// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Recovery SD Tool';

  @override
  String get onboardingTitle1 => 'RECOVERY SD TOOL';

  @override
  String get onboardingSubtitle1 => 'UNLOCK YOUR LOST DATA!';

  @override
  String get onboardingDesc1 =>
      'Professional, fast, and reliable data recovery solution for all your SD devices.';

  @override
  String get onboardingTitle2 => 'FAST SCAN SYSTEM';

  @override
  String get onboardingSubtitle2 => 'RECOVER WITH EASE';

  @override
  String get onboardingDesc2 =>
      'Deep scan algorithms help find lost photos, videos, and documents in an instant.';

  @override
  String get onboardingTitle3 => 'PREVIEW FILES';

  @override
  String get onboardingSubtitle3 => 'SEE BEFORE RESTORE';

  @override
  String get onboardingDesc3 =>
      'Preview data during the scanning process to ensure you select exactly what matters most.';

  @override
  String get onboardingTitle4 => 'SAFE & SECURE';

  @override
  String get onboardingSubtitle4 => 'PROTECT YOUR MEMORY';

  @override
  String get onboardingDesc4 =>
      'Absolutely safe recovery process, ensuring no overwriting or damage to the original data.';

  @override
  String get skip => 'SKIP';

  @override
  String get nextStep => 'NEXT STEP';

  @override
  String get startRecovery => 'START RECOVERY';

  @override
  String get sidebarDevices => 'DEVICES';

  @override
  String get sidebarRestore => 'RESTORE IMAGE';

  @override
  String get sidebarSettings => 'SETTINGS';

  @override
  String get systemStatus => 'SYSTEM STATUS';

  @override
  String get online => 'ONLINE';

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get systemReady => 'SYSTEM READY';

  @override
  String get connectedDevices => 'Connected Devices';

  @override
  String get noDevicesDetected => 'NO DEVICES DETECTED';

  @override
  String get tryRescan => 'TRY RESCAN';

  @override
  String get unknownDevice => 'Unknown Device';

  @override
  String get interface => 'INTERFACE';

  @override
  String get restoreData => 'Restore Data';

  @override
  String get selectBackupImage => 'SELECT BACKUP IMAGE FILE';

  @override
  String get supportedFormats => 'Supports .img, .bin, .dd, .raw';

  @override
  String get browseFile => 'BROWSE FILE';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get vietnamese => 'Vietnamese';

  @override
  String get english => 'English';

  @override
  String get developing => 'DEVELOPING';

  @override
  String get gcTrimWarningTitle => 'WARNING: GARBAGE COLLECTION RISK';

  @override
  String get gcTrimWarningDesc =>
      'Modern SD cards may automatically erase deleted data during idle time (Trim/GC). Recommended: Clone the entire card to an .img file immediately to preserve data.';

  @override
  String get sourceDevice => 'Source Device';

  @override
  String get recoveryMode => 'Recovery Mode';

  @override
  String get storageConfig => 'Storage Configuration';

  @override
  String get outputDirectory => 'Output Directory';

  @override
  String get deletedFiles => 'Deleted Files';

  @override
  String get existingFiles => 'Existing Files';

  @override
  String get allFiles => 'All Files';

  @override
  String get deletedFilesDesc =>
      'Find and recover files that have been deleted from the file system.';

  @override
  String get existingFilesDesc =>
      'Scan and list files currently present on the device.';

  @override
  String get allFilesDesc =>
      'Combines scanning for both existing and deleted files.';

  @override
  String get startScanNow => 'SCAN';

  @override
  String get change => 'Change';

  @override
  String get pleaseSelectOutputDir => 'Please select output directory';

  @override
  String backupImage(String path) {
    return 'Backup Image: $path';
  }

  @override
  String get readOnlyMode => 'Read-only mode - Absolute safety';

  @override
  String capacity(int size) {
    return 'Capacity: $size GB';
  }

  @override
  String scanInitializing(String path) {
    return 'Initializing scan session for $path';
  }

  @override
  String scanFsIdentified(String type, int offset) {
    return 'IDENTIFIED: File system $type at sector $offset';
  }

  @override
  String get scanFsNotFound =>
      'IDENTIFIED: No valid file system found. Switching to Signature Carving.';

  @override
  String scanScanningSector(int sector, String percent) {
    return 'Scanning Sector: $sector ($percent%)';
  }

  @override
  String scanFileFound(String filename, String type) {
    return 'FOUND: $filename ($type)';
  }

  @override
  String scanComplete(int count, String duration) {
    return 'COMPLETE: Found $count files in $duration';
  }

  @override
  String scanError(String message) {
    return 'ERROR: $message';
  }

  @override
  String scanStreamError(Object error) {
    return 'STREAM ERROR: $error';
  }

  @override
  String get scanResults => 'Scan Results';

  @override
  String get scanProcessing => 'Processing data...';

  @override
  String get scanStop => 'Stop';

  @override
  String get scanPause => 'Pause';

  @override
  String get scanResume => 'Resume';

  @override
  String get scanCancel => 'Cancel';

  @override
  String get scanViewAllResults => 'VIEW ALL RESULTS';

  @override
  String scanViewLive(int count) {
    return 'VIEW LIVE ($count files)';
  }

  @override
  String get scanTabFiles => 'Found files';

  @override
  String get scanTabLogs => 'System logs';

  @override
  String get scanSearchingFiles => 'Searching for files...';

  @override
  String get scanProgress => 'Scan Progress';

  @override
  String get scanSpeed => 'Speed';

  @override
  String get scanFound => 'FOUND';

  @override
  String get scanElapsed => 'ELAPSED';

  @override
  String get scanRemaining => 'REMAINING (EST.)';

  @override
  String get scanHardwareError => 'Hardware Error';

  @override
  String get scanSystemError => 'System Error';

  @override
  String get scanUnderstand => 'I UNDERSTAND';

  @override
  String get scanNew => 'SCAN ANOTHER DEVICE';

  @override
  String get openFolder => 'OPEN OUTPUT FOLDER';

  @override
  String get freeScanMode => 'Free Scan & Preview Mode';

  @override
  String get upgradeToSave => 'UPGRADE TO SAVE';

  @override
  String get upgradeRequiredDesc =>
      'Upgrade to Premium to save recovered files to your computer.';

  @override
  String get saveToDiskPremium => 'Save to Disk (Premium)';

  @override
  String get premiumFeature => 'Premium Feature';

  @override
  String get freeModeDesc =>
      'Scanning to temporary storage for preview. Files may be cleared by system.';

  @override
  String get fileDetailTitle => 'File Details';

  @override
  String get fileDetailProperties => 'Properties';

  @override
  String get fileDetailName => 'Filename';

  @override
  String get fileDetailType => 'Type';

  @override
  String get fileDetailSize => 'Size';

  @override
  String get fileDetailLocation => 'Relative Path';

  @override
  String get fileDetailOffset => 'Sector Offset';

  @override
  String get fileDetailModified => 'Date Modified';

  @override
  String get fileDetailStatus => 'Recovery Status';

  @override
  String get fileDetailOpenFile => 'Open File';

  @override
  String get fileDetailShowInFolder => 'Show in Folder';

  @override
  String get fileDetailNext => 'Next File';

  @override
  String get fileDetailPrevious => 'Previous File';

  @override
  String get fileDetailHealthy => 'Healthy';

  @override
  String get fileDetailOrphaned => 'Orphaned';

  @override
  String get fileDetailCarved => 'Carved';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get clearCacheDesc =>
      'Delete all temporary scan files to free up disk space.';

  @override
  String get cacheCleared => 'Cache cleared successfully';

  @override
  String clearCacheError(String error) {
    return 'Error clearing cache: $error';
  }

  @override
  String errorOpenDevice(int handle) {
    return 'Error opening device ($handle)';
  }

  @override
  String errorHardwareSerious(String message) {
    return 'Serious hardware/firmware error detected: $message. Recommended: Use specialized equipment (PC-3000 Flash) to read NAND chip directly.';
  }

  @override
  String errorUnknownEvent(int type) {
    return 'Unknown event type: $type';
  }

  @override
  String get errorVerifyLicense =>
      'Could not verify license. Please try again later.';

  @override
  String get errorTimeout => 'Connection timeout. Please check your internet.';

  @override
  String errorConnection(String error) {
    return 'Connection error: $error';
  }

  @override
  String get premiumActivated => 'Premium activated successfully!';

  @override
  String get licenseExpired => 'License key has expired.';

  @override
  String get licenseInvalid => 'Invalid license key.';

  @override
  String errorActivatePremium(String error) {
    return 'Error activating premium: $error';
  }

  @override
  String get featureRemoved => 'This feature has been removed.';

  @override
  String get conversionInitializing => 'Initializing...';

  @override
  String get conversionDecrypting => 'Decrypting E01 file...';

  @override
  String conversionStatus(String percent) {
    return 'Converting: $percent%';
  }

  @override
  String get conversionComplete => 'Conversion complete!';

  @override
  String get errorFileNotFoundAfterConversion =>
      'Error: Output file not found after conversion.';

  @override
  String get conversionTitle => 'E01 FORMAT CONVERSION';

  @override
  String get convertedRawImage => 'Converted Raw Image';

  @override
  String get pleaseEnterLicenseKey => 'Please enter license key';

  @override
  String get premiumActivatedTitle => 'Premium Activated!';

  @override
  String get askDecryptNow => 'Do you want to decrypt all files now?';

  @override
  String get later => 'Later';

  @override
  String get decryptNow => 'Decrypt Now';

  @override
  String get success => 'Success!';

  @override
  String decryptedFilesCount(int decrypted, int total) {
    return 'Successfully decrypted $decrypted/$total files!';
  }

  @override
  String get accessFilesFromOutput =>
      'You can access files directly from the output directory.';

  @override
  String get close => 'Close';

  @override
  String get unlockPremiumTitle => 'Unlock Premium';

  @override
  String get upgradeToPremium => 'Upgrade to Premium';

  @override
  String get unlockAllFilesDesc =>
      'Unlock all recovered files and access them directly from the directory';

  @override
  String get featureDecryptAll => 'Decrypt all files';

  @override
  String get featureDirectAccess => 'Direct access from directory';

  @override
  String get featureNoWatermark => 'No watermark';

  @override
  String get licenseKeyHint => 'Enter your license key';

  @override
  String get buyLicenseKey => 'Buy license key';

  @override
  String get decryptingFiles => 'Decrypting files...';

  @override
  String get preparing => 'Preparing...';

  @override
  String get dontCloseApp => 'Please do not close the application';

  @override
  String get storage => 'Storage';

  @override
  String get debugInfo => 'Debug Info';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get copyEncryptionValue => 'Copy Encryption Value';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryImages => 'Images';

  @override
  String get categoryVideos => 'Videos';

  @override
  String get categoryDocuments => 'Documents';

  @override
  String get searchFilesHint => 'Search files...';

  @override
  String previewNotAvailable(String type) {
    return 'Preview not available for $type';
  }

  @override
  String get cannotViewVideo => 'Cannot view this video';

  @override
  String get unknown => 'Unknown';

  @override
  String get errorIdentifyPath => 'Error: Could not identify device path';

  @override
  String get backupImageFile => 'Backup Image File';

  @override
  String get premiumPlan => 'PREMIUM PLAN';

  @override
  String get freePlan => 'FREE PLAN';

  @override
  String get outputConfig => 'Output Configuration';

  @override
  String get selectOutputDir => 'Select Output Directory';

  @override
  String currentOutputPath(String path) {
    return 'Current Path: $path';
  }
}
