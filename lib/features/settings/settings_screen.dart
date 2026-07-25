import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recovery_tool/core/bloc/premium/premium_cubit.dart';
import 'package:recovery_tool/core/service/storage_service.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/core/bloc/locale/locale_cubit.dart';
import 'package:recovery_tool/features/premium/widgets/contact_buy_dialog.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCleaning = false;
  bool _isAuthorExpanded = false;

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
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _LanguageOption(
                      label: l10n.vietnamese,
                      isSelected: currentLocale.languageCode == 'vi',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('vi')),
                    ),
                    _LanguageOption(
                      label: l10n.english,
                      isSelected: currentLocale.languageCode == 'en',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('en')),
                    ),
                    _LanguageOption(
                      label: l10n.spanish,
                      isSelected: currentLocale.languageCode == 'es',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('es')),
                    ),
                    _LanguageOption(
                      label: l10n.chinese,
                      isSelected: currentLocale.languageCode == 'zh',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('zh')),
                    ),
                    _LanguageOption(
                      label: l10n.hindi,
                      isSelected: currentLocale.languageCode == 'hi',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('hi')),
                    ),
                    _LanguageOption(
                      label: l10n.arabic,
                      isSelected: currentLocale.languageCode == 'ar',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('ar')),
                    ),
                    _LanguageOption(
                      label: l10n.french,
                      isSelected: currentLocale.languageCode == 'fr',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('fr')),
                    ),
                    _LanguageOption(
                      label: l10n.russian,
                      isSelected: currentLocale.languageCode == 'ru',
                      onTap: () => context.read<LocaleCubit>().setLocale(const Locale('ru')),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              BlocBuilder<PremiumCubit, PremiumState>(
                builder: (context, premiumState) {
                  if (premiumState.isPremium) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildSettingsSection(
                      context,
                      title: l10n.upgradeToPremium,
                      icon: Icons.workspace_premium_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.unlockAllFilesDesc,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.premiumPrice,
                            style: const TextStyle(
                              color: AppTheme.cyberCyan,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => const ContactBuyDialog(),
                              );
                            },
                            icon: const Icon(Icons.shopping_cart_rounded, size: 18),
                            label: Text(l10n.buyLicenseKey),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF1744).withValues(alpha: 0.1),
                              foregroundColor: const Color(0xFFFF1744),
                              side: BorderSide(color: const Color(0xFFFF1744).withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

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
                          const SizedBox(height: 8),
                          Text(
                            l10n.premiumPrice,
                            style: const TextStyle(
                              color: AppTheme.cyberCyan,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
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

              _buildSettingsSection(
                context,
                title: l10n.authorContact,
                icon: Icons.person_outline_rounded,
                isExpanded: _isAuthorExpanded,
                onToggle: () => setState(() => _isAuthorExpanded = !_isAuthorExpanded),
                child: Column(
                  children: [
                    _ContactItem(
                      label: l10n.authorName,
                      value: 'Trần Văn Hiếu (Brian)',
                      icon: Icons.badge_outlined,
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    _ContactItem(
                      label: l10n.authorEmail,
                      value: 'tranhieuglpk@gmail.com',
                      icon: Icons.email_outlined,
                      onTap: () => launchUrl(Uri.parse('mailto:tranhieuglpk@gmail.com')),
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    _ContactItem(
                      label: l10n.authorZalo,
                      value: '0335286360',
                      icon: Icons.chat_bubble_outline_rounded,
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    _ContactItem(
                      label: l10n.authorLinkedIn,
                      value: 'brian-tran1998',
                      icon: Icons.link_rounded,
                      onTap: () => launchUrl(Uri.parse('https://www.linkedin.com/in/brian-tran1998/')),
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    _ContactItem(
                      label: l10n.authorFacebook,
                      value: 'haylachinhminh1998',
                      icon: Icons.facebook_rounded,
                      onTap: () => launchUrl(Uri.parse('https://www.facebook.com/haylachinhminh1998')),
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
    bool? isExpanded,
    VoidCallback? onToggle,
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
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            hoverColor: AppTheme.cyberCyan.withValues(alpha: 0.1),
            splashColor: AppTheme.cyberCyan.withValues(alpha: 0.2),
            highlightColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(icon, color: AppTheme.cyberCyan, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isExpanded != null)
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: isExpanded ? 0.5 : 0,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.cyberCyan,
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const SizedBox(height: 24),
                child,
              ],
            ),
            crossFadeState: (isExpanded == null || isExpanded)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _ContactItem({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      hoverColor: AppTheme.cyberCyan.withValues(alpha: 0.05),
      splashColor: AppTheme.cyberCyan.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      mouseCursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.cyberCyan, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.open_in_new_rounded,
                color: AppTheme.cyberCyan.withValues(alpha: 0.5),
                size: 16,
              ),
          ],
        ),
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
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 64 - 48 - 24) / 3, // Adjust based on padding and spacing
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
