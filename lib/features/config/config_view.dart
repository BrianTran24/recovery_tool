import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:disks_desktop/disks_desktop.dart';
import '../../core/bloc/premium/premium_cubit.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/animated_scan_button.dart';

class ConfigView extends StatefulWidget {
  final Disk disk;
  final Function(int scanMode, String outputDir) onStartScan;
  final VoidCallback? onBack;
  final VoidCallback? onPickNewFile;

  const ConfigView({
    super.key,
    required this.disk,
    required this.onStartScan,
    this.onBack,
    this.onPickNewFile,
  });

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  int _scanMode = 1; // 1=Deleted, 2=Existing, 3=Both
  String? _outputDir;
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  Future<void> _initPath() async {
    final isPremium = context.read<PremiumCubit>().state;
    if (isPremium) {
      _outputDir = r'E:\test';
    } else {
      final temp = await getTemporaryDirectory();
      _outputDir = temp.path;
    }
    _pathController.text = _outputDir!;
  }

  Future<void> _pickDirectory() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _outputDir = result;
        _pathController.text = result;
      });
    }
  }

  void _startScan() {
    final l10n = AppLocalizations.of(context)!;
    if (_outputDir == null || _outputDir!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectOutputDir)),
      );
      return;
    }

    widget.onStartScan(_scanMode, _outputDir!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<PremiumCubit, bool>(
      builder: (context, isPremium) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Disk Info Card
              _buildSectionHeader(l10n.sourceDevice),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storage_rounded, color: AppTheme.cyberCyan),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.disk.raw.startsWith('/dev/')
                                  ? (widget.disk.devicePath ?? l10n.unknownDevice)
                                  : l10n.backupImage(widget.disk.devicePath ?? 'Unknown'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.disk.raw.startsWith('/dev/')
                                  ? l10n.capacity((widget.disk.size ?? 0) ~/ (1024 * 1024 * 1024))
                                  : l10n.readOnlyMode,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onBack != null || widget.onPickNewFile != null)
                        TextButton.icon(
                          onPressed: () {
                            if (widget.onPickNewFile != null && !widget.disk.raw.startsWith('/dev/')) {
                              widget.onPickNewFile!();
                            } else {
                              widget.onBack?.call();
                            }
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.cyberCyan),
                          label: Text(
                            l10n.change,
                            style: const TextStyle(
                              color: AppTheme.cyberCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: AppTheme.cyberCyan.withValues(alpha: 0.05),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              if (!isPremium) ...[
                const SizedBox(height: 12),
                _buildPremiumBanner(l10n),
              ],

              // GC/Trim Warning
              if (widget.disk.raw.startsWith('/dev/')) ...[
                const SizedBox(height: 12),
                _buildGCTrimWarning(),
              ],
              
              const SizedBox(height: 16),
              _buildSectionHeader(l10n.recoveryMode),
              _buildScanModeSelector(l10n),
              
              const SizedBox(height: 16),
              _buildSectionHeader(l10n.storageConfig),
              _buildPathSelector(
                label: l10n.outputDirectory,
                controller: _pathController,
                onTap: isPremium ? _pickDirectory : () {},
                icon: Icons.folder_open_rounded,
                isPremium: isPremium,
              ),
              
              const Spacer(),
              Center(
                child: AnimatedScanButton(
                  onTap: _startScan,
                  label: l10n.startScanNow,
                ),
              ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.freeScanMode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.freeModeDesc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGCTrimWarning() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gcTrimWarningTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.gcTrimWarningDesc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanModeSelector(AppLocalizations l10n) {
    return Row(
      children: [
        _buildScanModeItem(
          value: 1,
          icon: Icons.delete_sweep_rounded,
          title: l10n.deletedFiles,
          description: l10n.deletedFilesDesc,
          color: Colors.red.shade400,
        ),
        const SizedBox(width: 12),
        _buildScanModeItem(
          value: 2,
          icon: Icons.file_present_rounded,
          title: l10n.existingFiles,
          description: l10n.existingFilesDesc,
          color: Colors.green.shade400,
        ),
        const SizedBox(width: 12),
        _buildScanModeItem(
          value: 3,
          icon: Icons.all_inclusive_rounded,
          title: l10n.allFiles,
          description: l10n.allFilesDesc,
          color: AppTheme.cyberCyan,
        ),
      ],
    );
  }

  Widget _buildScanModeItem({
    required int value,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final isSelected = _scanMode == value;
    return Expanded(
      child: Tooltip(
        message: description,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.cyberDeepNavy.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        child: InkWell(
          onTap: () => setState(() => _scanMode = value),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.cyberGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.white.withValues(alpha: 0.05),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.white.withValues(alpha: 0.4),
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPathSelector({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    required IconData icon,
    bool isSmall = false,
    bool isPremium = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSmall)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
          ),
        Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: isPremium ? 1.0 : 0.6,
                child: TextField(
                  controller: controller,
                  readOnly: true,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: label,
                    prefixIcon: Icon(icon, size: 20, color: AppTheme.cyberCyan),
                    filled: true,
                    fillColor: AppTheme.cyberGlass,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.cyberCyan.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.cyberCyan.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isPremium ? onTap : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cyberGlass,
                  foregroundColor: AppTheme.cyberCyan,
                  side: BorderSide(color: AppTheme.cyberCyan.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Icon(Icons.edit_note_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
