// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Recovery SD Tool';

  @override
  String get onboardingTitle1 => 'RECOVERY SD TOOL';

  @override
  String get onboardingSubtitle1 => 'UNLOCK YOUR LOST DATA!';

  @override
  String get onboardingDesc1 =>
      'Giải pháp khôi phục dữ liệu chuyên nghiệp, nhanh chóng và tin cậy cho mọi thiết bị SD của bạn.';

  @override
  String get onboardingTitle2 => 'FAST SCAN SYSTEM';

  @override
  String get onboardingSubtitle2 => 'RECOVER WITH EASE';

  @override
  String get onboardingDesc2 =>
      'Thuật toán quét sâu giúp tìm lại ảnh, video và tài liệu bị mất trong tích tắc.';

  @override
  String get onboardingTitle3 => 'PREVIEW FILES';

  @override
  String get onboardingSubtitle3 => 'SEE BEFORE RESTORE';

  @override
  String get onboardingDesc3 =>
      'Xem lại dữ liệu ngay trong quá trình quét để đảm bảo bạn chọn đúng những gì quan trọng nhất.';

  @override
  String get onboardingTitle4 => 'SAFE & SECURE';

  @override
  String get onboardingSubtitle4 => 'PROTECT YOUR MEMORY';

  @override
  String get onboardingDesc4 =>
      'Quy trình khôi phục an toàn tuyệt đối, đảm bảo không ghi đè hay làm hỏng dữ liệu gốc.';

  @override
  String get skip => 'BỎ QUA';

  @override
  String get nextStep => 'BƯỚC TIẾP THEO';

  @override
  String get startRecovery => 'BẮT ĐẦU KHÔI PHỤC';

  @override
  String get sidebarDevices => 'THIẾT BỊ';

  @override
  String get sidebarRestore => 'KHÔI PHỤC ẢNH';

  @override
  String get sidebarSettings => 'CÀI ĐẶT';

  @override
  String get systemStatus => 'TRẠNG THÁI HỆ THỐNG';

  @override
  String get online => 'TRỰC TUYẾN';

  @override
  String get expand => 'Mở rộng';

  @override
  String get collapse => 'Thu gọn';

  @override
  String get systemReady => 'HỆ THỐNG SẴN SÀNG';

  @override
  String get connectedDevices => 'Thiết Bị Kết Nối';

  @override
  String get noDevicesDetected => 'CHƯA PHÁT HIỆN THIẾT BỊ';

  @override
  String get tryRescan => 'THỬ QUÉT LẠI';

  @override
  String get unknownDevice => 'Thiết bị không xác định';

  @override
  String get interface => 'GIAO DIỆN';

  @override
  String get restoreData => 'Khôi Phục Dữ Liệu';

  @override
  String get selectBackupImage => 'CHỌN FILE ẢNH BACKUP';

  @override
  String get supportedFormats => 'Hỗ trợ .img, .bin, .dd, .raw';

  @override
  String get browseFile => 'DUYỆT FILE';

  @override
  String get settings => 'Cài đặt';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get selectLanguage => 'Chọn ngôn ngữ';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get english => 'Tiếng Anh';

  @override
  String get developing => 'ĐANG PHÁT TRIỂN';

  @override
  String get gcTrimWarningTitle => 'CẢNH BÁO: RỦI RO GARBAGE COLLECTION';

  @override
  String get gcTrimWarningDesc =>
      'Thẻ nhớ hiện đại có thể tự động xóa vật lý dữ liệu đã xóa trong lúc nhàn rỗi (Trim/GC). Khuyên dùng: Hãy clone toàn bộ thẻ sang file .img ngay lập tức để bảo toàn dữ liệu.';

  @override
  String get sourceDevice => 'Thiết bị nguồn';

  @override
  String get recoveryMode => 'Chế độ khôi phục';

  @override
  String get storageConfig => 'Cấu hình lưu trữ';

  @override
  String get outputDirectory => 'Thư mục đầu ra';

  @override
  String get deletedFiles => 'File đã xóa';

  @override
  String get existingFiles => 'File hiện có';

  @override
  String get allFiles => 'Tất cả file';

  @override
  String get deletedFilesDesc =>
      'Tìm kiếm và khôi phục các tệp tin đã bị xóa khỏi hệ thống.';

  @override
  String get existingFilesDesc =>
      'Quét và liệt kê các tệp tin đang tồn tại trên thiết bị.';

  @override
  String get allFilesDesc => 'Kết hợp quét cả file hiện có và file đã xóa.';

  @override
  String get startScanNow => 'QUÉT';

  @override
  String get change => 'Thay đổi';

  @override
  String get pleaseSelectOutputDir => 'Vui lòng chọn thư mục lưu file';

  @override
  String backupImage(String path) {
    return 'Ảnh backup: $path';
  }

  @override
  String get readOnlyMode => 'Chế độ chỉ đọc - An toàn tuyệt đối';

  @override
  String capacity(int size) {
    return 'Dung lượng: $size GB';
  }

  @override
  String scanInitializing(String path) {
    return 'Khởi tạo phiên quét cho $path';
  }

  @override
  String scanFsIdentified(String type, int offset) {
    return 'NHẬN DIỆN: Hệ thống tập tin $type tại sector $offset';
  }

  @override
  String get scanFsNotFound =>
      'NHẬN DIỆN: Không tìm thấy hệ thống tập tin hợp lệ. Chuyển sang quét thô (Signature Carving).';

  @override
  String scanScanningSector(int sector, String percent) {
    return 'Đang quét Sector: $sector ($percent%)';
  }

  @override
  String scanFileFound(String filename, String type) {
    return 'TÌM THẤY: $filename ($type)';
  }

  @override
  String scanComplete(int count, String duration) {
    return 'HOÀN THÀNH: Tìm thấy $count file trong $duration';
  }

  @override
  String scanError(String message) {
    return 'LỖI: $message';
  }

  @override
  String scanStreamError(Object error) {
    return 'LỖI STREAM: $error';
  }

  @override
  String get scanResults => 'Kết quả Quét';

  @override
  String get scanProcessing => 'Đang xử lý dữ liệu...';

  @override
  String get scanStop => 'Dừng';

  @override
  String get scanPause => 'Tạm dừng';

  @override
  String get scanResume => 'Tiếp tục';

  @override
  String get scanCancel => 'Hủy';

  @override
  String get scanViewAllResults => 'XEM TOÀN BỘ KẾT QUẢ';

  @override
  String scanViewLive(int count) {
    return 'XEM TRỰC TIẾP ($count file)';
  }

  @override
  String get scanTabFiles => 'Tệp tin tìm thấy';

  @override
  String get scanTabLogs => 'Nhật ký hệ thống';

  @override
  String get scanSearchingFiles => 'Đang tìm kiếm tệp tin...';

  @override
  String get scanProgress => 'Tiến độ quét';

  @override
  String get scanSpeed => 'Tốc độ';

  @override
  String get scanFound => 'TÌM THẤY';

  @override
  String get scanElapsed => 'ĐÃ TRÔI QUA';

  @override
  String get scanRemaining => 'CÒN LẠI (DỰ KIẾN)';

  @override
  String get scanHardwareError => 'Lỗi Phần Cứng';

  @override
  String get scanSystemError => 'Lỗi Hệ Thống';

  @override
  String get scanUnderstand => 'ĐÃ HIỂU';

  @override
  String get scanNew => 'QUÉT THIẾT BỊ KHÁC';

  @override
  String get openFolder => 'MỞ THƯ MỤC LƯU FILE';

  @override
  String get fileDetailTitle => 'Chi tiết Tệp tin';

  @override
  String get fileDetailProperties => 'Thuộc tính';

  @override
  String get fileDetailName => 'Tên tệp';

  @override
  String get fileDetailType => 'Loại';

  @override
  String get fileDetailSize => 'Kích thước';

  @override
  String get fileDetailLocation => 'Đường dẫn tương đối';

  @override
  String get fileDetailOffset => 'Vị trí Sector';

  @override
  String get fileDetailModified => 'Ngày sửa đổi';

  @override
  String get fileDetailStatus => 'Trạng thái khôi phục';

  @override
  String get fileDetailOpenFile => 'Mở Tệp';

  @override
  String get fileDetailShowInFolder => 'Xem trong thư mục';

  @override
  String get fileDetailNext => 'Tệp tiếp theo';

  @override
  String get fileDetailPrevious => 'Tệp trước đó';

  @override
  String get fileDetailHealthy => 'Tốt';

  @override
  String get fileDetailOrphaned => 'Thất lạc (Orphaned)';

  @override
  String get fileDetailCarved => 'Khôi phục thô (Carved)';
}
