// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Recovery SD Tool';

  @override
  String get onboardingTitle1 => 'RECOVERY SD TOOL';

  @override
  String get onboardingSubtitle1 => 'افتح بياناتك المفقودة!';

  @override
  String get onboardingDesc1 =>
      'حل احترافي وسريع وموثوق لاستعادة البيانات لجميع أجهزة SD الخاصة بك.';

  @override
  String get onboardingTitle2 => 'نظام فحص سريع';

  @override
  String get onboardingSubtitle2 => 'استعد بسهولة';

  @override
  String get onboardingDesc2 =>
      'تساعد خوارزميات الفحص العميق في العثور على الصور ومقاطع الفيديو والمستندات المفقودة في لحظة.';

  @override
  String get onboardingTitle3 => 'معاينة الملفات';

  @override
  String get onboardingSubtitle3 => 'شاهد قبل الاستعادة';

  @override
  String get onboardingDesc3 =>
      'قم بمعاينة البيانات أثناء عملية الفحص للتأكد من اختيار ما يهمك أكثر بالضبط.';

  @override
  String get onboardingTitle4 => 'آمن ومضمون';

  @override
  String get onboardingSubtitle4 => 'احمِ ذاكرتك';

  @override
  String get onboardingDesc4 =>
      'عملية استعادة آمنة تماماً، تضمن عدم الكتابة فوق البيانات الأصلية أو إتلافها.';

  @override
  String get skip => 'تخطي';

  @override
  String get nextStep => 'الخطوة التالية';

  @override
  String get startRecovery => 'بدء الاستعادة';

  @override
  String get sidebarDevices => 'الأجهزة';

  @override
  String get sidebarRestore => 'استعادة الصورة';

  @override
  String get sidebarWipe => 'WIPE DATA';

  @override
  String get sidebarSettings => 'الإعدادات';

  @override
  String get systemStatus => 'حالة النظام';

  @override
  String get online => 'متصل';

  @override
  String get expand => 'توسيع';

  @override
  String get collapse => 'طي';

  @override
  String get systemReady => 'النظام جاهز';

  @override
  String get connectedDevices => 'الأجهزة المتصلة';

  @override
  String get noDevicesDetected => 'لم يتم اكتشاف أي أجهزة';

  @override
  String get tryRescan => 'حاول إعادة الفحص';

  @override
  String get unknownDevice => 'جهاز غير معروف';

  @override
  String get interface => 'الواجهة';

  @override
  String get restoreData => 'استعادة البيانات';

  @override
  String get selectBackupImage => 'اختر ملف صورة النسخة الاحتياطية';

  @override
  String get supportedFormats => 'يدعم .img, .bin, .dd, .raw';

  @override
  String get browseFile => 'تصفح الملف';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Español';

  @override
  String get chinese => '简体中文';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get arabic => 'العربية';

  @override
  String get french => 'Français';

  @override
  String get russian => 'Русский';

  @override
  String get developing => 'قيد التطوير';

  @override
  String get gcTrimWarningTitle =>
      'تحذير: مخاطر جمع النفايات (Garbage Collection)';

  @override
  String get gcTrimWarningDesc =>
      'قد تقوم بطاقات SD الحديثة تلقائياً بمسح البيانات المحذوفة فعلياً أثناء وقت الخمول (Trim/GC). يوصى بـ: استنساخ البطاقة بالكامل إلى ملف .img فوراً للحفاظ على البيانات.';

  @override
  String get sourceDevice => 'الجهاز المصدر';

  @override
  String get recoveryMode => 'وضع الاستعادة';

  @override
  String get storageConfig => 'تكوين التخزين';

  @override
  String get outputDirectory => 'دليل المخرجات';

  @override
  String get deletedFiles => 'الملفات المحذوفة';

  @override
  String get existingFiles => 'الملفات الموجودة';

  @override
  String get allFiles => 'جميع الملفات';

  @override
  String get deletedFilesDesc =>
      'البحث عن الملفات التي تم حذفها من نظام الملفات واستعادتها.';

  @override
  String get existingFilesDesc =>
      'فحص وإدراج الملفات الموجودة حالياً على الجهاز.';

  @override
  String get allFilesDesc =>
      'يجمع بين الفحص لكل من الملفات الموجودة والمحذوفة.';

  @override
  String get startScanNow => 'فحص';

  @override
  String get change => 'تغيير';

  @override
  String get pleaseSelectOutputDir => 'يرجى اختيار دليل المخرجات';

  @override
  String backupImage(String path) {
    return 'صورة النسخة الاحتياطية: $path';
  }

  @override
  String get readOnlyMode => 'وضع القراءة فقط - أمان مطلق';

  @override
  String capacity(int size) {
    return 'السعة: $size جيجابايت';
  }

  @override
  String scanInitializing(String path) {
    return 'بدء جلسة الفحص لـ $path';
  }

  @override
  String scanFsIdentified(String type, int offset) {
    return 'تم التعرف: نظام ملفات $type عند القطاع $offset';
  }

  @override
  String get scanFsNotFound =>
      'تم التعرف: لم يتم العثور على نظام ملفات صالح. الانتقال إلى الفحص الخام (Signature Carving).';

  @override
  String scanScanningSector(int sector, String percent) {
    return 'فحص القطاع: $sector ($percent%)';
  }

  @override
  String scanFileFound(String filename, String type) {
    return 'تم العثور: $filename ($type)';
  }

  @override
  String scanComplete(int count, String duration) {
    return 'اكتمل: تم العثور على $count ملفات في $duration';
  }

  @override
  String scanError(String message) {
    return 'خطأ: $message';
  }

  @override
  String scanStreamError(Object error) {
    return 'خطأ في التدفق: $error';
  }

  @override
  String get scanResults => 'نتائج الفحص';

  @override
  String get scanProcessing => 'جاري معالجة البيانات...';

  @override
  String get scanStop => 'إيقاف';

  @override
  String get scanPause => 'إيقاف مؤقت';

  @override
  String get scanResume => 'استئناف';

  @override
  String get scanCancel => 'إلغاء';

  @override
  String get scanViewAllResults => 'عرض جميع النتائج';

  @override
  String scanViewLive(int count) {
    return 'عرض مباشر ($count ملفات)';
  }

  @override
  String get scanTabFiles => 'الملفات التي تم العثور عليها';

  @override
  String get scanTabLogs => 'سجلات النظام';

  @override
  String get scanSearchingFiles => 'جاري البحث عن الملفات...';

  @override
  String get scanProgress => 'تقدم الفحص';

  @override
  String get scanSpeed => 'السرعة';

  @override
  String get scanFound => 'تم العثور';

  @override
  String get scanElapsed => 'الوقت المنقضي';

  @override
  String get scanRemaining => 'الوقت المتبقي (تقديري)';

  @override
  String get scanHardwareError => 'خطأ في الأجهزة';

  @override
  String get scanSystemError => 'خطأ في النظام';

  @override
  String get scanUnderstand => 'أنا أفهم';

  @override
  String get scanNew => 'فحص جهاز آخر';

  @override
  String get openFolder => 'افتح مجلد المخرجات';

  @override
  String get freeScanMode => 'وضع الفحص والمعاينة المجاني';

  @override
  String get upgradeToSave => 'ترقية للحفظ';

  @override
  String get upgradeRequiredDesc =>
      'قم بالترقية إلى Premium لحفظ الملفات المستردة على جهاز الكمبيوتر الخاص بك.';

  @override
  String get saveToDiskPremium => 'حفظ على القرص (Premium)';

  @override
  String get premiumFeature => 'ميزة Premium';

  @override
  String get freeModeDesc =>
      'جاري الفحص إلى وحدة تخزين مؤقتة للمعاينة. قد يقوم النظام بمسح الملفات.';

  @override
  String get fileDetailTitle => 'تفاصيل الملف';

  @override
  String get fileDetailProperties => 'الخصائص';

  @override
  String get fileDetailName => 'اسم الملف';

  @override
  String get fileDetailType => 'النوع';

  @override
  String get fileDetailSize => 'الحجم';

  @override
  String get fileDetailLocation => 'المسار النسبي';

  @override
  String get fileDetailOffset => 'إزاحة القطاع';

  @override
  String get fileDetailModified => 'تاريخ التعديل';

  @override
  String get fileDetailStatus => 'حالة الاستعادة';

  @override
  String get fileDetailOpenFile => 'افتح الملف';

  @override
  String get fileDetailShowInFolder => 'عرض في المجلد';

  @override
  String get fileDetailNext => 'الملف التالي';

  @override
  String get fileDetailPrevious => 'الملف السابق';

  @override
  String get fileDetailHealthy => 'سليم';

  @override
  String get fileDetailOrphaned => 'يتيم (Orphaned)';

  @override
  String get fileDetailCarved => 'مسترد خام (Carved)';

  @override
  String get clearCache => 'مسح ذاكرة التخزين المؤقت';

  @override
  String get clearCacheDesc =>
      'احذف جميع ملفات الفحص المؤقتة لتحرير مساحة على القرص.';

  @override
  String get cacheCleared => 'تم مسح ذاكرة التخزين المؤقت بنجاح';

  @override
  String clearCacheError(String error) {
    return 'خطأ أثناء مسح ذاكرة التخزين المؤقت: $error';
  }

  @override
  String errorOpenDevice(int handle) {
    return 'خطأ في فتح الجهاز ($handle)';
  }

  @override
  String errorHardwareSerious(String message) {
    return 'تم اكتشاف خطأ فادح في الأجهزة/البرامج الثابتة: $message. يوصى بـ: استخدام معدات متخصصة (PC-3000 Flash) لقراءة شريحة NAND مباشرة.';
  }

  @override
  String errorUnknownEvent(int type) {
    return 'نوع حدث غير معروف: $type';
  }

  @override
  String get errorVerifyLicense =>
      'تعذر التحقق من الترخيص. يرجى المحاولة مرة أخرى لاحقاً.';

  @override
  String get errorTimeout =>
      'انتهت مهلة الاتصال. يرجى التحقق من الإنترنت الخاص بك.';

  @override
  String errorConnection(String error) {
    return 'خطأ في الاتصال: $error';
  }

  @override
  String get premiumActivated => 'تم تفعيل Premium بنجاح!';

  @override
  String get licenseExpired => 'انتهت صلاحية مفتاح الترخيص.';

  @override
  String get licenseInvalid => 'مفتاح الترخيص غير صالح.';

  @override
  String errorActivatePremium(String error) {
    return 'خطأ في تفعيل Premium: $error';
  }

  @override
  String get featureRemoved => 'تمت إزالة هذه الميزة.';

  @override
  String get conversionInitializing => 'جاري التهيئة...';

  @override
  String get conversionDecrypting => 'جاري فك تشفير ملف E01...';

  @override
  String conversionStatus(String percent) {
    return 'جاري التحويل: $percent%';
  }

  @override
  String get conversionComplete => 'اكتمل التحويل!';

  @override
  String get errorFileNotFoundAfterConversion =>
      'خطأ: لم يتم العثور على ملف المخرجات بعد التحويل.';

  @override
  String get conversionTitle => 'تحويل تنسيق E01';

  @override
  String get convertedRawImage => 'صورة الخام المحولة';

  @override
  String get pleaseEnterLicenseKey => 'يرجى إدخال مفتاح الترخيص';

  @override
  String get premiumActivatedTitle => 'تم تفعيل Premium!';

  @override
  String get success => 'نجاح!';

  @override
  String get accessFilesFromOutput =>
      'يمكنك الوصول إلى الملفات مباشرة من دليل المخرجات.';

  @override
  String get close => 'إغلاق';

  @override
  String get unlockPremiumTitle => 'فتح Premium';

  @override
  String get upgradeToPremium => 'ترقية إلى Premium';

  @override
  String get unlockAllFilesDesc =>
      'افتح جميع الملفات المستردة والوصول إليها مباشرة من الدليل';

  @override
  String get featureDirectAccess => 'الوصول المباشر من الدليل';

  @override
  String get featureNoWatermark => 'بدون علامة مائية';

  @override
  String get licenseKeyHint => 'أدخل مفتاح الترخيص الخاص بك';

  @override
  String get buyLicenseKey => 'شراء مفتاح الترخيص';

  @override
  String get storage => 'التخزين';

  @override
  String get debugInfo => 'معلومات التصحيح';

  @override
  String get copiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get copyEncryptionValue => 'نسخ قيمة التشفير';

  @override
  String get categoryAll => 'الكل';

  @override
  String get categoryImages => 'صور';

  @override
  String get categoryVideos => 'مقاطع فيديو';

  @override
  String get categoryDocuments => 'مستندات';

  @override
  String get searchFilesHint => 'البحث عن الملفات...';

  @override
  String previewNotAvailable(String type) {
    return 'المعاينة غير متاحة لـ $type';
  }

  @override
  String get cannotViewVideo => 'لا يمكن مشاهدة هذا الفيديو';

  @override
  String get unknown => 'غير معروف';

  @override
  String get errorIdentifyPath => 'خطأ: تعذر تحديد مسار الجهاز';

  @override
  String get backupImageFile => 'ملف صورة النسخة الاحتياطية';

  @override
  String get premiumPlan => 'خطة PREMIUM';

  @override
  String get freePlan => 'الخطة المجانية';

  @override
  String get outputConfig => 'تكوين المخرجات';

  @override
  String get selectOutputDir => 'اختر دليل المخرجات';

  @override
  String currentOutputPath(String path) {
    return 'المسار الحالي: $path';
  }

  @override
  String get authorContact => 'معلومات المؤلف';

  @override
  String get authorName => 'الاسم';

  @override
  String get authorEmail => 'البريد الإلكتروني';

  @override
  String get authorZalo => 'Zalo';

  @override
  String get authorLinkedIn => 'LinkedIn';

  @override
  String get authorFacebook => 'Facebook';

  @override
  String get premiumPrice => 'السعر: 50,000 VND / \$2 (يوم واحد)';

  @override
  String get wipeDataTitle => 'Permanently Delete Data';

  @override
  String get criticalWarning => 'CRITICAL WARNING';

  @override
  String get wipeWarningDesc =>
      'This action will overwrite all data on the device. Once performed, there is NO WAY to recover the old data. Please make sure you have backed up important data.';

  @override
  String get confirmWipeCheckbox =>
      'I understand that this action is irreversible and all data will be permanently lost.';

  @override
  String get startWipeNow => 'START PERMANENT ERASE';

  @override
  String get wipeCompleteDesc =>
      'All data on the device has been permanently erased and cannot be recovered.';

  @override
  String get backupTitle => 'BACKUP TO IMAGE';

  @override
  String get backupSaveAs => 'Save Backup As...';

  @override
  String get backupProcessing => 'CREATING DISK IMAGE...';

  @override
  String get backupComplete => 'Backup complete!';

  @override
  String backupCompleteDesc(String path) {
    return 'Backup completed successfully to $path';
  }

  @override
  String get quickFormat => 'QUICK RESET';

  @override
  String get quickFormatDesc =>
      'This will erase the partition table and file system headers, making the card \'fresh\' for your camera. All data will be inaccessible!';

  @override
  String get confirmQuickFormat => 'I want to reset this card for reuse.';

  @override
  String get formatSuccess =>
      'Card reset successfully! You can now put it back in your camera to format it properly.';
}
