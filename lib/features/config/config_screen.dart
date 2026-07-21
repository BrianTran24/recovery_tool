import 'package:flutter/material.dart';
import 'package:disks_desktop/disks_desktop.dart';
import '../../scan_screen.dart';
import 'config_view.dart';

class ConfigScreen extends StatelessWidget {
  final Disk disk;
  const ConfigScreen({super.key, required this.disk});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình Quét'),
        automaticallyImplyLeading: false,
      ),
      body: ConfigView(
        disk: disk,
        onBack: () => Navigator.pop(context),
        onStartScan: (scanMode, outputDir) {
          final path = (disk.raw.startsWith('/dev/'))
              ? disk.raw
              : disk.devicePath;

          if (path == null) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanScreen(
                sourcePath: path,
                outputDir: outputDir,
                enableFat: true,
                enableCarve: true,
                scanMode: scanMode,
                referenceVideo: '',
              ),
            ),
          );
        },
      ),
    );
  }
}
