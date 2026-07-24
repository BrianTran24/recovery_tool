# Hướng dẫn Phát hành và Công chứng Ứng dụng Recovery SD

Tài liệu này tổng hợp các bước cần thiết để phát hành ứng dụng ngoài cửa hàng chính thức (Store) và quy trình công chứng (Notarization) trên macOS.

---

## 1. Tổng quan về việc phát hành ngoài Store

Vì ứng dụng yêu cầu quyền truy cập vào dữ liệu thô (Raw Disk Access) và sử dụng thư viện Native (C++), việc phát hành ngoài Store là lựa chọn tối ưu để tránh các hạn chế bảo mật khắt khe.

### A. Đối với Windows
Ứng dụng cần chạy với quyền **Administrator** để đọc `\\.\PhysicalDrive`.
1. **Cấu hình Manifest:** Chỉnh sửa `windows/runner/runner.exe.manifest` để thêm `requestedExecutionLevel level="requireAdministrator"`.
2. **Build:** `flutter build windows --release`.
3. **Đóng gói:** Sử dụng **Inno Setup** để tạo file `.exe` cài đặt.

### B. Đối với macOS
1. **Entitlements:** Đảm bảo `com.apple.security.app-sandbox` là `false` trong `Release.entitlements`.
2. **Quyền người dùng:** Nhắc người dùng cấp quyền **Full Disk Access** trong System Settings.

---

## 2. Quy trình Công chứng (Notarization) chi tiết trên macOS

Đây là bước bắt buộc để tránh cảnh báo "App is damaged" khi người dùng tải ứng dụng từ internet.

### Điều kiện cần
- Tài khoản Apple Developer trả phí ($99/năm).
- **Team ID:** Tìm thấy tại [developer.apple.com](https://developer.apple.com/account) -> mục **Membership**. (Mã 10 ký tự như `AB12345XYZ`).
- **App-Specific Password:** Tạo tại [appleid.apple.com](https://appleid.apple.com) -> phần **App-Specific Passwords**.

> [!IMPORTANT]
> **notary-profile là gì?**
> Thực chất đây là một "biệt danh" (alias) bạn tự đặt để đại diện cho thông tin xác thực của mình. Thông tin này được lưu an toàn trong Keychain của macOS, giúp bạn không cần nhập lại mật khẩu mỗi lần công chứng.

### Các bước thực hiện (Sử dụng Terminal)

#### Bước 1: Build và Nén ứng dụng
```bash
flutter build macos --release
ditto -c -k --keepParent build/macos/Build/Products/Release/recovery_tool.app recovery_tool.zip
```

#### Bước 2: Lưu thông tin xác thực vào Keychain (Chỉ làm 1 lần duy nhất)
Sử dụng lệnh sau để tạo profile có tên là `notary-profile`:
```bash
xcrun notarytool store-credentials "notary-profile" \
    --apple-id "email_cua_ban@example.com" \
    --team-id "TEAM_ID_CUA_BAN" \
    --password "abcd-efgh-ijkl-mnop"
```

#### Bước 3: Gửi lên Apple để công chứng
```bash
xcrun notarytool submit recovery_tool.zip --keychain-profile "notary-profile" --wait
```
*Đợi cho đến khi trạng thái báo `status: Accepted`.*

#### Bước 4: Đóng dấu công chứng (Stapling)
```bash
xcrun stapler staple build/macos/Build/Products/Release/recovery_tool.app
```

#### Bước 5: Kiểm tra kết quả
```bash
spctl --assess -vv --type install build/macos/Build/Products/Release/recovery_tool.app
```
*Kết quả phải có dòng `source=Notarized Developer ID`.*

---

## 3. Tự động hóa với Script

Bạn có thể sử dụng script có sẵn trong dự án để thực hiện toàn bộ quy trình trên một cách nhanh chóng.

### Cấu hình file .env
Tạo file `.env` ở thư mục gốc của dự án với nội dung sau:
```env
APPLE_ID=email_cua_ban@example.com
APPLE_TEAM_ID=TEAM_ID_CUA_BAN
APPLE_PASSWORD=abcd-efgh-ijkl-mnop
NOTARY_PROFILE=notary-profile
```

### Chạy Script
```bash
chmod +x scripts/notarize_macos.sh
./scripts/notarize_macos.sh
```
*Script sẽ tự động kiểm tra xem `notary-profile` đã tồn tại chưa và hướng dẫn bạn tạo nếu thiếu.*

---

## 4. Đóng gói file .DMG
Sau khi đã công chứng xong, hãy chạy script tạo file cài đặt:
```bash
./scripts/build_dmg.sh
```

---

## 5. Kênh phân phối gợi ý
- **GitHub Releases:** Phù hợp nhất để quản lý phiên bản và mã nguồn.
- **Website riêng:** Tạo trang giới thiệu và đặt link tải file `.dmg` hoặc `.exe` đã đóng gói.
