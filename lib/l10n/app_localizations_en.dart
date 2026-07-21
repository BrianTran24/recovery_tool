// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RECOVERY TOOL';

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
}
