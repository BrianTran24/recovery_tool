import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../config/config_screen.dart';
import 'conversion_view.dart';

class ConversionScreen extends StatelessWidget {
  final String e01Path;

  const ConversionScreen({super.key, required this.e01Path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cyberDeepNavy,
      body: ConversionView(
        e01Path: e01Path,
        onConversionDone: (disk) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ConfigScreen(disk: disk),
            ),
          );
        },
      ),
    );
  }
}
