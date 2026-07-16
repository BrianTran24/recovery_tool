// video_repair.c — Sửa video MP4/MOV bị mất/hỏng atom `moov`.
//
// Hai tầng (theo yêu cầu):
//   Tier 1 — frame-rebuild (kiểu untrunc/GoPro-SOS):
//       * Mượn cấu hình codec (stsd/hvcC/avcC), media timescale và sample-duration
//         từ video tham chiếu khỏe.
//       * Quét mdat của file hỏng theo NAL length-prefixed, tách thành sample,
//         trích riêng luồng video và remux thành MP4 mới (ftyp + mdat + moov) hợp lệ.
//   Tier 2 — best-effort fallback:
//       * Ghép nguyên `moov` của video tham chiếu, dịch offset stco/co64 theo vị trí
//         mdat mới. Dùng khi Tier 1 không trích đủ sample.
//
// Lưu ý: v1 tập trung dựng lại track VIDEO (có thể thiếu audio).

#include "video_repair.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// ─────────────────────────── Tiện ích big-endian ───────────────────────────
static uint32_t rd32(const uint8_t* p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}
static uint64_t rd64(const uint8_t* p) {
    uint64_t v = 0;
    for (int i = 0; i < 8; i++) v = (v << 8) | p[i];
    return v;
}
static void wr32(uint8_t* p, uint32_t v) {
    p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v;
}

// ─────────────────────────── Buffer động cho moov ──────────────────────────
typedef struct { uint8_t* d; size_t len, cap; } Buf;

static int buf_reserve(Buf* b, size_t need) {
    if (b->len + need <= b->cap) return 0;
    size_t ncap = b->cap ? b->cap : 4096;
    while (ncap < b->len + need) ncap *= 2;
    uint8_t* nd = (uint8_t*)realloc(b->d, ncap);
    if (!nd) return -1;
    b->d = nd; b->cap = ncap;
    return 0;
}
static int buf_put(Buf* b, const void* src, size_t n) {
    if (buf_reserve(b, n) != 0) return -1;
    memcpy(b->d + b->len, src, n); b->len += n; return 0;
}
static int buf_put32(Buf* b, uint32_t v) { uint8_t t[4]; wr32(t, v); return buf_put(b, t, 4); }
static int buf_put16(Buf* b, uint16_t v) { uint8_t t[2] = { (uint8_t)(v >> 8), (uint8_t)v }; return buf_put(b, t, 2); }
static int buf_put8(Buf* b, uint8_t v)   { return buf_put(b, &v, 1); }

// Bắt đầu 1 box: ghi placeholder size(4) + type(4). Trả offset để backpatch.
static size_t box_begin(Buf* b, const char* type) {
    size_t pos = b->len;
    buf_put32(b, 0);
    buf_put(b, type, 4);
    return pos;
}
static void box_end(Buf* b, size_t pos) {
    wr32(b->d + pos, (uint32_t)(b->len - pos));
}

// ───────────────────── Tìm box trong buffer (in-memory) ─────────────────────
// Trả về con trỏ tới đầu box (gồm header 8 byte) và tổng kích thước box.
static const uint8_t* find_box(const uint8_t* buf, size_t len, const char* type, size_t* out_size) {
    size_t pos = 0;
    while (pos + 8 <= len) {
        uint64_t bs = rd32(buf + pos);
        const uint8_t* t = buf + pos + 4;
        size_t hdr = 8;
        if (bs == 1) {
            if (pos + 16 > len) break;
            bs = rd64(buf + pos + 8);
            hdr = 16;
        } else if (bs == 0) {
            bs = len - pos;
        }
        if (bs < hdr || pos + bs > len) break;
        if (memcmp(t, type, 4) == 0) {
            if (out_size) *out_size = (size_t)bs;
            return buf + pos;
        }
        pos += (size_t)bs;
    }
    return NULL;
}

// Lấy payload (bỏ header) của 1 box tìm được.
static const uint8_t* box_payload(const uint8_t* box, size_t box_size, size_t* out_len) {
    size_t hdr = 8;
    if (rd32(box) == 1) hdr = 16;
    if (out_len) *out_len = box_size - hdr;
    return box + hdr;
}

// ─────────────────────── Thông tin trích từ tham chiếu ──────────────────────
typedef struct {
    const uint8_t* stsd;      // raw box stsd (gồm header)
    size_t         stsd_size;
    uint8_t        wh[8];     // width/height (16.16) raw từ tkhd
    uint32_t       media_ts;  // media timescale
    uint32_t       sample_delta; // duration mỗi sample (media units)
    int            is_hevc;   // 1 = HEVC, 0 = AVC
    int            nal_len_sz; // kích thước length prefix (thường 4)
    // Audio (best-effort AAC)
    const uint8_t* a_stsd;      // raw box stsd của trak soun (mp4a/esds)
    size_t         a_stsd_size;
    uint32_t       a_media_ts;  // audio media timescale (vd 48000)
    int            has_audio;
} RefInfo;

// Duyệt các con trực tiếp của một payload, gọi để tìm box con theo type.
static const uint8_t* find_child(const uint8_t* payload, size_t plen, const char* type, size_t* out_size) {
    return find_box(payload, plen, type, out_size);
}

static int parse_reference(const uint8_t* file, size_t flen, RefInfo* ri) {
    memset(ri, 0, sizeof(*ri));
    ri->nal_len_sz = 4;

    size_t moov_sz = 0;
    const uint8_t* moov = find_box(file, flen, "moov", &moov_sz);
    if (!moov) return -1;
    size_t moov_plen = 0;
    const uint8_t* moov_p = box_payload(moov, moov_sz, &moov_plen);

    // Duyệt từng trak, tìm trak video (và trak audio nếu có).
    int video_found = 0;
    size_t scan = 0;
    while (scan + 8 <= moov_plen) {
        uint64_t bs = rd32(moov_p + scan);
        if (bs == 1) bs = (scan + 16 <= moov_plen) ? rd64(moov_p + scan + 8) : 0;
        else if (bs == 0) bs = moov_plen - scan;
        if (bs < 8 || scan + bs > moov_plen) break;

        if (memcmp(moov_p + scan + 4, "trak", 4) == 0) {
            const uint8_t* trak = moov_p + scan;
            size_t trak_sz = (size_t)bs;
            size_t trak_plen; const uint8_t* trak_p = box_payload(trak, trak_sz, &trak_plen);

            size_t mdia_sz; const uint8_t* mdia = find_child(trak_p, trak_plen, "mdia", &mdia_sz);
            if (!mdia) { scan += (size_t)bs; continue; }
            size_t mdia_plen; const uint8_t* mdia_p = box_payload(mdia, mdia_sz, &mdia_plen);

            size_t hdlr_sz; const uint8_t* hdlr = find_child(mdia_p, mdia_plen, "hdlr", &hdlr_sz);
            if (!hdlr) { scan += (size_t)bs; continue; }
            size_t hdlr_plen; const uint8_t* hdlr_p = box_payload(hdlr, hdlr_sz, &hdlr_plen);
            // handler_type ở payload offset 8 (version+flags 4, pre_defined 4)
            int is_vide = (hdlr_plen >= 12 && memcmp(hdlr_p + 8, "vide", 4) == 0);
            int is_soun = (hdlr_plen >= 12 && memcmp(hdlr_p + 8, "soun", 4) == 0);

            if (is_soun) {
                // Trak audio (soun): lưu stsd (mp4a/esds) + timescale để dựng track AAC.
                uint32_t a_ts = 0;
                size_t amdhd_sz; const uint8_t* amdhd = find_child(mdia_p, mdia_plen, "mdhd", &amdhd_sz);
                if (amdhd) {
                    size_t amd_plen; const uint8_t* amd_p = box_payload(amdhd, amdhd_sz, &amd_plen);
                    uint8_t av = amd_p[0];
                    if (av == 1 && amd_plen >= 28) a_ts = rd32(amd_p + 20);
                    else if (amd_plen >= 16)       a_ts = rd32(amd_p + 12);
                }
                size_t aminf_sz; const uint8_t* aminf = find_child(mdia_p, mdia_plen, "minf", &aminf_sz);
                if (aminf) {
                    size_t aminf_plen; const uint8_t* aminf_p = box_payload(aminf, aminf_sz, &aminf_plen);
                    size_t astbl_sz; const uint8_t* astbl = find_child(aminf_p, aminf_plen, "stbl", &astbl_sz);
                    if (astbl) {
                        size_t astbl_plen; const uint8_t* astbl_p = box_payload(astbl, astbl_sz, &astbl_plen);
                        size_t astsd_sz; const uint8_t* astsd = find_child(astbl_p, astbl_plen, "stsd", &astsd_sz);
                        if (astsd) {
                            ri->a_stsd = astsd; ri->a_stsd_size = astsd_sz;
                            ri->a_media_ts = a_ts ? a_ts : 48000;
                            ri->has_audio = 1;
                        }
                    }
                }
                scan += (size_t)bs;
                continue;
            }
            if (!is_vide) { scan += (size_t)bs; continue; }

            // Đây là trak video. Lấy tkhd width/height.
            size_t tkhd_sz; const uint8_t* tkhd = find_child(trak_p, trak_plen, "tkhd", &tkhd_sz);
            if (tkhd) {
                size_t tk_plen; const uint8_t* tk_p = box_payload(tkhd, tkhd_sz, &tk_plen);
                // v0: width tại payload offset 76, height 80
                if (tk_plen >= 84) memcpy(ri->wh, tk_p + 76, 8);
            }

            // mdhd: media timescale
            size_t mdhd_sz; const uint8_t* mdhd = find_child(mdia_p, mdia_plen, "mdhd", &mdhd_sz);
            if (mdhd) {
                size_t md_plen; const uint8_t* md_p = box_payload(mdhd, mdhd_sz, &md_plen);
                uint8_t ver = md_p[0];
                if (ver == 1 && md_plen >= 28) ri->media_ts = rd32(md_p + 20);
                else if (md_plen >= 16)        ri->media_ts = rd32(md_p + 12);
            }

            // minf > stbl
            size_t minf_sz; const uint8_t* minf = find_child(mdia_p, mdia_plen, "minf", &minf_sz);
            if (!minf) return -2;
            size_t minf_plen; const uint8_t* minf_p = box_payload(minf, minf_sz, &minf_plen);
            size_t stbl_sz; const uint8_t* stbl = find_child(minf_p, minf_plen, "stbl", &stbl_sz);
            if (!stbl) return -2;
            size_t stbl_plen; const uint8_t* stbl_p = box_payload(stbl, stbl_sz, &stbl_plen);

            // stsd (giữ nguyên)
            size_t stsd_sz; const uint8_t* stsd = find_child(stbl_p, stbl_plen, "stsd", &stsd_sz);
            if (!stsd) return -2;
            ri->stsd = stsd; ri->stsd_size = stsd_sz;

            // Xác định codec + nal length size từ stsd
            size_t stsd_plen; const uint8_t* stsd_p = box_payload(stsd, stsd_sz, &stsd_plen);
            // stsd payload: version+flags(4) + entry_count(4) + sample_entry...
            if (stsd_plen > 8) {
                const uint8_t* se = stsd_p + 8;               // sample entry box
                size_t se_len = stsd_plen - 8;
                const char* fmt = (const char*)(se + 4);
                if (memcmp(fmt, "hvc1", 4) == 0 || memcmp(fmt, "hev1", 4) == 0) ri->is_hevc = 1;
                else if (memcmp(fmt, "avc1", 4) == 0 || memcmp(fmt, "avc3", 4) == 0) ri->is_hevc = 0;
                else ri->is_hevc = 1; // mặc định HEVC (GoPro)
                // Bên trong VisualSampleEntry, sau 78 byte cố định là các box con (hvcC/avcC)
                if (se_len > 86) {
                    const uint8_t* cfg_area = se + 8 + 78;     // +8 header sample entry, +78 fields
                    size_t cfg_len = se_len - 8 - 78;
                    size_t cc_sz;
                    const uint8_t* hvcC = find_child(cfg_area, cfg_len, "hvcC", &cc_sz);
                    if (hvcC) {
                        size_t cc_plen; const uint8_t* cc_p = box_payload(hvcC, cc_sz, &cc_plen);
                        if (cc_plen > 21) ri->nal_len_sz = (cc_p[21] & 0x3) + 1;
                        ri->is_hevc = 1;
                    } else {
                        const uint8_t* avcC = find_child(cfg_area, cfg_len, "avcC", &cc_sz);
                        if (avcC) {
                            size_t cc_plen; const uint8_t* cc_p = box_payload(avcC, cc_sz, &cc_plen);
                            if (cc_plen > 4) ri->nal_len_sz = (cc_p[4] & 0x3) + 1;
                            ri->is_hevc = 0;
                        }
                    }
                }
            }

            // stts sample_delta (entry đầu)
            size_t stts_sz; const uint8_t* stts = find_child(stbl_p, stbl_plen, "stts", &stts_sz);
            if (stts) {
                size_t st_plen; const uint8_t* st_p = box_payload(stts, stts_sz, &st_plen);
                if (st_plen >= 16) ri->sample_delta = rd32(st_p + 12);
            }

            if (!ri->media_ts) ri->media_ts = 30000;
            if (!ri->sample_delta) ri->sample_delta = ri->media_ts / 30; // giả định ~30fps
            video_found = 1;
        }
        scan += (size_t)bs;
    }
    if (!ri->media_ts) ri->media_ts = 30000;
    if (!ri->sample_delta) ri->sample_delta = ri->media_ts / 30;
    return video_found ? 0 : -3;
}

// ─────────────────────── Streaming reader cho file hỏng ─────────────────────
#define SRC_CAP (32u * 1024 * 1024)
typedef struct {
    FILE*    f;
    uint8_t* buf;
    size_t   len;   // số byte hợp lệ trong buf
    size_t   pos;   // con trỏ đọc
    int      eof;
} Src;

static void src_fill(Src* s) {
    if (s->pos > 0) {
        memmove(s->buf, s->buf + s->pos, s->len - s->pos);
        s->len -= s->pos;
        s->pos = 0;
    }
    while (s->len < SRC_CAP && !s->eof) {
        size_t got = fread(s->buf + s->len, 1, SRC_CAP - s->len, s->f);
        if (got == 0) { s->eof = 1; break; }
        s->len += got;
    }
}
static size_t src_avail(Src* s) { return s->len - s->pos; }

// ─────────────────────── Kiểm tra NAL hợp lệ (đồng bộ) ──────────────────────
static int hevc_nal_ok(const uint8_t* p) {
    if (p[0] & 0x80) return 0;                 // forbidden_zero_bit
    int type  = (p[0] >> 1) & 0x3F;
    int layer = ((p[0] & 1) << 5) | (p[1] >> 3);
    int tid   = p[1] & 0x7;
    if (layer != 0) return 0;                  // chỉ base layer
    if (tid == 0) return 0;                    // temporal_id_plus1 >= 1
    if (type > 40) return 0;
    return 1;
}
static int avc_nal_ok(const uint8_t* p) {
    if (p[0] & 0x80) return 0;
    int type = p[0] & 0x1F;
    return (type >= 1 && type <= 23);
}
static int nal_ok(const RefInfo* ri, const uint8_t* p) {
    return ri->is_hevc ? hevc_nal_ok(p) : avc_nal_ok(p);
}
static int nal_is_vcl(const RefInfo* ri, const uint8_t* p) {
    if (ri->is_hevc) { int t = (p[0] >> 1) & 0x3F; return t <= 31; }
    int t = p[0] & 0x1F; return (t >= 1 && t <= 5);
}
static int nal_is_keyframe(const RefInfo* ri, const uint8_t* p) {
    if (ri->is_hevc) { int t = (p[0] >> 1) & 0x3F; return (t >= 16 && t <= 23); } // IRAP
    int t = p[0] & 0x1F; return (t == 5);
}
static int nal_first_slice(const RefInfo* ri, const uint8_t* p, size_t nal_len) {
    if (nal_len < 3) return 1;
    // Bit đầu của slice header nằm ngay sau NAL header (2 byte HEVC / 1 byte AVC).
    if (ri->is_hevc) return (p[2] >> 7) & 1;
    return (p[1] >> 7) & 1; // AVC: first_mb_in_slice ue(v); bit đầu =1 khi giá trị 0
}

// Đọc length-prefix tại p (avail byte khả dụng). Trả nlen hợp lệ, hoặc 0 nếu không.
static uint64_t nal_len_at(const RefInfo* ri, const uint8_t* p, size_t avail) {
    int LS = ri->nal_len_sz;
    if (avail < (size_t)LS + 2) return 0;
    uint64_t nlen = 0;
    for (int i = 0; i < LS; i++) nlen = (nlen << 8) | p[i];
    if (nlen < 2 || nlen > 12ULL * 1024 * 1024) return 0;  // cap để giữ đồng bộ
    if (!nal_ok(ri, p + LS)) return 0;
    return nlen;
}

// ───────────────────────── Xây dựng moov video-only ─────────────────────────
static int build_moov(Buf* mv, const RefInfo* ri,
                      const uint32_t* sizes, uint32_t nsamp,
                      const uint32_t* keys, uint32_t nkey,
                      uint64_t mdat_data_off,
                      const uint32_t* a_sizes, uint32_t a_nsamp,
                      uint64_t audio_data_off) {
    uint32_t ts = ri->media_ts;
    uint32_t sd = ri->sample_delta;
    uint64_t dur = (uint64_t)nsamp * sd;                 // video duration (movie ts == video media ts)
    uint64_t a_dur_movie = (a_nsamp > 0 && ri->a_media_ts)
        ? (uint64_t)a_nsamp * 1024ULL * ts / ri->a_media_ts : 0;
    uint64_t movie_dur = (dur > a_dur_movie) ? dur : a_dur_movie;
    uint32_t dur32 = (dur > 0xFFFFFFFFULL) ? 0xFFFFFFFFu : (uint32_t)dur;
    uint32_t mvdur32 = (movie_dur > 0xFFFFFFFFULL) ? 0xFFFFFFFFu : (uint32_t)movie_dur;

    size_t moov = box_begin(mv, "moov");

    // mvhd (v0)
    size_t mvhd = box_begin(mv, "mvhd");
    buf_put32(mv, 0);            // version+flags
    buf_put32(mv, 0);            // creation
    buf_put32(mv, 0);            // modification
    buf_put32(mv, ts);           // timescale
    buf_put32(mv, mvdur32);      // duration (max của các track)
    buf_put32(mv, 0x00010000);   // rate 1.0
    buf_put16(mv, 0x0100);       // volume 1.0
    buf_put16(mv, 0);            // reserved
    buf_put32(mv, 0); buf_put32(mv, 0);
    // matrix identity
    uint32_t mtx[9] = {0x00010000,0,0,0,0x00010000,0,0,0,0x40000000};
    for (int i = 0; i < 9; i++) buf_put32(mv, mtx[i]);
    for (int i = 0; i < 6; i++) buf_put32(mv, 0); // pre_defined
    buf_put32(mv, a_nsamp > 0 ? 3 : 2);            // next_track_ID
    box_end(mv, mvhd);

    // trak
    size_t trak = box_begin(mv, "trak");

    // tkhd (v0, enabled+in movie)
    size_t tkhd = box_begin(mv, "tkhd");
    buf_put32(mv, 0x00000007);   // version0 flags=enabled|inMovie|inPreview
    buf_put32(mv, 0);            // creation
    buf_put32(mv, 0);            // modification
    buf_put32(mv, 1);            // track_ID
    buf_put32(mv, 0);            // reserved
    buf_put32(mv, dur32);        // duration
    buf_put32(mv, 0); buf_put32(mv, 0); // reserved
    buf_put16(mv, 0);            // layer
    buf_put16(mv, 0);            // alternate_group
    buf_put16(mv, 0);            // volume (video=0)
    buf_put16(mv, 0);            // reserved
    for (int i = 0; i < 9; i++) buf_put32(mv, mtx[i]);
    buf_put(mv, ri->wh, 8);      // width/height (16.16)
    box_end(mv, tkhd);

    // mdia
    size_t mdia = box_begin(mv, "mdia");
    // mdhd (v0)
    size_t mdhd = box_begin(mv, "mdhd");
    buf_put32(mv, 0);
    buf_put32(mv, 0); buf_put32(mv, 0);
    buf_put32(mv, ts);
    buf_put32(mv, dur32);
    buf_put16(mv, 0x55C4);       // language 'und'
    buf_put16(mv, 0);
    box_end(mv, mdhd);
    // hdlr
    size_t hdlr = box_begin(mv, "hdlr");
    buf_put32(mv, 0);
    buf_put32(mv, 0);            // pre_defined
    buf_put(mv, "vide", 4);
    buf_put32(mv, 0); buf_put32(mv, 0); buf_put32(mv, 0);
    buf_put(mv, "VideoHandler", 12); buf_put8(mv, 0);
    box_end(mv, hdlr);
    // minf
    size_t minf = box_begin(mv, "minf");
    // vmhd
    size_t vmhd = box_begin(mv, "vmhd");
    buf_put32(mv, 0x00000001);   // flags=1
    buf_put16(mv, 0); buf_put16(mv, 0); buf_put16(mv, 0); buf_put16(mv, 0);
    box_end(mv, vmhd);
    // dinf > dref (self-contained)
    size_t dinf = box_begin(mv, "dinf");
    size_t dref = box_begin(mv, "dref");
    buf_put32(mv, 0);
    buf_put32(mv, 1);            // entry_count
    size_t url = box_begin(mv, "url ");
    buf_put32(mv, 0x00000001);   // flags: self-contained
    box_end(mv, url);
    box_end(mv, dref);
    box_end(mv, dinf);
    // stbl
    size_t stbl = box_begin(mv, "stbl");
    // stsd (copy raw từ tham chiếu)
    buf_put(mv, ri->stsd, ri->stsd_size);
    // stts: 1 entry
    size_t stts = box_begin(mv, "stts");
    buf_put32(mv, 0);
    buf_put32(mv, 1);
    buf_put32(mv, nsamp);
    buf_put32(mv, sd);
    box_end(mv, stts);
    // stss (keyframes) nếu có
    if (nkey > 0) {
        size_t stss = box_begin(mv, "stss");
        buf_put32(mv, 0);
        buf_put32(mv, nkey);
        for (uint32_t i = 0; i < nkey; i++) buf_put32(mv, keys[i]);
        box_end(mv, stss);
    }
    // stsc: tất cả sample trong 1 chunk
    size_t stsc = box_begin(mv, "stsc");
    buf_put32(mv, 0);
    buf_put32(mv, 1);
    buf_put32(mv, 1);            // first_chunk
    buf_put32(mv, nsamp);        // samples_per_chunk
    buf_put32(mv, 1);            // sample_description_index
    box_end(mv, stsc);
    // stsz
    size_t stsz = box_begin(mv, "stsz");
    buf_put32(mv, 0);
    buf_put32(mv, 0);            // sample_size=0 => bảng
    buf_put32(mv, nsamp);
    for (uint32_t i = 0; i < nsamp; i++) buf_put32(mv, sizes[i]);
    box_end(mv, stsz);
    // co64: offset 64-bit của chunk duy nhất
    size_t co64 = box_begin(mv, "co64");
    buf_put32(mv, 0);
    buf_put32(mv, 1);
    uint8_t off8[8];
    for (int i = 0; i < 8; i++) off8[i] = (uint8_t)(mdat_data_off >> (56 - 8 * i));
    buf_put(mv, off8, 8);
    box_end(mv, co64);

    box_end(mv, stbl);
    box_end(mv, minf);
    box_end(mv, mdia);
    box_end(mv, trak);

    // ── Trak audio (soun / AAC) — best-effort ──
    if (a_nsamp > 0 && ri->a_stsd) {
        uint32_t a_ts = ri->a_media_ts ? ri->a_media_ts : 48000;
        uint64_t a_dur = (uint64_t)a_nsamp * 1024ULL;
        uint32_t a_dur32 = (a_dur > 0xFFFFFFFFULL) ? 0xFFFFFFFFu : (uint32_t)a_dur;
        uint32_t mtx2[9] = {0x00010000,0,0,0,0x00010000,0,0,0,0x40000000};

        size_t atrak = box_begin(mv, "trak");
        // tkhd
        size_t atkhd = box_begin(mv, "tkhd");
        buf_put32(mv, 0x00000007);       // enabled|inMovie|inPreview
        buf_put32(mv, 0); buf_put32(mv, 0);
        buf_put32(mv, 2);                // track_ID = 2
        buf_put32(mv, 0);
        buf_put32(mv, a_dur_movie > 0xFFFFFFFFULL ? 0xFFFFFFFFu : (uint32_t)a_dur_movie);
        buf_put32(mv, 0); buf_put32(mv, 0);
        buf_put16(mv, 0);                // layer
        buf_put16(mv, 1);                // alternate_group
        buf_put16(mv, 0x0100);           // volume 1.0 (audio)
        buf_put16(mv, 0);
        for (int i = 0; i < 9; i++) buf_put32(mv, mtx2[i]);
        buf_put32(mv, 0); buf_put32(mv, 0); // width/height = 0
        box_end(mv, atkhd);
        // mdia
        size_t amdia = box_begin(mv, "mdia");
        size_t amdhd = box_begin(mv, "mdhd");
        buf_put32(mv, 0);
        buf_put32(mv, 0); buf_put32(mv, 0);
        buf_put32(mv, a_ts);
        buf_put32(mv, a_dur32);
        buf_put16(mv, 0x55C4);           // 'und'
        buf_put16(mv, 0);
        box_end(mv, amdhd);
        size_t ahdlr = box_begin(mv, "hdlr");
        buf_put32(mv, 0);
        buf_put32(mv, 0);
        buf_put(mv, "soun", 4);
        buf_put32(mv, 0); buf_put32(mv, 0); buf_put32(mv, 0);
        buf_put(mv, "SoundHandler", 12); buf_put8(mv, 0);
        box_end(mv, ahdlr);
        size_t aminf = box_begin(mv, "minf");
        // smhd
        size_t smhd = box_begin(mv, "smhd");
        buf_put32(mv, 0);
        buf_put16(mv, 0); buf_put16(mv, 0); // balance + reserved
        box_end(mv, smhd);
        // dinf > dref
        size_t adinf = box_begin(mv, "dinf");
        size_t adref = box_begin(mv, "dref");
        buf_put32(mv, 0);
        buf_put32(mv, 1);
        size_t aurl = box_begin(mv, "url ");
        buf_put32(mv, 0x00000001);
        box_end(mv, aurl);
        box_end(mv, adref);
        box_end(mv, adinf);
        // stbl
        size_t astbl = box_begin(mv, "stbl");
        buf_put(mv, ri->a_stsd, ri->a_stsd_size);   // stsd (mp4a/esds) copy
        size_t astts = box_begin(mv, "stts");
        buf_put32(mv, 0);
        buf_put32(mv, 1);
        buf_put32(mv, a_nsamp);
        buf_put32(mv, 1024);             // AAC: 1024 sample/frame
        box_end(mv, astts);
        size_t astsc = box_begin(mv, "stsc");
        buf_put32(mv, 0);
        buf_put32(mv, 1);
        buf_put32(mv, 1);
        buf_put32(mv, a_nsamp);
        buf_put32(mv, 1);
        box_end(mv, astsc);
        size_t astsz = box_begin(mv, "stsz");
        buf_put32(mv, 0);
        buf_put32(mv, 0);
        buf_put32(mv, a_nsamp);
        for (uint32_t i = 0; i < a_nsamp; i++) buf_put32(mv, a_sizes[i]);
        box_end(mv, astsz);
        size_t aco64 = box_begin(mv, "co64");
        buf_put32(mv, 0);
        buf_put32(mv, 1);
        uint8_t ao8[8];
        for (int i = 0; i < 8; i++) ao8[i] = (uint8_t)(audio_data_off >> (56 - 8 * i));
        buf_put(mv, ao8, 8);
        box_end(mv, aco64);
        box_end(mv, astbl);
        box_end(mv, aminf);
        box_end(mv, amdia);
        box_end(mv, atrak);
    }

    box_end(mv, moov);
    return 0;
}

// ───────────────────────────── Tier 1: rebuild ──────────────────────────────
// Trả 0 nếu thành công (đã ghi outputPath), <0 nếu không đủ dữ liệu.
static int repair_tier1(const char* brokenPath, const RefInfo* ri, const char* outputPath) {
    FILE* fin = fopen(brokenPath, "rb");
    if (!fin) return -1;
    FILE* fout = fopen(outputPath, "wb");
    if (!fout) { fclose(fin); return -1; }

    Src s = {0};
    s.f = fin;
    s.buf = (uint8_t*)malloc(SRC_CAP);
    if (!s.buf) { fclose(fin); fclose(fout); return -1; }

    // ftyp
    Buf ftyp = {0};
    size_t fb = box_begin(&ftyp, "ftyp");
    buf_put(&ftyp, "mp42", 4);
    buf_put32(&ftyp, 0);
    buf_put(&ftyp, "mp42", 4); buf_put(&ftyp, "isom", 4); buf_put(&ftyp, "hvc1", 4);
    box_end(&ftyp, fb);
    fwrite(ftyp.d, 1, ftyp.len, fout);

    // mdat header (co64 dùng 64-bit size để an toàn)
    uint64_t mdat_hdr_off = ftyp.len;
    uint64_t mdat_data_off = mdat_hdr_off + 16; // large-size box: size(4)=1 + type(4) + largesize(8)
    uint8_t mdat_hdr[16] = {0,0,0,1,'m','d','a','t',0,0,0,0,0,0,0,0};
    fwrite(mdat_hdr, 1, 16, fout);

    // Bảng sample
    uint32_t cap = 65536, nsamp = 0;
    uint32_t* sizes = (uint32_t*)malloc(cap * sizeof(uint32_t));
    uint32_t kcap = 4096, nkey = 0;
    uint32_t* keys = (uint32_t*)malloc(kcap * sizeof(uint32_t));
    if (!sizes || !keys) { free(sizes); free(keys); free(s.buf); fclose(fin); fclose(fout); return -1; }

    uint64_t mdat_written = 0;
    int cur_has_vcl = 0;
    uint32_t cur_size = 0;
    int cur_key = 0;
    const int LS = ri->nal_len_sz;

    // ── Audio best-effort: thu thập các "gap" giữa chunk video làm khung AAC ──
    #define AAC_GAP_CAP 16384u
    #define AAC_MIN     40u
    #define AAC_MAX     4000u
    int want_audio = ri->has_audio && ri->a_stsd;
    uint8_t* gap = want_audio ? (uint8_t*)malloc(AAC_GAP_CAP) : NULL;
    size_t gap_len = 0; int gap_of = 0;
    Buf a_data = {0};
    uint32_t a_cap = 8192, a_nsamp = 0;
    uint32_t* a_sizes = want_audio ? (uint32_t*)malloc(a_cap * sizeof(uint32_t)) : NULL;
    if (want_audio && (!gap || !a_sizes)) { want_audio = 0; }
    int in_sync = 0;   // 1 khi đang trong 1 chuỗi NAL video liền mạch

    for (;;) {
        if (src_avail(&s) < (size_t)(LS + 2)) {
            src_fill(&s);
            if (src_avail(&s) < (size_t)(LS + 2)) break;
        }
        const uint8_t* p = s.buf + s.pos;
        uint64_t nlen = nal_len_at(ri, p, src_avail(&s));

        int accept = 0;
        size_t need = 0;
        if (nlen) {
            need = (size_t)LS + (size_t)nlen;
            // Đảm bảo đủ NAL hiện tại + header NAL kế trong buffer để kiểm tra chuỗi.
            if (src_avail(&s) < need + (size_t)LS + 2) {
                src_fill(&s);
                p = s.buf + s.pos;
            }
            size_t av = src_avail(&s);
            if (av >= need) {
                if (in_sync) {
                    accept = 1;                 // đang đồng bộ → tin NAL đơn (giữ cả NAL cuối chunk)
                } else if (av >= need + (size_t)LS + 2) {
                    // Resync: chống false-sync, NAL kế cũng phải hợp lệ (chuỗi liền mạch).
                    accept = nal_len_at(ri, p + need, av - need) ? 1 : 0;
                } else if (s.eof) {
                    accept = 1;                 // NAL cuối cùng — không còn gì để nối.
                }
            } else if (s.eof) {
                break;                          // NAL bị cắt cụt ở cuối file.
            }
        }

        if (!accept) {
            in_sync = 0;
            if (want_audio) {
                if (gap_len < AAC_GAP_CAP) gap[gap_len++] = s.buf[s.pos];
                else gap_of = 1;
            }
            s.pos += 1;           // Mất đồng bộ (gpmf/audio/chunk khác) → trượt tìm NAL kế.
            continue;
        }

        // Đã chấp nhận 1 NAL video → xử lý gap tích lũy trước đó như 1 khung AAC.
        // Chỉ xét sau khi đã ghi video (bỏ qua phần preamble ftyp/mdat ban đầu).
        if (want_audio && gap_len > 0 && mdat_written > 0) {
            if (!gap_of) {
                size_t st = 0;
                while (st < gap_len && gap[st] == 0x00) st++;           // trọn zero-padding đầu
                // Bỏ qua khối "GP" framing của GoPro: 47 50 <nwords> 00.
                // Khối GP ngay trước khung audio mã hoá kích thước AU thật ở offset +4.
                long last_gp = -1;
                while (st + 4 <= gap_len && gap[st] == 0x47 && gap[st + 1] == 0x50 && gap[st + 3] == 0x00) {
                    last_gp = (long)st;
                    size_t blk = (size_t)gap[st + 2] * 4;
                    if (blk < 4) break;
                    st += blk;
                }
                while (st < gap_len && gap[st] == 0x00) st++;           // trọn zero sau GP
                size_t alen;
                if (last_gp >= 0 && (size_t)last_gp + 8 <= gap_len) {
                    uint32_t sz = rd32(gap + last_gp + 4);              // kích thước AU chính xác
                    if (sz >= AAC_MIN && sz <= AAC_MAX && st + sz <= gap_len) alen = sz;
                    else { size_t en = gap_len; while (en > st && gap[en - 1] == 0x00) en--; alen = (en > st) ? en - st : 0; }
                } else {
                    size_t en = gap_len; while (en > st && gap[en - 1] == 0x00) en--; alen = (en > st) ? en - st : 0;
                }
                if (alen >= AAC_MIN && alen <= AAC_MAX) {
                    if (a_nsamp >= a_cap) {
                        a_cap *= 2;
                        uint32_t* na = (uint32_t*)realloc(a_sizes, a_cap * sizeof(uint32_t));
                        if (na) a_sizes = na;
                    }
                    if (a_nsamp < a_cap && buf_put(&a_data, gap + st, alen) == 0) {
                        a_sizes[a_nsamp++] = (uint32_t)alen;
                    }
                }
            }
            gap_len = 0; gap_of = 0;
        } else if (gap_len > 0) {
            gap_len = 0; gap_of = 0;
        }

        int is_vcl = nal_is_vcl(ri, p + LS);
        int first  = is_vcl ? nal_first_slice(ri, p + LS, (size_t)nlen) : 0;
        int is_key = nal_is_keyframe(ri, p + LS);

        // Ranh giới access-unit mới?
        int boundary = cur_has_vcl && ((is_vcl && first) || !is_vcl);
        if (boundary) {
            if (nsamp >= cap) {
                cap *= 2;
                uint32_t* ns = (uint32_t*)realloc(sizes, cap * sizeof(uint32_t));
                if (!ns) break;
                sizes = ns;
            }
            sizes[nsamp] = cur_size;
            if (cur_key) {
                if (nkey >= kcap) { kcap *= 2; uint32_t* nk = (uint32_t*)realloc(keys, kcap * sizeof(uint32_t)); if (nk) keys = nk; }
                if (nkey < kcap) keys[nkey++] = nsamp + 1; // stss 1-based
            }
            nsamp++;
            cur_size = 0; cur_has_vcl = 0; cur_key = 0;
        }

        // Ghi NAL (length prefix + data) vào mdat mới.
        fwrite(p, 1, need, fout);
        mdat_written += need;
        cur_size += (uint32_t)need;
        if (is_vcl) cur_has_vcl = 1;
        if (is_key) cur_key = 1;

        in_sync = 1;              // đã đọc trọn 1 NAL → duy trì đồng bộ cho NAL kế
        s.pos += need;
    }

    // Đóng sample cuối cùng.
    if (cur_has_vcl && cur_size > 0) {
        if (nsamp < cap) {
            sizes[nsamp] = cur_size;
            if (cur_key && nkey < kcap) keys[nkey++] = nsamp + 1;
            nsamp++;
        }
    }

    free(s.buf);
    fclose(fin);

    // Cổng tin cậy audio: số khung phải xấp xỉ kỳ vọng theo thời lượng video.
    uint32_t keep_a_nsamp = 0;
    if (want_audio && a_nsamp > 0 && ri->media_ts > 0) {
        double vid_sec = (double)((uint64_t)nsamp * ri->sample_delta) / (double)ri->media_ts;
        double a_ts = (double)(ri->a_media_ts ? ri->a_media_ts : 48000);
        double expected = vid_sec * a_ts / 1024.0;
        if (expected > 0 && a_nsamp >= expected * 0.5 && a_nsamp <= expected * 1.5) {
            keep_a_nsamp = a_nsamp;
        }
    }

    // Ngưỡng thành công: đủ số frame & dữ liệu để đáng gọi là "playable".
    if (nsamp < 30 || mdat_written < 512 * 1024) {
        free(sizes); free(keys); free(gap); free(a_sizes); free(a_data.d);
        fclose(fout);
        remove(outputPath);
        return -2;
    }

    // Ghi vùng audio ngay sau video trong cùng mdat (nếu giữ audio).
    uint64_t audio_data_off = mdat_data_off + mdat_written;
    uint64_t total_media = mdat_written;
    if (keep_a_nsamp > 0 && a_data.d) {
        fwrite(a_data.d, 1, a_data.len, fout);
        total_media += a_data.len;
    }

    // Backpatch mdat largesize (offset 8, 8 byte big-endian).
    uint64_t mdat_box_size = 16 + total_media;
    uint8_t sz8[8];
    for (int i = 0; i < 8; i++) sz8[i] = (uint8_t)(mdat_box_size >> (56 - 8 * i));
    fseek(fout, (long)(mdat_hdr_off + 8), SEEK_SET);
    fwrite(sz8, 1, 8, fout);
    fseek(fout, 0, SEEK_END);

    // moov
    Buf mv = {0};
    if (build_moov(&mv, ri, sizes, nsamp, keys, nkey, mdat_data_off,
                   a_sizes, keep_a_nsamp, audio_data_off) == 0 && mv.d) {
        fwrite(mv.d, 1, mv.len, fout);
    }
    free(mv.d);
    free(sizes); free(keys); free(gap); free(a_sizes); free(a_data.d);
    free(ftyp.d);
    fclose(fout);
    return 0;
}

// ─────────────────── Tier 2: graft moov + dịch offset stco/co64 ──────────────
static void shift_recursive(uint8_t* buf, size_t len, int64_t delta) {
    size_t pos = 0;
    while (pos + 8 <= len) {
        uint64_t bs = rd32(buf + pos);
        size_t hdr = 8;
        if (bs == 1) { if (pos + 16 > len) break; bs = rd64(buf + pos + 8); hdr = 16; }
        else if (bs == 0) bs = len - pos;
        if (bs < hdr || pos + bs > len) break;

        const uint8_t* type = buf + pos + 4;
        uint8_t* payload = buf + pos + hdr;
        size_t plen = (size_t)bs - hdr;

        if (memcmp(type, "stco", 4) == 0 && plen >= 8) {
            uint32_t n = rd32(payload + 4);
            for (uint32_t i = 0; i < n && 8 + (size_t)i * 4 + 4 <= plen; i++) {
                uint8_t* e = payload + 8 + i * 4;
                wr32(e, (uint32_t)((int64_t)rd32(e) + delta));
            }
        } else if (memcmp(type, "co64", 4) == 0 && plen >= 8) {
            uint32_t n = rd32(payload + 4);
            for (uint32_t i = 0; i < n && 8 + (size_t)i * 8 + 8 <= plen; i++) {
                uint8_t* e = payload + 8 + i * 8;
                uint64_t v = (uint64_t)((int64_t)rd64(e) + delta);
                for (int j = 0; j < 8; j++) e[j] = (uint8_t)(v >> (56 - 8 * j));
            }
        } else if (memcmp(type, "moov", 4) == 0 || memcmp(type, "trak", 4) == 0 ||
                   memcmp(type, "mdia", 4) == 0 || memcmp(type, "minf", 4) == 0 ||
                   memcmp(type, "stbl", 4) == 0) {
            shift_recursive(payload, plen, delta);
        }
        pos += (size_t)bs;
    }
}

static int repair_tier2(const char* brokenPath,
                        const uint8_t* ref, size_t ref_len,
                        const char* outputPath) {
    size_t ftyp_sz = 0;
    const uint8_t* ftyp = find_box(ref, ref_len, "ftyp", &ftyp_sz);
    size_t moov_sz = 0;
    const uint8_t* moov = find_box(ref, ref_len, "moov", &moov_sz);
    size_t rmdat_sz = 0;
    const uint8_t* rmdat = find_box(ref, ref_len, "mdat", &rmdat_sz);
    if (!moov || !rmdat) return -1;

    // Vị trí data mdat trong tham chiếu.
    size_t rmdat_hdr = (rd32(rmdat) == 1) ? 16 : 8;
    uint64_t ref_mdat_data = (uint64_t)(rmdat - ref) + rmdat_hdr;

    FILE* fin = fopen(brokenPath, "rb");
    if (!fin) return -1;
    fseek(fin, 0, SEEK_END);
    long broken_size = ftell(fin);
    fseek(fin, 0, SEEK_SET);
    if (broken_size <= 0) { fclose(fin); return -1; }

    FILE* fout = fopen(outputPath, "wb");
    if (!fout) { fclose(fin); return -1; }

    // ftyp
    if (ftyp) fwrite(ftyp, 1, ftyp_sz, fout);
    uint64_t after_ftyp = ftyp ? ftyp_sz : 0;

    // mdat lớn (64-bit)
    uint64_t new_mdat_data = after_ftyp + 16;
    uint64_t mdat_box_size = 16 + (uint64_t)broken_size;
    uint8_t mdat_hdr[16] = {0,0,0,1,'m','d','a','t',0,0,0,0,0,0,0,0};
    for (int i = 0; i < 8; i++) mdat_hdr[8 + i] = (uint8_t)(mdat_box_size >> (56 - 8 * i));
    fwrite(mdat_hdr, 1, 16, fout);

    // copy dữ liệu file hỏng
    uint8_t* cbuf = (uint8_t*)malloc(4 * 1024 * 1024);
    if (cbuf) {
        size_t n;
        while ((n = fread(cbuf, 1, 4 * 1024 * 1024, fin)) > 0) fwrite(cbuf, 1, n, fout);
        free(cbuf);
    }
    fclose(fin);

    // moov (bản sao) + dịch offset
    uint8_t* moov_copy = (uint8_t*)malloc(moov_sz);
    if (!moov_copy) { fclose(fout); return -1; }
    memcpy(moov_copy, moov, moov_sz);
    int64_t delta = (int64_t)new_mdat_data - (int64_t)ref_mdat_data;
    shift_recursive(moov_copy, moov_sz, delta);
    fwrite(moov_copy, 1, moov_sz, fout);
    free(moov_copy);

    fclose(fout);
    return 0;
}

// ─────────────────────────────── API chính ─────────────────────────────────
int RepairVideo(const char* brokenPath, const char* referencePath, const char* outputPath) {
    if (!brokenPath || !referencePath || !outputPath) return -1;

    // Nạp toàn bộ tham chiếu vào RAM (thường < 200MB).
    FILE* fr = fopen(referencePath, "rb");
    if (!fr) return -1;
    fseek(fr, 0, SEEK_END);
    long ref_len = ftell(fr);
    fseek(fr, 0, SEEK_SET);
    if (ref_len <= 0 || ref_len > 512L * 1024 * 1024) { fclose(fr); return -1; }
    uint8_t* ref = (uint8_t*)malloc((size_t)ref_len);
    if (!ref) { fclose(fr); return -1; }
    if (fread(ref, 1, (size_t)ref_len, fr) != (size_t)ref_len) { free(ref); fclose(fr); return -1; }
    fclose(fr);

    RefInfo ri;
    int pr = parse_reference(ref, (size_t)ref_len, &ri);

    // Tier 1 — frame-rebuild.
    if (pr == 0) {
        int r1 = repair_tier1(brokenPath, &ri, outputPath);
        if (r1 == 0) { free(ref); return 0; }
    }

    // Tier 2 — best-effort fallback.
    int r2 = repair_tier2(brokenPath, ref, (size_t)ref_len, outputPath);
    free(ref);
    return (r2 == 0) ? 0 : -2;
}
