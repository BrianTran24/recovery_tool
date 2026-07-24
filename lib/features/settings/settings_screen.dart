import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recovery_tool/core/bloc/premium/premium_cubit.dart';
import 'package:recovery_tool/core/service/storage_service.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/core/bloc/locale/locale_cubit.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCleaning = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, currentLocale) {
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.systemReady.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.cyberCyan.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.sidebarSettings,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              
              _buildSettingsSection(
                context,
                title: l10n.language,
                icon: Icons.language_rounded,
                child: Row(
                  children: [
                    _LanguageOption(
                      label: l10n.vietnamese,
                      isSelected: currentLocale.languageCode == 'vi',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('vi')),
                    ),
                    const SizedBox(width: 16),
                    _LanguageOption(
                      label: l10n.english,
                      isSelected: currentLocale.languageCode == 'en',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('en')),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              BlocBuilder<PremiumCubit, PremiumState>(
                builder: (context, premiumState) {
                  if (!premiumState.isPremium) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildSettingsSection(
                      context,
                      title: l10n.outputConfig,
                      icon: Icons.folder_open_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.currentOutputPath(premiumState.outputDir ?? l10n.unknown),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _pickOutputDir(context),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: Text(l10n.selectOutputDir),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cyberCyan.withValues(alpha: 0.1),
                              foregroundColor: AppTheme.cyberCyan,
                              side: BorderSide(color: AppTheme.cyberCyan.withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              _buildSettingsSection(
                context,
                title: l10n.storage,
                icon: Icons.storage_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.clearCacheDesc,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isCleaning ? null : () => _clearCache(context, l10n),
                      icon: _isCleaning 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
                          : const Icon(Icons.cleaning_services_rounded, size: 18),
                      label: Text(l10n.clearCache),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _clearCache(BuildContext context, AppLocalizations l10n) async {
    setState(() => _isCleaning = true);
    try {
      await context.read<StorageService>().clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cacheCleared)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.clearCacheError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _pickOutputDir(BuildContext context) async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      await context.read<PremiumCubit>().updateOutputDir(result);
    }
  }

  Widget _buildSettingsSection(BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cyberGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.cyberCyan.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.cyberCyan, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.cyberCyan.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.cyberCyan : Colors.white.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
