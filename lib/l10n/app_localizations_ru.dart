// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Recovery SD Tool';

  @override
  String get onboardingTitle1 => 'RECOVERY SD TOOL';

  @override
  String get onboardingSubtitle1 => 'РАЗБЛОКИРУЙТЕ ВАШИ ПОТЕРЯННЫЕ ДАННЫЕ!';

  @override
  String get onboardingDesc1 =>
      'Профессиональное, быстрое и надежное решение для восстановления данных для всех ваших SD-устройств.';

  @override
  String get onboardingTitle2 => 'СИСТЕМА БЫСТРОГО СКАНИРОВАНИЯ';

  @override
  String get onboardingSubtitle2 => 'ВОССТАНАВЛИВАЙТЕ С ЛЕГКОСТЬЮ';

  @override
  String get onboardingDesc2 =>
      'Алгоритмы глубокого сканирования помогут в мгновение ока найти потерянные фотографии, видео и документы.';

  @override
  String get onboardingTitle3 => 'ПРЕДПРОСМОТР ФАЙЛОВ';

  @override
  String get onboardingSubtitle3 => 'ПОСМОТРИТЕ ПЕРЕД ВОССТАНОВЛЕНИЕМ';

  @override
  String get onboardingDesc3 =>
      'Предварительно просмотрите данные в процессе сканирования, чтобы убедиться, что вы выбрали именно то, что важнее всего.';

  @override
  String get onboardingTitle4 => 'БЕЗОПАСНО И НАДЕЖНО';

  @override
  String get onboardingSubtitle4 => 'ЗАЩИТИТЕ СВОЮ ПАМЯТЬ';

  @override
  String get onboardingDesc4 =>
      'Абсолютно безопасный процесс восстановления, гарантирующий отсутствие перезаписи или повреждения исходных данных.';

  @override
  String get skip => 'ПРОПУСТИТЬ';

  @override
  String get nextStep => 'СЛЕДУЮЩИЙ ШАГ';

  @override
  String get startRecovery => 'НАЧАТЬ ВОССТАНОВЛЕНИЕ';

  @override
  String get sidebarDevices => 'УСТРОЙСТВА';

  @override
  String get sidebarRestore => 'ВОССТАНОВИТЬ ОБРАЗ';

  @override
  String get sidebarWipe => 'WIPE DATA';

  @override
  String get sidebarSettings => 'НАСТРОЙКИ';

  @override
  String get systemStatus => 'СТАТУС СИСТЕМЫ';

  @override
  String get online => 'В СЕТИ';

  @override
  String get expand => 'Развернуть';

  @override
  String get collapse => 'Свернуть';

  @override
  String get systemReady => 'СИСТЕМА ГОТОВА';

  @override
  String get connectedDevices => 'Подключенные устройства';

  @override
  String get noDevicesDetected => 'УСТРОЙСТВА НЕ ОБНАРУЖЕНЫ';

  @override
  String get tryRescan => 'ПОВТОРИТЬ СКАНИРОВАНИЕ';

  @override
  String get unknownDevice => 'Неизвестное устройство';

  @override
  String get interface => 'ИНТЕРФЕЙС';

  @override
  String get restoreData => 'Восстановить данные';

  @override
  String get selectBackupImage => 'ВЫБЕРИТЕ ФАЙЛ ОБРАЗА РЕЗЕРВНОЙ КОПИИ';

  @override
  String get supportedFormats => 'Поддерживает .img, .bin, .dd, .raw';

  @override
  String get browseFile => 'ОБЗОР ФАЙЛА';

  @override
  String get settings => 'Настройки';

  @override
  String get language => 'Язык';

  @override
  String get selectLanguage => 'Выбрать язык';

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
  String get developing => 'В РАЗРАБОТКЕ';

  @override
  String get gcTrimWarningTitle =>
      'ПРЕДУПРЕЖДЕНИЕ: РИСК СБОРА МУСОРА (Garbage Collection)';

  @override
  String get gcTrimWarningDesc =>
      'Современные SD-карты могут автоматически физически стирать удаленные данные во время простоя (Trim/GC). Рекомендуется: Немедленно клонируйте всю карту в файл .img для сохранения данных.';

  @override
  String get sourceDevice => 'Исходное устройство';

  @override
  String get recoveryMode => 'Режим восстановления';

  @override
  String get storageConfig => 'Конфигурация хранилища';

  @override
  String get outputDirectory => 'Выходной каталог';

  @override
  String get deletedFiles => 'Удаленные файлы';

  @override
  String get existingFiles => 'Существующие файлы';

  @override
  String get allFiles => 'Все файлы';

  @override
  String get deletedFilesDesc =>
      'Поиск и восстановление файлов, удаленных из файловой системы.';

  @override
  String get existingFilesDesc =>
      'Сканирование и список файлов, присутствующих на устройстве в данный момент.';

  @override
  String get allFilesDesc =>
      'Объединяет сканирование существующих и удаленных файлов.';

  @override
  String get startScanNow => 'СКАНИРОВАТЬ';

  @override
  String get change => 'Изменить';

  @override
  String get pleaseSelectOutputDir => 'Пожалуйста, выберите выходной каталог';

  @override
  String backupImage(String path) {
    return 'Образ резервной копии: $path';
  }

  @override
  String get readOnlyMode => 'Режим «только чтение» — абсолютная безопасность';

  @override
  String capacity(int size) {
    return 'Емкость: $size ГБ';
  }

  @override
  String scanInitializing(String path) {
    return 'Инициализация сеанса сканирования для $path';
  }

  @override
  String scanFsIdentified(String type, int offset) {
    return 'ИДЕНТИФИЦИРОВАНО: Файловая система $type в секторе $offset';
  }

  @override
  String get scanFsNotFound =>
      'ИДЕНТИФИЦИРОВАНО: Допустимая файловая система не найдена. Переключение на Signature Carving.';

  @override
  String scanScanningSector(int sector, String percent) {
    return 'Сканирование сектора: $sector ($percent%)';
  }

  @override
  String scanFileFound(String filename, String type) {
    return 'НАЙДЕНО: $filename ($type)';
  }

  @override
  String scanComplete(int count, String duration) {
    return 'ЗАВЕРШЕНО: Найдено $count файлов за $duration';
  }

  @override
  String scanError(String message) {
    return 'ОШИБКА: $message';
  }

  @override
  String scanStreamError(Object error) {
    return 'ОШИБКА ПОТОКА: $error';
  }

  @override
  String get scanResults => 'Результаты сканирования';

  @override
  String get scanProcessing => 'Обработка данных...';

  @override
  String get scanStop => 'Стоп';

  @override
  String get scanPause => 'Пауза';

  @override
  String get scanResume => 'Продолжить';

  @override
  String get scanCancel => 'Отмена';

  @override
  String get scanViewAllResults => 'ПОСМОТРЕТЬ ВСЕ РЕЗУЛЬТАТЫ';

  @override
  String scanViewLive(int count) {
    return 'ПОСМОТРЕТЬ В РЕАЛЬНОМ ВРЕМЕНИ ($count файлов)';
  }

  @override
  String get scanTabFiles => 'Найденные файлы';

  @override
  String get scanTabLogs => 'Системные логи';

  @override
  String get scanSearchingFiles => 'Поиск файлов...';

  @override
  String get scanProgress => 'Прогресс сканирования';

  @override
  String get scanSpeed => 'Скорость';

  @override
  String get scanFound => 'НАЙДЕНО';

  @override
  String get scanElapsed => 'ПРОШЛО';

  @override
  String get scanRemaining => 'ОСТАЛОСЬ (ПРИМЕРНО)';

  @override
  String get scanHardwareError => 'Ошибка оборудования';

  @override
  String get scanSystemError => 'Системная ошибка';

  @override
  String get scanUnderstand => 'Я ПОНИМАЮ';

  @override
  String get scanNew => 'СКАНИРОВАТЬ ДРУГОЕ УСТРОЙСТВО';

  @override
  String get openFolder => 'ОТКРЫТЬ ПАПКУ ВЫВОДА';

  @override
  String get freeScanMode => 'Бесплатный режим сканирования и предпросмотра';

  @override
  String get upgradeToSave => 'ОБНОВИТЕСЬ, ЧТОБЫ СОХРАНИТЬ';

  @override
  String get upgradeRequiredDesc =>
      'Обновитесь до Premium, чтобы сохранять восстановленные файлы на свой компьютер.';

  @override
  String get saveToDiskPremium => 'Сохранить на диск (Premium)';

  @override
  String get premiumFeature => 'Premium функция';

  @override
  String get freeModeDesc =>
      'Сканирование во временное хранилище для предпросмотра. Файлы могут быть удалены системой.';

  @override
  String get fileDetailTitle => 'Детали файла';

  @override
  String get fileDetailProperties => 'Свойства';

  @override
  String get fileDetailName => 'Имя файла';

  @override
  String get fileDetailType => 'Тип';

  @override
  String get fileDetailSize => 'Размер';

  @override
  String get fileDetailLocation => 'Относительный путь';

  @override
  String get fileDetailOffset => 'Смещение сектора';

  @override
  String get fileDetailModified => 'Дата изменения';

  @override
  String get fileDetailStatus => 'Статус восстановления';

  @override
  String get fileDetailOpenFile => 'Открыть файл';

  @override
  String get fileDetailShowInFolder => 'Показать в папке';

  @override
  String get fileDetailNext => 'Следующий файл';

  @override
  String get fileDetailPrevious => 'Предыдущий файл';

  @override
  String get fileDetailHealthy => 'Целый';

  @override
  String get fileDetailOrphaned => 'Потерянный (Orphaned)';

  @override
  String get fileDetailCarved => 'Восстановлен по сигнатуре (Carved)';

  @override
  String get clearCache => 'Очистить кэш';

  @override
  String get clearCacheDesc =>
      'Удалить все временные файлы сканирования, чтобы освободить место на диске.';

  @override
  String get cacheCleared => 'Кэш успешно очищен';

  @override
  String clearCacheError(String error) {
    return 'Ошибка при очистке кэша: $error';
  }

  @override
  String errorOpenDevice(int handle) {
    return 'Ошибка открытия устройства ($handle)';
  }

  @override
  String errorHardwareSerious(String message) {
    return 'Обнаружена серьезная ошибка оборудования/прошивки: $message. Рекомендуется: Использовать специализированное оборудование (PC-3000 Flash) для прямого чтения чипа NAND.';
  }

  @override
  String errorUnknownEvent(int type) {
    return 'Неизвестный тип события: $type';
  }

  @override
  String get errorVerifyLicense =>
      'Не удалось проверить лицензию. Пожалуйста, попробуйте позже.';

  @override
  String get errorTimeout =>
      'Тайм-аут подключения. Пожалуйста, проверьте ваш интернет.';

  @override
  String errorConnection(String error) {
    return 'Ошибка подключения: $error';
  }

  @override
  String get premiumActivated => 'Premium успешно активирован!';

  @override
  String get licenseExpired => 'Лицензионный ключ истек.';

  @override
  String get licenseInvalid => 'Неверный лицензионный ключ.';

  @override
  String errorActivatePremium(String error) {
    return 'Ошибка активации premium: $error';
  }

  @override
  String get featureRemoved => 'Эта функция была удалена.';

  @override
  String get conversionInitializing => 'Инициализация...';

  @override
  String get conversionDecrypting => 'Расшифровка файла E01...';

  @override
  String conversionStatus(String percent) {
    return 'Конвертация: $percent%';
  }

  @override
  String get conversionComplete => 'Конвертация завершена!';

  @override
  String get errorFileNotFoundAfterConversion =>
      'Ошибка: Выходной файл не найден после конвертации.';

  @override
  String get conversionTitle => 'КОНВЕРТАЦИЯ ФОРМАТА E01';

  @override
  String get convertedRawImage => 'Конвертированный Raw образ';

  @override
  String get pleaseEnterLicenseKey => 'Пожалуйста, введите лицензионный ключ';

  @override
  String get premiumActivatedTitle => 'Premium активирован!';

  @override
  String get success => 'Успех!';

  @override
  String get accessFilesFromOutput =>
      'Вы можете получить доступ к файлам напрямую из выходного каталога.';

  @override
  String get close => 'Закрыть';

  @override
  String get unlockPremiumTitle => 'Разблокировать Premium';

  @override
  String get upgradeToPremium => 'Обновиться до Premium';

  @override
  String get unlockAllFilesDesc =>
      'Разблокируйте все восстановленные файлы и получите к ним прямой доступ из каталога';

  @override
  String get featureDirectAccess => 'Прямой доступ из каталога';

  @override
  String get featureNoWatermark => 'Без водяного знака';

  @override
  String get licenseKeyHint => 'Введите лицензионный ключ';

  @override
  String get buyLicenseKey => 'Купить лицензионный ключ';

  @override
  String get storage => 'Хранилище';

  @override
  String get debugInfo => 'Отладочная информация';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get copyEncryptionValue => 'Копировать значение шифрования';

  @override
  String get categoryAll => 'Все';

  @override
  String get categoryImages => 'Изображения';

  @override
  String get categoryVideos => 'Видео';

  @override
  String get categoryDocuments => 'Документы';

  @override
  String get searchFilesHint => 'Поиск файлов...';

  @override
  String previewNotAvailable(String type) {
    return 'Предпросмотр недоступен для $type';
  }

  @override
  String get cannotViewVideo => 'Невозможно просмотреть это видео';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get errorIdentifyPath =>
      'Ошибка: Не удалось идентифицировать путь к устройству';

  @override
  String get backupImageFile => 'Файл образа резервной копии';

  @override
  String get premiumPlan => 'PREMIUM ПЛАН';

  @override
  String get freePlan => 'БЕСПЛАТНЫЙ ПЛАН';

  @override
  String get outputConfig => 'Конфигурация вывода';

  @override
  String get selectOutputDir => 'Выбрать выходной каталог';

  @override
  String currentOutputPath(String path) {
    return 'Текущий путь: $path';
  }

  @override
  String get authorContact => 'Контакты автора';

  @override
  String get authorName => 'Имя';

  @override
  String get authorEmail => 'Email';

  @override
  String get authorZalo => 'Zalo';

  @override
  String get authorLinkedIn => 'LinkedIn';

  @override
  String get authorFacebook => 'Facebook';

  @override
  String get premiumPrice =>
      'Цена: 50 000 вьетнамских донгов / 2 доллара США (1 день)';

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
