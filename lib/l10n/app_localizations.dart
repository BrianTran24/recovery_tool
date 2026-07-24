import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery SD Tool'**
  String get appTitle;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'RECOVERY SD TOOL'**
  String get onboardingTitle1;

  /// No description provided for @onboardingSubtitle1.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK YOUR LOST DATA!'**
  String get onboardingSubtitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Professional, fast, and reliable data recovery solution for all your SD devices.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'FAST SCAN SYSTEM'**
  String get onboardingTitle2;

  /// No description provided for @onboardingSubtitle2.
  ///
  /// In en, this message translates to:
  /// **'RECOVER WITH EASE'**
  String get onboardingSubtitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Deep scan algorithms help find lost photos, videos, and documents in an instant.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW FILES'**
  String get onboardingTitle3;

  /// No description provided for @onboardingSubtitle3.
  ///
  /// In en, this message translates to:
  /// **'SEE BEFORE RESTORE'**
  String get onboardingSubtitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Preview data during the scanning process to ensure you select exactly what matters most.'**
  String get onboardingDesc3;

  /// No description provided for @onboardingTitle4.
  ///
  /// In en, this message translates to:
  /// **'SAFE & SECURE'**
  String get onboardingTitle4;

  /// No description provided for @onboardingSubtitle4.
  ///
  /// In en, this message translates to:
  /// **'PROTECT YOUR MEMORY'**
  String get onboardingSubtitle4;

  /// No description provided for @onboardingDesc4.
  ///
  /// In en, this message translates to:
  /// **'Absolutely safe recovery process, ensuring no overwriting or damage to the original data.'**
  String get onboardingDesc4;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get skip;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'NEXT STEP'**
  String get nextStep;

  /// No description provided for @startRecovery.
  ///
  /// In en, this message translates to:
  /// **'START RECOVERY'**
  String get startRecovery;

  /// No description provided for @sidebarDevices.
  ///
  /// In en, this message translates to:
  /// **'DEVICES'**
  String get sidebarDevices;

  /// No description provided for @sidebarRestore.
  ///
  /// In en, this message translates to:
  /// **'RESTORE IMAGE'**
  String get sidebarRestore;

  /// No description provided for @sidebarSettings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get sidebarSettings;

  /// No description provided for @systemStatus.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM STATUS'**
  String get systemStatus;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get online;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @systemReady.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM READY'**
  String get systemReady;

  /// No description provided for @connectedDevices.
  ///
  /// In en, this message translates to:
  /// **'Connected Devices'**
  String get connectedDevices;

  /// No description provided for @noDevicesDetected.
  ///
  /// In en, this message translates to:
  /// **'NO DEVICES DETECTED'**
  String get noDevicesDetected;

  /// No description provided for @tryRescan.
  ///
  /// In en, this message translates to:
  /// **'TRY RESCAN'**
  String get tryRescan;

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDevice;

  /// No description provided for @interface.
  ///
  /// In en, this message translates to:
  /// **'INTERFACE'**
  String get interface;

  /// No description provided for @restoreData.
  ///
  /// In en, this message translates to:
  /// **'Restore Data'**
  String get restoreData;

  /// No description provided for @selectBackupImage.
  ///
  /// In en, this message translates to:
  /// **'SELECT BACKUP IMAGE FILE'**
  String get selectBackupImage;

  /// No description provided for @supportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Supports .img, .bin, .dd, .raw'**
  String get supportedFormats;

  /// No description provided for @browseFile.
  ///
  /// In en, this message translates to:
  /// **'BROWSE FILE'**
  String get browseFile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @developing.
  ///
  /// In en, this message translates to:
  /// **'DEVELOPING'**
  String get developing;

  /// No description provided for @gcTrimWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'WARNING: GARBAGE COLLECTION RISK'**
  String get gcTrimWarningTitle;

  /// No description provided for @gcTrimWarningDesc.
  ///
  /// In en, this message translates to:
  /// **'Modern SD cards may automatically erase deleted data during idle time (Trim/GC). Recommended: Clone the entire card to an .img file immediately to preserve data.'**
  String get gcTrimWarningDesc;

  /// No description provided for @sourceDevice.
  ///
  /// In en, this message translates to:
  /// **'Source Device'**
  String get sourceDevice;

  /// No description provided for @recoveryMode.
  ///
  /// In en, this message translates to:
  /// **'Recovery Mode'**
  String get recoveryMode;

  /// No description provided for @storageConfig.
  ///
  /// In en, this message translates to:
  /// **'Storage Configuration'**
  String get storageConfig;

  /// No description provided for @outputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Output Directory'**
  String get outputDirectory;

  /// No description provided for @deletedFiles.
  ///
  /// In en, this message translates to:
  /// **'Deleted Files'**
  String get deletedFiles;

  /// No description provided for @existingFiles.
  ///
  /// In en, this message translates to:
  /// **'Existing Files'**
  String get existingFiles;

  /// No description provided for @allFiles.
  ///
  /// In en, this message translates to:
  /// **'All Files'**
  String get allFiles;

  /// No description provided for @deletedFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Find and recover files that have been deleted from the file system.'**
  String get deletedFilesDesc;

  /// No description provided for @existingFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan and list files currently present on the device.'**
  String get existingFilesDesc;

  /// No description provided for @allFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Combines scanning for both existing and deleted files.'**
  String get allFilesDesc;

  /// No description provided for @startScanNow.
  ///
  /// In en, this message translates to:
  /// **'SCAN'**
  String get startScanNow;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @pleaseSelectOutputDir.
  ///
  /// In en, this message translates to:
  /// **'Please select output directory'**
  String get pleaseSelectOutputDir;

  /// No description provided for @backupImage.
  ///
  /// In en, this message translates to:
  /// **'Backup Image: {path}'**
  String backupImage(String path);

  /// No description provided for @readOnlyMode.
  ///
  /// In en, this message translates to:
  /// **'Read-only mode - Absolute safety'**
  String get readOnlyMode;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity: {size} GB'**
  String capacity(int size);

  /// No description provided for @scanInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing scan session for {path}'**
  String scanInitializing(String path);

  /// No description provided for @scanFsIdentified.
  ///
  /// In en, this message translates to:
  /// **'IDENTIFIED: File system {type} at sector {offset}'**
  String scanFsIdentified(String type, int offset);

  /// No description provided for @scanFsNotFound.
  ///
  /// In en, this message translates to:
  /// **'IDENTIFIED: No valid file system found. Switching to Signature Carving.'**
  String get scanFsNotFound;

  /// No description provided for @scanScanningSector.
  ///
  /// In en, this message translates to:
  /// **'Scanning Sector: {sector} ({percent}%)'**
  String scanScanningSector(int sector, String percent);

  /// No description provided for @scanFileFound.
  ///
  /// In en, this message translates to:
  /// **'FOUND: {filename} ({type})'**
  String scanFileFound(String filename, String type);

  /// No description provided for @scanComplete.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE: Found {count} files in {duration}'**
  String scanComplete(int count, String duration);

  /// No description provided for @scanError.
  ///
  /// In en, this message translates to:
  /// **'ERROR: {message}'**
  String scanError(String message);

  /// No description provided for @scanStreamError.
  ///
  /// In en, this message translates to:
  /// **'STREAM ERROR: {error}'**
  String scanStreamError(Object error);

  /// No description provided for @scanResults.
  ///
  /// In en, this message translates to:
  /// **'Scan Results'**
  String get scanResults;

  /// No description provided for @scanProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing data...'**
  String get scanProcessing;

  /// No description provided for @scanStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get scanStop;

  /// No description provided for @scanPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get scanPause;

  /// No description provided for @scanResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get scanResume;

  /// No description provided for @scanCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get scanCancel;

  /// No description provided for @scanViewAllResults.
  ///
  /// In en, this message translates to:
  /// **'VIEW ALL RESULTS'**
  String get scanViewAllResults;

  /// No description provided for @scanViewLive.
  ///
  /// In en, this message translates to:
  /// **'VIEW LIVE ({count} files)'**
  String scanViewLive(int count);

  /// No description provided for @scanTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Found files'**
  String get scanTabFiles;

  /// No description provided for @scanTabLogs.
  ///
  /// In en, this message translates to:
  /// **'System logs'**
  String get scanTabLogs;

  /// No description provided for @scanSearchingFiles.
  ///
  /// In en, this message translates to:
  /// **'Searching for files...'**
  String get scanSearchingFiles;

  /// No description provided for @scanProgress.
  ///
  /// In en, this message translates to:
  /// **'Scan Progress'**
  String get scanProgress;

  /// No description provided for @scanSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get scanSpeed;

  /// No description provided for @scanFound.
  ///
  /// In en, this message translates to:
  /// **'FOUND'**
  String get scanFound;

  /// No description provided for @scanElapsed.
  ///
  /// In en, this message translates to:
  /// **'ELAPSED'**
  String get scanElapsed;

  /// No description provided for @scanRemaining.
  ///
  /// In en, this message translates to:
  /// **'REMAINING (EST.)'**
  String get scanRemaining;

  /// No description provided for @scanHardwareError.
  ///
  /// In en, this message translates to:
  /// **'Hardware Error'**
  String get scanHardwareError;

  /// No description provided for @scanSystemError.
  ///
  /// In en, this message translates to:
  /// **'System Error'**
  String get scanSystemError;

  /// No description provided for @scanUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I UNDERSTAND'**
  String get scanUnderstand;

  /// No description provided for @scanNew.
  ///
  /// In en, this message translates to:
  /// **'SCAN ANOTHER DEVICE'**
  String get scanNew;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'OPEN OUTPUT FOLDER'**
  String get openFolder;

  /// No description provided for @freeScanMode.
  ///
  /// In en, this message translates to:
  /// **'Free Scan & Preview Mode'**
  String get freeScanMode;

  /// No description provided for @upgradeToSave.
  ///
  /// In en, this message translates to:
  /// **'UPGRADE TO SAVE'**
  String get upgradeToSave;

  /// No description provided for @upgradeRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium to save recovered files to your computer.'**
  String get upgradeRequiredDesc;

  /// No description provided for @saveToDiskPremium.
  ///
  /// In en, this message translates to:
  /// **'Save to Disk (Premium)'**
  String get saveToDiskPremium;

  /// No description provided for @premiumFeature.
  ///
  /// In en, this message translates to:
  /// **'Premium Feature'**
  String get premiumFeature;

  /// No description provided for @freeModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Scanning to temporary storage for preview. Files may be cleared by system.'**
  String get freeModeDesc;

  /// No description provided for @fileDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'File Details'**
  String get fileDetailTitle;

  /// No description provided for @fileDetailProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get fileDetailProperties;

  /// No description provided for @fileDetailName.
  ///
  /// In en, this message translates to:
  /// **'Filename'**
  String get fileDetailName;

  /// No description provided for @fileDetailType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fileDetailType;

  /// No description provided for @fileDetailSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fileDetailSize;

  /// No description provided for @fileDetailLocation.
  ///
  /// In en, this message translates to:
  /// **'Relative Path'**
  String get fileDetailLocation;

  /// No description provided for @fileDetailOffset.
  ///
  /// In en, this message translates to:
  /// **'Sector Offset'**
  String get fileDetailOffset;

  /// No description provided for @fileDetailModified.
  ///
  /// In en, this message translates to:
  /// **'Date Modified'**
  String get fileDetailModified;

  /// No description provided for @fileDetailStatus.
  ///
  /// In en, this message translates to:
  /// **'Recovery Status'**
  String get fileDetailStatus;

  /// No description provided for @fileDetailOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get fileDetailOpenFile;

  /// No description provided for @fileDetailShowInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in Folder'**
  String get fileDetailShowInFolder;

  /// No description provided for @fileDetailNext.
  ///
  /// In en, this message translates to:
  /// **'Next File'**
  String get fileDetailNext;

  /// No description provided for @fileDetailPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous File'**
  String get fileDetailPrevious;

  /// No description provided for @fileDetailHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get fileDetailHealthy;

  /// No description provided for @fileDetailOrphaned.
  ///
  /// In en, this message translates to:
  /// **'Orphaned'**
  String get fileDetailOrphaned;

  /// No description provided for @fileDetailCarved.
  ///
  /// In en, this message translates to:
  /// **'Carved'**
  String get fileDetailCarved;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @clearCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Delete all temporary scan files to free up disk space.'**
  String get clearCacheDesc;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get cacheCleared;

  /// No description provided for @clearCacheError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing cache: {error}'**
  String clearCacheError(String error);

  /// No description provided for @errorOpenDevice.
  ///
  /// In en, this message translates to:
  /// **'Error opening device ({handle})'**
  String errorOpenDevice(int handle);

  /// No description provided for @errorHardwareSerious.
  ///
  /// In en, this message translates to:
  /// **'Serious hardware/firmware error detected: {message}. Recommended: Use specialized equipment (PC-3000 Flash) to read NAND chip directly.'**
  String errorHardwareSerious(String message);

  /// No description provided for @errorUnknownEvent.
  ///
  /// In en, this message translates to:
  /// **'Unknown event type: {type}'**
  String errorUnknownEvent(int type);

  /// No description provided for @errorVerifyLicense.
  ///
  /// In en, this message translates to:
  /// **'Could not verify license. Please try again later.'**
  String get errorVerifyLicense;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timeout. Please check your internet.'**
  String get errorTimeout;

  /// No description provided for @errorConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection error: {error}'**
  String errorConnection(String error);

  /// No description provided for @premiumActivated.
  ///
  /// In en, this message translates to:
  /// **'Premium activated successfully!'**
  String get premiumActivated;

  /// No description provided for @licenseExpired.
  ///
  /// In en, this message translates to:
  /// **'License key has expired.'**
  String get licenseExpired;

  /// No description provided for @licenseInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid license key.'**
  String get licenseInvalid;

  /// No description provided for @errorActivatePremium.
  ///
  /// In en, this message translates to:
  /// **'Error activating premium: {error}'**
  String errorActivatePremium(String error);

  /// No description provided for @featureRemoved.
  ///
  /// In en, this message translates to:
  /// **'This feature has been removed.'**
  String get featureRemoved;

  /// No description provided for @conversionInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing...'**
  String get conversionInitializing;

  /// No description provided for @conversionDecrypting.
  ///
  /// In en, this message translates to:
  /// **'Decrypting E01 file...'**
  String get conversionDecrypting;

  /// No description provided for @conversionStatus.
  ///
  /// In en, this message translates to:
  /// **'Converting: {percent}%'**
  String conversionStatus(String percent);

  /// No description provided for @conversionComplete.
  ///
  /// In en, this message translates to:
  /// **'Conversion complete!'**
  String get conversionComplete;

  /// No description provided for @errorFileNotFoundAfterConversion.
  ///
  /// In en, this message translates to:
  /// **'Error: Output file not found after conversion.'**
  String get errorFileNotFoundAfterConversion;

  /// No description provided for @conversionTitle.
  ///
  /// In en, this message translates to:
  /// **'E01 FORMAT CONVERSION'**
  String get conversionTitle;

  /// No description provided for @convertedRawImage.
  ///
  /// In en, this message translates to:
  /// **'Converted Raw Image'**
  String get convertedRawImage;

  /// No description provided for @pleaseEnterLicenseKey.
  ///
  /// In en, this message translates to:
  /// **'Please enter license key'**
  String get pleaseEnterLicenseKey;

  /// No description provided for @premiumActivatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Activated!'**
  String get premiumActivatedTitle;

  /// No description provided for @askDecryptNow.
  ///
  /// In en, this message translates to:
  /// **'Do you want to decrypt all files now?'**
  String get askDecryptNow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @decryptNow.
  ///
  /// In en, this message translates to:
  /// **'Decrypt Now'**
  String get decryptNow;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get success;

  /// No description provided for @decryptedFilesCount.
  ///
  /// In en, this message translates to:
  /// **'Successfully decrypted {decrypted}/{total} files!'**
  String decryptedFilesCount(int decrypted, int total);

  /// No description provided for @accessFilesFromOutput.
  ///
  /// In en, this message translates to:
  /// **'You can access files directly from the output directory.'**
  String get accessFilesFromOutput;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @unlockPremiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Premium'**
  String get unlockPremiumTitle;

  /// No description provided for @upgradeToPremium.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get upgradeToPremium;

  /// No description provided for @unlockAllFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock all recovered files and access them directly from the directory'**
  String get unlockAllFilesDesc;

  /// No description provided for @featureDecryptAll.
  ///
  /// In en, this message translates to:
  /// **'Decrypt all files'**
  String get featureDecryptAll;

  /// No description provided for @featureDirectAccess.
  ///
  /// In en, this message translates to:
  /// **'Direct access from directory'**
  String get featureDirectAccess;

  /// No description provided for @featureNoWatermark.
  ///
  /// In en, this message translates to:
  /// **'No watermark'**
  String get featureNoWatermark;

  /// No description provided for @licenseKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your license key'**
  String get licenseKeyHint;

  /// No description provided for @buyLicenseKey.
  ///
  /// In en, this message translates to:
  /// **'Buy license key'**
  String get buyLicenseKey;

  /// No description provided for @decryptingFiles.
  ///
  /// In en, this message translates to:
  /// **'Decrypting files...'**
  String get decryptingFiles;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get preparing;

  /// No description provided for @dontCloseApp.
  ///
  /// In en, this message translates to:
  /// **'Please do not close the application'**
  String get dontCloseApp;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @debugInfo.
  ///
  /// In en, this message translates to:
  /// **'Debug Info'**
  String get debugInfo;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @copyEncryptionValue.
  ///
  /// In en, this message translates to:
  /// **'Copy Encryption Value'**
  String get copyEncryptionValue;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @categoryImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get categoryImages;

  /// No description provided for @categoryVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get categoryVideos;

  /// No description provided for @categoryDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get categoryDocuments;

  /// No description provided for @searchFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Search files...'**
  String get searchFilesHint;

  /// No description provided for @previewNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Preview not available for {type}'**
  String previewNotAvailable(String type);

  /// No description provided for @cannotViewVideo.
  ///
  /// In en, this message translates to:
  /// **'Cannot view this video'**
  String get cannotViewVideo;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @errorIdentifyPath.
  ///
  /// In en, this message translates to:
  /// **'Error: Could not identify device path'**
  String get errorIdentifyPath;

  /// No description provided for @backupImageFile.
  ///
  /// In en, this message translates to:
  /// **'Backup Image File'**
  String get backupImageFile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
