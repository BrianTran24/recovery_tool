// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Recovery SD Tool';

  @override
  String get onboardingTitle1 => 'RECOVERY SD TOOL';

  @override
  String get onboardingSubtitle1 => 'DÉBLOQUEZ VOS DONNÉES PERDUES !';

  @override
  String get onboardingDesc1 =>
      'Solution de récupération de données professionnelle, rapide et fiable pour tous vos appareils SD.';

  @override
  String get onboardingTitle2 => 'SYSTÈME DE SCAN RAPIDE';

  @override
  String get onboardingSubtitle2 => 'RÉCUPÉREZ FACILEMENT';

  @override
  String get onboardingDesc2 =>
      'Les algorithmes de scan approfondi aident à retrouver instantanément les photos, vidéos et documents perdus.';

  @override
  String get onboardingTitle3 => 'APERÇU DES FICHIERS';

  @override
  String get onboardingSubtitle3 => 'VOIR AVANT DE RESTAURER';

  @override
  String get onboardingDesc3 =>
      'Prévisualisez les données pendant le processus de scan pour vous assurer de sélectionner exactement ce qui compte le plus.';

  @override
  String get onboardingTitle4 => 'SÛR ET SÉCURISÉ';

  @override
  String get onboardingSubtitle4 => 'PROTÉGEZ VOTRE MÉMOIRE';

  @override
  String get onboardingDesc4 =>
      'Processus de récupération absolument sûr, garantissant l\'absence de réécriture ou de dommage aux données originales.';

  @override
  String get skip => 'PASSER';

  @override
  String get nextStep => 'ÉTAPE SUIVANTE';

  @override
  String get startRecovery => 'DÉMARRER LA RÉCUPÉRATION';

  @override
  String get sidebarDevices => 'APPAREILS';

  @override
  String get sidebarRestore => 'RESTAURER L\'IMAGE';

  @override
  String get sidebarWipe => 'WIPE DATA';

  @override
  String get sidebarSettings => 'PARAMÈTRES';

  @override
  String get systemStatus => 'ÉTAT DU SYSTÈME';

  @override
  String get online => 'EN LIGNE';

  @override
  String get expand => 'Développer';

  @override
  String get collapse => 'Réduire';

  @override
  String get systemReady => 'SYSTÈME PRÊT';

  @override
  String get connectedDevices => 'Appareils Connectés';

  @override
  String get noDevicesDetected => 'AUCUN APPAREIL DÉTECTÉ';

  @override
  String get tryRescan => 'RÉESSAYER LE SCAN';

  @override
  String get unknownDevice => 'Appareil Inconnu';

  @override
  String get interface => 'INTERFACE';

  @override
  String get restoreData => 'Restaurer les Données';

  @override
  String get selectBackupImage => 'SÉLECTIONNER LE FICHIER IMAGE DE SAUVEGARDE';

  @override
  String get supportedFormats => 'Supporte .img, .bin, .dd, .raw';

  @override
  String get browseFile => 'PARCOURIR LE FICHIER';

  @override
  String get settings => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get selectLanguage => 'Choisir la Langue';

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
  String get developing => 'EN DÉVELOPPEMENT';

  @override
  String get gcTrimWarningTitle =>
      'AVERTISSEMENT : RISQUE DE GARBAGE COLLECTION';

  @override
  String get gcTrimWarningDesc =>
      'Les cartes SD modernes peuvent effacer automatiquement les données supprimées pendant le temps d\'inactivité (Trim/GC). Recommandé : Clonez immédiatement toute la carte dans un fichier .img pour préserver les données.';

  @override
  String get sourceDevice => 'Appareil Source';

  @override
  String get recoveryMode => 'Mode de Récupération';

  @override
  String get storageConfig => 'Configuration du Stockage';

  @override
  String get outputDirectory => 'Répertoire de Sortie';

  @override
  String get deletedFiles => 'Fichiers Supprimés';

  @override
  String get existingFiles => 'Fichiers Existants';

  @override
  String get allFiles => 'Tous les Fichiers';

  @override
  String get deletedFilesDesc =>
      'Recherchez et récupérez les fichiers qui ont été supprimés du système de fichiers.';

  @override
  String get existingFilesDesc =>
      'Scannez et listez les fichiers actuellement présents sur l\'appareil.';

  @override
  String get allFilesDesc =>
      'Combine le scan pour les fichiers existants et supprimés.';

  @override
  String get startScanNow => 'SCANNER';

  @override
  String get change => 'Modifier';

  @override
  String get pleaseSelectOutputDir =>
      'Veuillez sélectionner le répertoire de sortie';

  @override
  String backupImage(String path) {
    return 'Image de Sauvegarde : $path';
  }

  @override
  String get readOnlyMode => 'Mode lecture seule - Sécurité absolue';

  @override
  String capacity(int size) {
    return 'Capacité : $size Go';
  }

  @override
  String scanInitializing(String path) {
    return 'Initialisation de la session de scan pour $path';
  }

  @override
  String scanFsIdentified(String type, int offset) {
    return 'IDENTIFIÉ : Système de fichiers $type au secteur $offset';
  }

  @override
  String get scanFsNotFound =>
      'IDENTIFIÉ : Aucun système de fichiers valide trouvé. Passage à la Signature Carving.';

  @override
  String scanScanningSector(int sector, String percent) {
    return 'Scan du secteur : $sector ($percent%)';
  }

  @override
  String scanFileFound(String filename, String type) {
    return 'TROUVÉ : $filename ($type)';
  }

  @override
  String scanComplete(int count, String duration) {
    return 'TERMINÉ : $count fichiers trouvés en $duration';
  }

  @override
  String scanError(String message) {
    return 'ERREUR : $message';
  }

  @override
  String scanStreamError(Object error) {
    return 'ERREUR DE FLUX : $error';
  }

  @override
  String get scanResults => 'Résultats du Scan';

  @override
  String get scanProcessing => 'Traitement des données...';

  @override
  String get scanStop => 'Arrêter';

  @override
  String get scanPause => 'Pause';

  @override
  String get scanResume => 'Reprendre';

  @override
  String get scanCancel => 'Annuler';

  @override
  String get scanViewAllResults => 'VOIR TOUS LES RÉSULTATS';

  @override
  String scanViewLive(int count) {
    return 'VOIR EN DIRECT ($count fichiers)';
  }

  @override
  String get scanTabFiles => 'Fichiers trouvés';

  @override
  String get scanTabLogs => 'Journaux système';

  @override
  String get scanSearchingFiles => 'Recherche de fichiers...';

  @override
  String get scanProgress => 'Progression du Scan';

  @override
  String get scanSpeed => 'Vitesse';

  @override
  String get scanFound => 'TROUVÉ';

  @override
  String get scanElapsed => 'ÉCOULÉ';

  @override
  String get scanRemaining => 'RESTANT (EST.)';

  @override
  String get scanHardwareError => 'Erreur Matérielle';

  @override
  String get scanSystemError => 'Erreur Système';

  @override
  String get scanUnderstand => 'JE COMPRENDS';

  @override
  String get scanNew => 'SCANNER UN AUTRE APPAREIL';

  @override
  String get openFolder => 'OUVRIR LE DOSSIER DE SORTIE';

  @override
  String get freeScanMode => 'Mode Scan & Aperçu Gratuit';

  @override
  String get upgradeToSave => 'PASSER À LA VERSION SUPÉRIEURE POUR ENREGISTRER';

  @override
  String get upgradeRequiredDesc =>
      'Passez à la version Premium pour enregistrer les fichiers récupérés sur votre ordinateur.';

  @override
  String get saveToDiskPremium => 'Enregistrer sur le disque (Premium)';

  @override
  String get premiumFeature => 'Fonctionnalité Premium';

  @override
  String get freeModeDesc =>
      'Scan vers le stockage temporaire pour aperçu. Les fichiers peuvent être effacés par le système.';

  @override
  String get fileDetailTitle => 'Détails du Fichier';

  @override
  String get fileDetailProperties => 'Propriétés';

  @override
  String get fileDetailName => 'Nom du fichier';

  @override
  String get fileDetailType => 'Type';

  @override
  String get fileDetailSize => 'Taille';

  @override
  String get fileDetailLocation => 'Chemin Relatif';

  @override
  String get fileDetailOffset => 'Offset du secteur';

  @override
  String get fileDetailModified => 'Date de modification';

  @override
  String get fileDetailStatus => 'État de récupération';

  @override
  String get fileDetailOpenFile => 'Ouvrir le fichier';

  @override
  String get fileDetailShowInFolder => 'Afficher dans le dossier';

  @override
  String get fileDetailNext => 'Fichier suivant';

  @override
  String get fileDetailPrevious => 'Fichier précédent';

  @override
  String get fileDetailHealthy => 'Sain';

  @override
  String get fileDetailOrphaned => 'Orphelin (Orphaned)';

  @override
  String get fileDetailCarved => 'Récupéré par signature (Carved)';

  @override
  String get clearCache => 'Vider le cache';

  @override
  String get clearCacheDesc =>
      'Supprimer tous les fichiers de scan temporaires pour libérer de l\'espace disque.';

  @override
  String get cacheCleared => 'Cache vidé avec succès';

  @override
  String clearCacheError(String error) {
    return 'Erreur lors du vidage du cache : $error';
  }

  @override
  String errorOpenDevice(int handle) {
    return 'Erreur lors de l\'ouverture de l\'appareil ($handle)';
  }

  @override
  String errorHardwareSerious(String message) {
    return 'Erreur matérielle/firmware grave détectée : $message. Recommandé : Utiliser un équipement spécialisé (PC-3000 Flash) pour lire directement la puce NAND.';
  }

  @override
  String errorUnknownEvent(int type) {
    return 'Type d\'événement inconnu : $type';
  }

  @override
  String get errorVerifyLicense =>
      'Impossible de vérifier la licence. Veuillez réessayer plus tard.';

  @override
  String get errorTimeout =>
      'Délai de connexion dépassé. Veuillez vérifier votre connexion internet.';

  @override
  String errorConnection(String error) {
    return 'Erreur de connexion : $error';
  }

  @override
  String get premiumActivated => 'Premium activé avec succès !';

  @override
  String get licenseExpired => 'La clé de licence a expiré.';

  @override
  String get licenseInvalid => 'Clé de licence invalide.';

  @override
  String errorActivatePremium(String error) {
    return 'Erreur lors de l\'activation du premium : $error';
  }

  @override
  String get featureRemoved => 'Cette fonctionnalité a été supprimée.';

  @override
  String get conversionInitializing => 'Initialisation...';

  @override
  String get conversionDecrypting => 'Déchiffrement du fichier E01...';

  @override
  String conversionStatus(String percent) {
    return 'Conversion en cours : $percent%';
  }

  @override
  String get conversionComplete => 'Conversion terminée !';

  @override
  String get errorFileNotFoundAfterConversion =>
      'Erreur : Fichier de sortie introuvable après la conversion.';

  @override
  String get conversionTitle => 'CONVERSION DE FORMAT E01';

  @override
  String get convertedRawImage => 'Image Raw convertie';

  @override
  String get pleaseEnterLicenseKey => 'Veuillez saisir la clé de licence';

  @override
  String get premiumActivatedTitle => 'Premium Activé !';

  @override
  String get success => 'Succès !';

  @override
  String get accessFilesFromOutput =>
      'Vous pouvez accéder aux fichiers directement depuis le répertoire de sortie.';

  @override
  String get close => 'Fermer';

  @override
  String get unlockPremiumTitle => 'Débloquer le Premium';

  @override
  String get upgradeToPremium => 'Passer au Premium';

  @override
  String get unlockAllFilesDesc =>
      'Débloquez tous les fichiers récupérés et accédez-y directement depuis le répertoire';

  @override
  String get featureDirectAccess => 'Accès direct depuis le répertoire';

  @override
  String get featureNoWatermark => 'Sans filigrane';

  @override
  String get licenseKeyHint => 'Saisissez votre clé de licence';

  @override
  String get buyLicenseKey => 'Acheter une clé de licence';

  @override
  String get storage => 'Stockage';

  @override
  String get debugInfo => 'Infos de débogage';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get copyEncryptionValue => 'Copier la valeur de chiffrement';

  @override
  String get categoryAll => 'Tout';

  @override
  String get categoryImages => 'Images';

  @override
  String get categoryVideos => 'Vidéos';

  @override
  String get categoryDocuments => 'Documents';

  @override
  String get searchFilesHint => 'Rechercher des fichiers...';

  @override
  String previewNotAvailable(String type) {
    return 'Aperçu non disponible pour $type';
  }

  @override
  String get cannotViewVideo => 'Impossible de visionner cette vidéo';

  @override
  String get unknown => 'Inconnu';

  @override
  String get errorIdentifyPath =>
      'Erreur : Impossible d\'identifier le chemin de l\'appareil';

  @override
  String get backupImageFile => 'Fichier Image de Sauvegarde';

  @override
  String get premiumPlan => 'FORFAIT PREMIUM';

  @override
  String get freePlan => 'FORFAIT GRATUIT';

  @override
  String get outputConfig => 'Configuration de Sortie';

  @override
  String get selectOutputDir => 'Choisir le répertoire de sortie';

  @override
  String currentOutputPath(String path) {
    return 'Chemin actuel : $path';
  }

  @override
  String get authorContact => 'Contact de l\'auteur';

  @override
  String get authorName => 'Nom';

  @override
  String get authorEmail => 'E-mail';

  @override
  String get authorZalo => 'Zalo';

  @override
  String get authorLinkedIn => 'LinkedIn';

  @override
  String get authorFacebook => 'Facebook';

  @override
  String get premiumPrice => 'Prix : 50 000 VND / 2 \$ (1 jour)';

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
