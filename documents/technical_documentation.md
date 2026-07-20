# Tài liệu Kỹ thuật: Hệ thống Khôi phục Dữ liệu (Recovery SD)

Tài liệu này chi tiết về kiến trúc, phương pháp luận và quy trình thực thi của giải pháp khôi phục dữ liệu được triển khai trong dự án.

## 1. Tổng quan Kiến trúc
Hệ thống được xây dựng theo mô hình **Hybrid Recovery**, kết hợp giữa phân tích cấu trúc hệ thống tập tin (File System Analysis) và kỹ thuật Carving dữ liệu thô (Raw Data Carving).

### 1.1. Kiểm tra Sức khỏe Vật lý (Hardware Health Check)
Trước khi tiến hành các bước khôi phục logic, hệ thống thực hiện kiểm tra lớp vật lý để ngăn ngừa hư hỏng thêm:
- **Xác thực Controller**: Đọc ID và phiên bản firmware của bộ điều khiển Flash. Nếu thông tin không hợp lệ hoặc thiết bị nhận dạng sai (ví dụ: "Generic Loader"), hệ thống sẽ cảnh báo lỗi phần cứng nghiêm trọng.
- **Kiểm tra Dung lượng**: So sánh dung lượng vật lý báo cáo bởi Controller với dung lượng định danh. Trường hợp dung lượng 0MB hoặc báo cáo sai lệch lớn (vài KB) thường là dấu hiệu của hỏng FTL (Flash Translation Layer).
- **Phép thử Đọc Cơ bản (Sanity Read)**: Thử nghiệm đọc các sector tại các vị trí chiến lược (đầu, giữa, cuối). Nếu xảy ra lỗi I/O liên tục, hệ thống sẽ đề xuất dừng lại để tránh làm hỏng chip NAND.

### 1.2. Rủi ro Ghi đè & Garbage Collection (GC) / Trim
Một yếu tố quan trọng ảnh hưởng đến tỷ lệ thành công của việc khôi phục dữ liệu trên các thiết bị lưu trữ hiện đại (SD Card, SSD):
- **Cơ chế GC/Trim**: Các thẻ nhớ cao cấp (UHS-II) và SSD có cơ chế tự động dọn dẹp các khối dữ liệu "rảnh" ở tầng vật lý ngay cả khi người dùng chưa ghi dữ liệu mới. Quá trình này diễn ra âm thầm trong nền (background) khi thiết bị có điện.
- **Hậu quả**: Dữ liệu sau khi xóa có thể bị mất vĩnh viễn do bộ điều khiển (Controller) xóa sạch vật lý các cell nhớ để tối ưu hiệu suất ghi sau này.
- **Khuyến nghị**: Luôn thực hiện **Clone toàn bộ thẻ vật lý** sang một file ảnh đĩa (`.img`) ngay khi bắt đầu quy trình khôi phục. Việc thao tác trên file ảnh giúp bảo vệ dữ liệu gốc khỏi cơ chế tự hủy của Controller.

- **Frontend**: Flutter (Dart) - Đảm nhiệm UI/UX và quản lý trạng thái.
- **Backend Core**: C++ (Native Library) - Thực hiện các tác vụ xử lý cấp thấp, đọc sector và phân tích bitstream.
- **Giao tiếp**: Dart FFI (Foreign Function Interface) - Cầu nối hiệu năng cao giữa Dart và C++.

## 2. Phương pháp Khôi phục Dữ liệu

Dự án sử dụng hai kỹ thuật chính để tối đa hóa khả năng tìm lại dữ liệu:

### 2.1. Phân tích FAT (File Allocation Table)
Áp dụng cho các thiết bị lưu trữ định dạng FAT32/exFAT (phổ biến trên thẻ nhớ SD).
- **Cơ chế**: Quét bảng FAT để tìm các entry bị đánh dấu là "deleted" nhưng dữ liệu thực tế (clusters) vẫn còn trên đĩa.
- **Ưu điểm**: Khôi phục được đầy đủ tên tệp, cấu trúc thư mục và thời gian chỉnh sửa ban đầu.
- **Hạn chế**: Không hiệu quả nếu bảng FAT đã bị ghi đè hoặc thiết bị đã bị format nhanh.

### 2.2. Data Carving (Deep Scan)
Kỹ thuật quét thô dựa trên "Magic Bytes" (Signatures).
- **Cơ chế**: Quét từng sector trên đĩa để tìm các header đặc trưng của định dạng tệp (ví dụ: `FF D8 FF` cho JPEG, `00 00 00 18 66 74 79 70` cho MP4).
- **Ưu điểm**: Tìm được tệp ngay cả khi hệ thống tập tin bị hỏng hoàn toàn.
- **Tính năng đặc biệt**:
    - **Video Repair**: Tự động sửa lỗi thiếu `moov` atom (thường gặp khi video bị quay lỗi hoặc carving không hoàn chỉnh) bằng cách sử dụng một video tham chiếu (Reference Video) cùng loại.

## 3. Chi tiết Xử lý Native (C++ Core)

Phần lõi C++ là trái tim của hệ thống, được tối ưu hóa để làm việc trực tiếp với bitstream của thiết bị lưu trữ.

### 3.1. Quản lý Thiết bị & Đọc Sector (Sector Reader)
- **Truy cập thô (Raw Access)**: C++ mở thiết bị dưới dạng file nhị phân thô (`/dev/rdisk` trên macOS hoặc `\\.\PhysicalDrive` trên Windows). Điều này cho phép bỏ qua các lớp đệm của hệ điều hành để đọc dữ liệu bị xóa.
- **Tối ưu hóa I/O**: Dữ liệu được đọc theo từng khối (chunk) có kích thước là bội số của sector size (thường là 512 bytes hoặc 4096 bytes) để đảm bảo tốc độ cao nhất và căn chỉnh bộ nhớ chính xác.

### 3.2. Chiến lược Carving Dữ liệu (Signature-based Carving)
Lõi native áp dụng nhiều chiến lược khác nhau tùy thuộc vào loại tệp:
- **Strategy: Footer-based**: Dành cho các định dạng có cặp Header/Footer rõ ràng (như JPEG: `FF D8 FF` / `FF D9`). C++ sẽ quét bitstream tìm header, sau đó tiếp tục quét cho đến khi gặp footer tương ứng hoặc vượt quá giới hạn dung lượng (`max_size`).
- **Strategy: Size-field**: Dành cho các tệp có khai báo kích thước ngay trong header (như PDF, ZIP). C++ phân tích các byte quy định độ dài để trích xuất chính xác số byte cần thiết.
- **Strategy: Smart Carving (Video/JPEG)**:
    - **JPEG**: Kiểm tra tính toàn vẹn của cấu trúc Huffman để loại bỏ các tệp ảnh giả hoặc bị hỏng một phần.
    - **MP4/MOV**: Phân tích các `atom` (ftyp, mdat, moov). Nếu tệp thiếu `moov` atom (thường nằm ở cuối file và dễ bị mất khi xóa), hệ thống sẽ đánh dấu để thực hiện sửa lỗi.

### 3.3. Cơ chế Sửa lỗi Video (Video Repair Engine)
Đây là tính năng nâng cao giúp khôi phục các video không thể mở được sau khi carving:
- **Header Reconstruction**: Sử dụng một **Video Tham chiếu** (do người dùng cung cấp) để trích xuất cấu trúc `moov` chuẩn (codec, bitrate, track thông tin).
- **Bitstream Stitching**: Kết hợp dữ liệu thô (`mdat`) của video bị hỏng với cấu trúc đầu/cuối của video tham chiếu, sau đó tính toán lại các offset thời gian để tạo ra một file MP4 hoàn chỉnh có thể phát được.

### 3.4. Quản lý Đa luồng & An toàn
- **Isolate-safe**: Lõi C++ được thiết kế để chạy độc lập trong Isolate của Dart, không chia sẻ trạng thái global phức tạp, đảm bảo tính ổn định.
- **Flag-based Cancellation**: Cho phép người dùng dừng quét ngay lập tức bằng cách kiểm tra flag `volatile int* cancelled` trong mỗi vòng lặp quét sector, đảm bảo tài nguyên được giải phóng kịp thời.

## 4. Quy trình thực thi thực tế (Execution Flow)

Khi người dùng nhấn "BẮT ĐẦU QUÉT", hệ thống thực hiện các bước sau:

### Bước 0: Kiểm tra sức khỏe phần cứng (Pre-scan Health Check)
- Gọi `check_hardware_health` để xác định tình trạng Controller và FTL.
- Nếu phát hiện lỗi (0MB, RAW không thể đọc, I/O Error), ứng dụng sẽ hiển thị thông báo: **"Phát hiện lỗi phần cứng/firmware nghiêm trọng. Khuyến nghị sử dụng thiết bị chuyên dụng (PC-3000 Flash) để đọc trực tiếp chip NAND."**

### Bước 1: Chuẩn bị thiết bị (Unmount & Open)
- Hệ thống gọi lệnh `recovery_unmount` (thông qua FFI) để giải phóng thiết bị khỏi sự kiểm soát của OS (tránh xung đột đọc/ghi).
- Mở thiết bị ở chế độ **Raw Read** (trên macOS sử dụng `/dev/rdisk`, trên Windows sử dụng `\\.\`).

### Bước 2: Khởi tạo Isolate (Worker Thread)
- Dart khởi tạo một `Isolate` riêng biệt để chạy mã C++ thông qua `Isolate.run`.
- **Lý do**: Việc quét sector là tác vụ chặn (blocking), nếu chạy trên UI Thread sẽ gây lag ứng dụng. Isolate cho phép UI vẫn mượt mà (60fps) trong khi quét.

### Bước 3: Tiến hành Quét (Hybrid Scan)
Lõi C++ (`recovery_scan`) thực hiện quét song song hoặc tuần tự tùy theo cấu hình:
1. **Quét FAT**: Duyệt bảng FAT tìm các entry xóa.
2. **Quét Carving**: Đọc bitstream, nhận diện header/footer của JPEG, MP4, MOV, v.v.
3. **Phát sự kiện (Callback)**: Mỗi khi tìm thấy tệp hoặc có tiến triển (progress), C++ gọi ngược lại hàm callback của Dart để cập nhật UI realtime.

### Bước 4: Xử lý và Lưu trữ
- Các tệp tìm thấy được lưu tạm vào danh sách `foundFilesProvider`.
- Nếu tệp là Video bị lỗi header, hệ thống sẽ thực hiện quy trình **Header Reconstruction** dựa trên video tham chiếu đã chọn.

### Bước 5: Hoàn tất và Dọn dẹp
- Đóng handle thiết bị (`recovery_close`).
- Giải phóng bộ nhớ native.
- Thông báo kết quả tổng hợp cho người dùng.

## 4. Các thành phần mã nguồn chính (Core Components)

| Tên File | Chức năng |
| :--- | :--- |
| `recovery_bindings.dart` | Định nghĩa interface FFI, ánh xạ các hàm C++ sang Dart. |
| `recovery_service.dart` | Lớp wrapper xử lý logic Isolate, normalize đường dẫn thiết bị và quản lý dòng sự kiện (Stream). |
| `scan_provider.dart` | Quản lý trạng thái quét (Riverpod), xử lý batching (nhóm tệp) để tối ưu hiệu suất hiển thị UI. |
| `scan_screen.dart` | Giao diện hiển thị tiến độ, tốc độ (MB/s) và nhật ký quét thời gian thực. |

---
> [!IMPORTANT]
> **Lưu ý an toàn**: Ứng dụng luôn mở thiết bị ở chế độ **Read-Only** để đảm bảo không ghi đè lên dữ liệu cũ, bảo vệ tính toàn vẹn của bằng chứng kỹ thuật số.
