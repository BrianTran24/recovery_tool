import 'package:flutter/material.dart';
import 'scan_view.dart';

class ScanScreen extends StatelessWidget {
  final String sourcePath;
  final String outputDir;
  final bool enableFat;
  final bool enableCarve;
  final int scanMode;
  final String referenceVideo;
  final bool isPremium;

  const ScanScreen({
    super.key,
    required this.sourcePath,
    required this.outputDir,
    this.enableFat = true,
    this.enableCarve = true,
    this.scanMode = 1,
    this.referenceVideo = '',
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScanView(
          sourcePath: sourcePath,
          outputDir: outputDir,
          enableFat: enableFat,
          enableCarve: enableCarve,
          scanMode: scanMode,
          referenceVideo: referenceVideo,
          isPremium: isPremium,
        ),
      ),
    );
  }
}
