// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Recovery SD Tool';

  @override
  String get onboardingTitle1 => 'RECOVERY SD TOOL';

  @override
  String get onboardingSubtitle1 => '¡DESBLOQUEA TUS DATOS PERDIDOS!';

  @override
  String get onboardingDesc1 =>
      'Solución de recuperación de datos profesional, rápida y confiable para todos sus dispositivos SD.';

  @override
  String get onboardingTitle2 => 'SISTEMA DE ESCANEO RÁPIDO';

  @override
  String get onboardingSubtitle2 => 'RECUPERA CON FACILIDAD';

  @override
  String get onboardingDesc2 =>
      'Los algoritmos de escaneo profundo ayudan a encontrar fotos, videos y documentos perdidos en un instante.';

  @override
  String get onboardingTitle3 => 'VISTA PREVIA DE ARCHIVOS';

  @override
  String get onboardingSubtitle3 => 'VER ANTES DE RESTAURAR';

  @override
  String get onboardingDesc3 =>
      'Previsualice los datos durante el proceso de escaneo para asegurarse de seleccionar exactamente lo que más importa.';

  @override
  String get onboardingTitle4 => 'SEGURO Y PROTEGIDO';

  @override
  String get onboardingSubtitle4 => 'PROTEGE TU MEMORIA';

  @override
  String get onboardingDesc4 =>
      'Proceso de recuperación absolutamente seguro, garantizando que no se sobrescriban ni dañen los datos originales.';

  @override
  String get skip => 'SALTAR';

  @override
  String get nextStep => 'SIGUIENTE PASO';

  @override
  String get startRecovery => 'INICIAR RECUPERACIÓN';

  @override
  String get sidebarDevices => 'DISPOSITIVOS';

  @override
  String get sidebarRestore => 'RESTAURAR IMAGEN';

  @override
  String get sidebarWipe => 'WIPE DATA';

  @override
  String get sidebarSettings => 'AJUSTES';

  @override
  String get systemStatus => 'ESTADO DEL SISTEMA';

  @override
  String get online => 'EN LÍNEA';

  @override
  String get expand => 'Expandir';

  @override
  String get collapse => 'Colapsar';

  @override
  String get systemReady => 'SISTEMA LISTO';

  @override
  String get connectedDevices => 'Dispositivos Conectados';

  @override
  String get noDevicesDetected => 'NO SE DETECTARON DISPOSITIVOS';

  @override
  String get tryRescan => 'REINTENTAR ESCANEO';

  @override
  String get unknownDevice => 'Dispositivo Desconocido';

  @override
  String get interface => 'INTERFAZ';

  @override
  String get restoreData => 'Restaurar Datos';

  @override
  String get selectBackupImage => 'SELECCIONAR ARCHIVO DE IMAGEN DE RESPALDO';

  @override
  String get supportedFormats => 'Soporta .img, .bin, .dd, .raw';

  @override
  String get browseFile => 'BUSCAR ARCHIVO';

  @override
  String get settings => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Seleccionar Idioma';

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
  String get developing => 'EN DESARROLLO';

  @override
  String get gcTrimWarningTitle =>
      'ADVERTENCIA: RIESGO DE RECOLECCIÓN DE BASURA';

  @override
  String get gcTrimWarningDesc =>
      'Las tarjetas SD modernas pueden borrar automáticamente los datos eliminados durante el tiempo de inactividad (Trim/GC). Recomendado: Clone toda la tarjeta a un archivo .img inmediatamente para preservar los datos.';

  @override
  String get sourceDevice => 'Dispositivo Origen';

  @override
  String get recoveryMode => 'Modo de Recuperación';

  @override
  String get storageConfig => 'Configuración de Almacenamiento';

  @override
  String get outputDirectory => 'Directorio de Salida';

  @override
  String get deletedFiles => 'Archivos Eliminados';

  @override
  String get existingFiles => 'Archivos Existentes';

  @override
  String get allFiles => 'Todos los Archivos';

  @override
  String get deletedFilesDesc =>
      'Busque y recupere archivos que han sido eliminados del sistema de archivos.';

  @override
  String get existingFilesDesc =>
      'Escanee y enumere los archivos presentes actualmente en el dispositivo.';

  @override
  String get allFilesDesc =>
      'Combina el escaneo de archivos existentes y eliminados.';

  @override
  String get startScanNow => 'ESCANEAR';

  @override
  String get change => 'Cambiar';

  @override
  String get pleaseSelectOutputDir =>
      'Por favor seleccione el directorio de salida';

  @override
  String backupImage(String path) {
    return 'Imagen de Respaldo: $path';
  }

  @override
  String get readOnlyMode => 'Modo de solo lectura - Seguridad absoluta';

  @override
  String capacity(int size) {
    return 'Capacidad: $size GB';
  }

  @override
  String scanInitializing(String path) {
    return 'Iniciando sesión de escaneo para $path';
  }

  @override
  String scanFsIdentified(String type, int offset) {
    return 'IDENTIFICADO: Sistema de archivos $type en el sector $offset';
  }

  @override
  String get scanFsNotFound =>
      'IDENTIFICADO: No se encontró un sistema de archivos válido. Cambiando a Signature Carving.';

  @override
  String scanScanningSector(int sector, String percent) {
    return 'Escaneando Sector: $sector ($percent%)';
  }

  @override
  String scanFileFound(String filename, String type) {
    return 'ENCONTRADO: $filename ($type)';
  }

  @override
  String scanComplete(int count, String duration) {
    return 'COMPLETO: Se encontraron $count archivos en $duration';
  }

  @override
  String scanError(String message) {
    return 'ERROR: $message';
  }

  @override
  String scanStreamError(Object error) {
    return 'ERROR DE FLUJO: $error';
  }

  @override
  String get scanResults => 'Resultados del Escaneo';

  @override
  String get scanProcessing => 'Procesando datos...';

  @override
  String get scanStop => 'Detener';

  @override
  String get scanPause => 'Pausar';

  @override
  String get scanResume => 'Reanudar';

  @override
  String get scanCancel => 'Cancelar';

  @override
  String get scanViewAllResults => 'VER TODOS LOS RESULTADOS';

  @override
  String scanViewLive(int count) {
    return 'VER EN VIVO ($count archivos)';
  }

  @override
  String get scanTabFiles => 'Archivos encontrados';

  @override
  String get scanTabLogs => 'Registros del sistema';

  @override
  String get scanSearchingFiles => 'Buscando archivos...';

  @override
  String get scanProgress => 'Progreso del Escaneo';

  @override
  String get scanSpeed => 'Velocidad';

  @override
  String get scanFound => 'ENCONTRADO';

  @override
  String get scanElapsed => 'TRANSCURRIDO';

  @override
  String get scanRemaining => 'RESTANTE (EST.)';

  @override
  String get scanHardwareError => 'Error de Hardware';

  @override
  String get scanSystemError => 'Error de Sistema';

  @override
  String get scanUnderstand => 'LO ENTIENDO';

  @override
  String get scanNew => 'ESCANEAR OTRO DISPOSITIVO';

  @override
  String get openFolder => 'ABRIR CARPETA DE SALIDA';

  @override
  String get freeScanMode => 'Modo de Escaneo y Vista Previa Gratis';

  @override
  String get upgradeToSave => 'MEJORAR PARA GUARDAR';

  @override
  String get upgradeRequiredDesc =>
      'Mejore a Premium para guardar archivos recuperados en su computadora.';

  @override
  String get saveToDiskPremium => 'Guardar en disco (Premium)';

  @override
  String get premiumFeature => 'Función Premium';

  @override
  String get freeModeDesc =>
      'Escaneando a almacenamiento temporal para vista previa. Los archivos pueden ser borrados por el sistema.';

  @override
  String get fileDetailTitle => 'Detalles del Archivo';

  @override
  String get fileDetailProperties => 'Propiedades';

  @override
  String get fileDetailName => 'Nombre de archivo';

  @override
  String get fileDetailType => 'Tipo';

  @override
  String get fileDetailSize => 'Tamaño';

  @override
  String get fileDetailLocation => 'Ruta Relativa';

  @override
  String get fileDetailOffset => 'Desplazamiento de Sector';

  @override
  String get fileDetailModified => 'Fecha de Modificación';

  @override
  String get fileDetailStatus => 'Estado de Recuperación';

  @override
  String get fileDetailOpenFile => 'Abrir Archivo';

  @override
  String get fileDetailShowInFolder => 'Mostrar en Carpeta';

  @override
  String get fileDetailNext => 'Siguiente Archivo';

  @override
  String get fileDetailPrevious => 'Archivo Anterior';

  @override
  String get fileDetailHealthy => 'Saludable';

  @override
  String get fileDetailOrphaned => 'Huérfano';

  @override
  String get fileDetailCarved => 'Recuperado (Carved)';

  @override
  String get clearCache => 'Limpiar Caché';

  @override
  String get clearCacheDesc =>
      'Elimina todos los archivos temporales de escaneo para liberar espacio en disco.';

  @override
  String get cacheCleared => 'Caché limpiado con éxito';

  @override
  String clearCacheError(String error) {
    return 'Error al limpiar caché: $error';
  }

  @override
  String errorOpenDevice(int handle) {
    return 'Error al abrir el dispositivo ($handle)';
  }

  @override
  String errorHardwareSerious(String message) {
    return 'Error grave de hardware/firmware detectado: $message. Recomendado: Use equipo especializado (PC-3000 Flash) para leer el chip NAND directamente.';
  }

  @override
  String errorUnknownEvent(int type) {
    return 'Tipo de evento desconocido: $type';
  }

  @override
  String get errorVerifyLicense =>
      ' No se pudo verificar la licencia. Inténtelo de nuevo más tarde.';

  @override
  String get errorTimeout =>
      'Tiempo de espera de conexión agotado. Por favor, compruebe su internet.';

  @override
  String errorConnection(String error) {
    return 'Error de conexión: $error';
  }

  @override
  String get premiumActivated => '¡Premium activado con éxito!';

  @override
  String get licenseExpired => 'La clave de licencia ha caducado.';

  @override
  String get licenseInvalid => 'Clave de licencia inválida.';

  @override
  String errorActivatePremium(String error) {
    return 'Error al activar premium: $error';
  }

  @override
  String get featureRemoved => 'Esta función ha sido eliminada.';

  @override
  String get conversionInitializing => 'Inicializando...';

  @override
  String get conversionDecrypting => 'Descifrando archivo E01...';

  @override
  String conversionStatus(String percent) {
    return 'Convirtiendo: $percent%';
  }

  @override
  String get conversionComplete => '¡Conversión completa!';

  @override
  String get errorFileNotFoundAfterConversion =>
      'Error: Archivo de salida no encontrado después de la conversión.';

  @override
  String get conversionTitle => 'CONVERSIÓN DE FORMATO E01';

  @override
  String get convertedRawImage => 'Imagen Raw Convertida';

  @override
  String get pleaseEnterLicenseKey =>
      'Por favor, introduzca la clave de licencia';

  @override
  String get premiumActivatedTitle => '¡Premium Activado!';

  @override
  String get success => '¡Éxito!';

  @override
  String get accessFilesFromOutput =>
      'Puede acceder a los archivos directamente desde el directorio de salida.';

  @override
  String get close => 'Cerrar';

  @override
  String get unlockPremiumTitle => 'Desbloquear Premium';

  @override
  String get upgradeToPremium => 'Mejorar a Premium';

  @override
  String get unlockAllFilesDesc =>
      'Desbloquea todos los archivos recuperados y accede a ellos directamente desde el directorio';

  @override
  String get featureDirectAccess => 'Acceso directo desde el directorio';

  @override
  String get featureNoWatermark => 'Sin marca de agua';

  @override
  String get licenseKeyHint => 'Introduzca su clave de licencia';

  @override
  String get buyLicenseKey => 'Comprar clave de licencia';

  @override
  String get storage => 'Almacenamiento';

  @override
  String get debugInfo => 'Info de Depuración';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get copyEncryptionValue => 'Copiar Valor de Cifrado';

  @override
  String get categoryAll => 'Todos';

  @override
  String get categoryImages => 'Imágenes';

  @override
  String get categoryVideos => 'Videos';

  @override
  String get categoryDocuments => 'Documentos';

  @override
  String get searchFilesHint => 'Buscar archivos...';

  @override
  String previewNotAvailable(String type) {
    return 'Vista previa no disponible para $type';
  }

  @override
  String get cannotViewVideo => 'No se puede ver este video';

  @override
  String get unknown => 'Desconocido';

  @override
  String get errorIdentifyPath =>
      'Error: No se pudo identificar la ruta del dispositivo';

  @override
  String get backupImageFile => 'Archivo de Imagen de Respaldo';

  @override
  String get premiumPlan => 'PLAN PREMIUM';

  @override
  String get freePlan => 'PLAN GRATUITO';

  @override
  String get outputConfig => 'Configuración de Salida';

  @override
  String get selectOutputDir => 'Seleccionar Directorio de Salida';

  @override
  String currentOutputPath(String path) {
    return 'Ruta Actual: $path';
  }

  @override
  String get authorContact => 'Contacto del Autor';

  @override
  String get authorName => 'Nombre';

  @override
  String get authorEmail => 'Correo electrónico';

  @override
  String get authorZalo => 'Zalo';

  @override
  String get authorLinkedIn => 'LinkedIn';

  @override
  String get authorFacebook => 'Facebook';

  @override
  String get premiumPrice => 'Precio: 50.000 VND / \$2 (1 Día)';

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
