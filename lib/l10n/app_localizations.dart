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
