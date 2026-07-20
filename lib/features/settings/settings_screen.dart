import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/core/providers/locale_provider.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
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
                  onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('vi')),
                ),
                const SizedBox(width: 16),
                _LanguageOption(
                  label: l10n.english,
                  isSelected: currentLocale.languageCode == 'en',
                  onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('en')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
