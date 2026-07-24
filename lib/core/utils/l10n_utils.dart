import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class L10nUtils {
  static String translate(BuildContext context, String? message) {
    if (message == null || message.isEmpty) return '';
    
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return message;

    // Handle parameterized keys (this is tricky with arb)
    // For now, handle exact matches for simple keys
    switch (message) {
      case 'premiumActivated': return l10n.premiumActivated;
      case 'licenseExpired': return l10n.licenseExpired;
      case 'licenseInvalid': return l10n.licenseInvalid;
      case 'errorVerifyLicense': return l10n.errorVerifyLicense;
      case 'errorTimeout': return l10n.errorTimeout;
      case 'featureRemoved': return l10n.featureRemoved;
      case 'conversionInitializing': return l10n.conversionInitializing;
      case 'conversionDecrypting': return l10n.conversionDecrypting;
      case 'conversionComplete': return l10n.conversionComplete;
      case 'errorFileNotFoundAfterConversion': return l10n.errorFileNotFoundAfterConversion;
      case 'unknown': return l10n.unknown;
      default:
        // Try to handle keys with "error:" prefix or similar if needed
        if (message.startsWith('errorConnection:')) {
          return l10n.errorConnection(message.replaceFirst('errorConnection:', ''));
        }
        if (message.startsWith('errorActivatePremium:')) {
          return l10n.errorActivatePremium(message.replaceFirst('errorActivatePremium:', ''));
        }
        if (message.startsWith('errorOpenDevice:')) {
           final handle = int.tryParse(message.replaceFirst('errorOpenDevice:', '')) ?? 0;
           return l10n.errorOpenDevice(handle);
        }
        if (message.startsWith('errorHardwareSerious:')) {
           return l10n.errorHardwareSerious(message.replaceFirst('errorHardwareSerious:', ''));
        }
        
        return message; // Fallback to raw message
    }
  }
}
