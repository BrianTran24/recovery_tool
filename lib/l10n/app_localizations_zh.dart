// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Recovery SD Tool';

  @override
  String get onboardingTitle1 => 'RECOVERY SD TOOL';

  @override
  String get onboardingSubtitle1 => '解锁您丢失的数据！';

  @override
  String get onboardingDesc1 => '为您所有的 SD 设备提供专业、快速且可靠的数据恢复解决方案。';

  @override
  String get onboardingTitle2 => '快速扫描系统';

  @override
  String get onboardingSubtitle2 => '轻松恢复';

  @override
  String get onboardingDesc2 => '深度扫描算法帮助您瞬间找回丢失的照片、视频和文档。';

  @override
  String get onboardingTitle3 => '预览文件';

  @override
  String get onboardingSubtitle3 => '恢复前查看';

  @override
  String get onboardingDesc3 => '在扫描过程中预览数据，确保您准确选择最重要的内容。';

  @override
  String get onboardingTitle4 => '安全可靠';

  @override
  String get onboardingSubtitle4 => '保护您的记忆';

  @override
  String get onboardingDesc4 => '绝对安全的恢复过程，确保不覆盖或损坏原始数据。';

  @override
  String get skip => '跳过';

  @override
  String get nextStep => '下一步';

  @override
  String get startRecovery => '开始恢复';

  @override
  String get sidebarDevices => '设备';

  @override
  String get sidebarRestore => '还原镜像';

  @override
  String get sidebarWipe => 'WIPE DATA';

  @override
  String get sidebarSettings => '设置';

  @override
  String get systemStatus => '系统状态';

  @override
  String get online => '在线';

  @override
  String get expand => '展开';

  @override
  String get collapse => '折叠';

  @override
  String get systemReady => '系统就绪';

  @override
  String get connectedDevices => '已连接设备';

  @override
  String get noDevicesDetected => '未检测到设备';

  @override
  String get tryRescan => '尝试重新扫描';

  @override
  String get unknownDevice => '未知设备';

  @override
  String get interface => '界面';

  @override
  String get restoreData => '恢复数据';

  @override
  String get selectBackupImage => '选择备份镜像文件';

  @override
  String get supportedFormats => '支持 .img, .bin, .dd, .raw';

  @override
  String get browseFile => '浏览文件';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get selectLanguage => '选择语言';

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
  String get developing => '开发中';

  @override
  String get gcTrimWarningTitle => '警告：垃圾回收风险';

  @override
  String get gcTrimWarningDesc =>
      '现代 SD 卡可能会在空闲时间自动擦除已删除的数据 (Trim/GC)。建议：立即将整个卡克隆到 .img 文件以保存数据。';

  @override
  String get sourceDevice => '源设备';

  @override
  String get recoveryMode => '恢复模式';

  @override
  String get storageConfig => '存储配置';

  @override
  String get outputDirectory => '输出目录';

  @override
  String get deletedFiles => '已删除文件';

  @override
  String get existingFiles => '现有文件';

  @override
  String get allFiles => '所有文件';

  @override
  String get deletedFilesDesc => '查找并恢复从文件系统中删除的文件。';

  @override
  String get existingFilesDesc => '扫描并列出设备上当前存在的文件。';

  @override
  String get allFilesDesc => '结合扫描现有文件和已删除文件。';

  @override
  String get startScanNow => '扫描';

  @override
  String get change => '更改';

  @override
  String get pleaseSelectOutputDir => '请选择输出目录';

  @override
  String backupImage(String path) {
    return '备份镜像: $path';
  }

  @override
  String get readOnlyMode => '只读模式 - 绝对安全';

  @override
  String capacity(int size) {
    return '容量: $size GB';
  }

  @override
  String scanInitializing(String path) {
    return '正在为 $path 初始化扫描会话';
  }

  @override
  String scanFsIdentified(String type, int offset) {
    return '已识别：扇区 $offset 处的 $type 文件系统';
  }

  @override
  String get scanFsNotFound => '已识别：未找到有效的文件系统。切换到特征签名恢复 (Signature Carving)。';

  @override
  String scanScanningSector(int sector, String percent) {
    return '正在扫描扇区：$sector ($percent%)';
  }

  @override
  String scanFileFound(String filename, String type) {
    return '找到：$filename ($type)';
  }

  @override
  String scanComplete(int count, String duration) {
    return '完成：在 $duration 内找到 $count 个文件';
  }

  @override
  String scanError(String message) {
    return '错误：$message';
  }

  @override
  String scanStreamError(Object error) {
    return '流错误：$error';
  }

  @override
  String get scanResults => '扫描结果';

  @override
  String get scanProcessing => '正在处理数据...';

  @override
  String get scanStop => '停止';

  @override
  String get scanPause => '暂停';

  @override
  String get scanResume => '继续';

  @override
  String get scanCancel => '取消';

  @override
  String get scanViewAllResults => '查看所有结果';

  @override
  String scanViewLive(int count) {
    return '实时查看 ($count 个文件)';
  }

  @override
  String get scanTabFiles => '找到的文件';

  @override
  String get scanTabLogs => '系统日志';

  @override
  String get scanSearchingFiles => '正在搜索文件...';

  @override
  String get scanProgress => '扫描进度';

  @override
  String get scanSpeed => '速度';

  @override
  String get scanFound => '找到';

  @override
  String get scanElapsed => '已用时间';

  @override
  String get scanRemaining => '剩余时间（预估）';

  @override
  String get scanHardwareError => '硬件错误';

  @override
  String get scanSystemError => '系统错误';

  @override
  String get scanUnderstand => '我明白';

  @override
  String get scanNew => '扫描其他设备';

  @override
  String get openFolder => '打开输出文件夹';

  @override
  String get freeScanMode => '免费扫描和预览模式';

  @override
  String get upgradeToSave => '升级以保存';

  @override
  String get upgradeRequiredDesc => '升级到高级版以将恢复的文件保存到您的计算机。';

  @override
  String get saveToDiskPremium => '保存到磁盘（高级版）';

  @override
  String get premiumFeature => '高级功能';

  @override
  String get freeModeDesc => '正在扫描到临时存储以进行预览。文件可能会被系统清除。';

  @override
  String get fileDetailTitle => '文件详情';

  @override
  String get fileDetailProperties => '属性';

  @override
  String get fileDetailName => '文件名';

  @override
  String get fileDetailType => '类型';

  @override
  String get fileDetailSize => '大小';

  @override
  String get fileDetailLocation => '相对路径';

  @override
  String get fileDetailOffset => '扇区偏移';

  @override
  String get fileDetailModified => '修改日期';

  @override
  String get fileDetailStatus => '恢复状态';

  @override
  String get fileDetailOpenFile => '打开文件';

  @override
  String get fileDetailShowInFolder => '在文件夹中显示';

  @override
  String get fileDetailNext => '下一个文件';

  @override
  String get fileDetailPrevious => '上一个文件';

  @override
  String get fileDetailHealthy => '良好';

  @override
  String get fileDetailOrphaned => '孤立文件';

  @override
  String get fileDetailCarved => '原始恢复 (Carved)';

  @override
  String get clearCache => '清理缓存';

  @override
  String get clearCacheDesc => '删除所有临时扫描文件以释放磁盘空间。';

  @override
  String get cacheCleared => '缓存清理成功';

  @override
  String clearCacheError(String error) {
    return '清理缓存出错：$error';
  }

  @override
  String errorOpenDevice(int handle) {
    return '打开设备出错 ($handle)';
  }

  @override
  String errorHardwareSerious(String message) {
    return '检测到严重的硬件/固件错误：$message。建议：使用专用设备 (PC-3000 Flash) 直接读取 NAND 芯片。';
  }

  @override
  String errorUnknownEvent(int type) {
    return '未知事件类型：$type';
  }

  @override
  String get errorVerifyLicense => '无法验证许可证。请稍后再试。';

  @override
  String get errorTimeout => '连接超时。请检查您的网络。';

  @override
  String errorConnection(String error) {
    return '连接错误：$error';
  }

  @override
  String get premiumActivated => '高级版激活成功！';

  @override
  String get licenseExpired => '许可证密钥已过期。';

  @override
  String get licenseInvalid => '许可证密钥无效。';

  @override
  String errorActivatePremium(String error) {
    return '激活高级版出错：$error';
  }

  @override
  String get featureRemoved => '此功能已被移除。';

  @override
  String get conversionInitializing => '正在初始化...';

  @override
  String get conversionDecrypting => '正在解密 E01 文件...';

  @override
  String conversionStatus(String percent) {
    return '正在转换：$percent%';
  }

  @override
  String get conversionComplete => '转换完成！';

  @override
  String get errorFileNotFoundAfterConversion => '错误：转换后未找到输出文件。';

  @override
  String get conversionTitle => 'E01 格式转换';

  @override
  String get convertedRawImage => '转换后的 Raw 镜像';

  @override
  String get pleaseEnterLicenseKey => '请输入许可证密钥';

  @override
  String get premiumActivatedTitle => '高级版已激活！';

  @override
  String get success => '成功！';

  @override
  String get accessFilesFromOutput => '您可以直接从输出目录访问文件。';

  @override
  String get close => '关闭';

  @override
  String get unlockPremiumTitle => '解锁高级版';

  @override
  String get upgradeToPremium => '升级到高级版';

  @override
  String get unlockAllFilesDesc => '解锁所有恢复的文件并直接从目录访问它们';

  @override
  String get featureDirectAccess => '从目录直接访问';

  @override
  String get featureNoWatermark => '无水印';

  @override
  String get licenseKeyHint => '输入您的许可证密钥';

  @override
  String get buyLicenseKey => '购买许可证密钥';

  @override
  String get storage => '存储';

  @override
  String get debugInfo => '调试信息';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get copyEncryptionValue => '复制加密值';

  @override
  String get categoryAll => '全部';

  @override
  String get categoryImages => '图片';

  @override
  String get categoryVideos => '视频';

  @override
  String get categoryDocuments => '文档';

  @override
  String get searchFilesHint => '搜索文件...';

  @override
  String previewNotAvailable(String type) {
    return '$type 不支持预览';
  }

  @override
  String get cannotViewVideo => '无法观看此视频';

  @override
  String get unknown => '未知';

  @override
  String get errorIdentifyPath => '错误：无法识别设备路径';

  @override
  String get backupImageFile => '备份镜像文件';

  @override
  String get premiumPlan => '高级版方案';

  @override
  String get freePlan => '免费版方案';

  @override
  String get outputConfig => '输出配置';

  @override
  String get selectOutputDir => '选择输出目录';

  @override
  String currentOutputPath(String path) {
    return '当前路径：$path';
  }

  @override
  String get authorContact => '作者联系方式';

  @override
  String get authorName => '姓名';

  @override
  String get authorEmail => '电子邮箱';

  @override
  String get authorZalo => 'Zalo';

  @override
  String get authorLinkedIn => 'LinkedIn';

  @override
  String get authorFacebook => 'Facebook';

  @override
  String get premiumPrice => '价格：50,000 VND / \$2（1 天）';

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
