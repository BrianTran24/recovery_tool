import 'dart:async';
import 'dart:io';

import 'package:disks_desktop/disks_desktop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recovery_tool/features/config/config_screen.dart';

void main() {
  runZonedGuarded(() {
    runApp(const ProviderScope(child: MyApp()));
  }, (error, stackTrace) {
    // Handle uncaught errors here
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recovery Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Recovery Tool'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<void> _pickImageFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Chọn file backup (.img, .bin, ...)',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final size = File(path).lengthSync();

      // Tạo một đối tượng Disk giả cho ConfigScreen
      final fakeDisk = Disk(
        blockSize: 512,
        busType: 'IMAGE',
        description: 'Backup Image File',
        device: path,
        devicePath: path,
        readOnly: true,
        removable: true,
        system: false,
        logicalBlockSize: 512,
        mountpoints: const [],
        raw: path,
        size: size,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfigScreen(disk: fakeDisk),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Nút chọn File Image
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              onPressed: _pickImageFile,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: Colors.blue),
              ),
              icon: const Icon(Icons.file_open),
              label: const Text('KHÔI PHỤC TỪ FILE BACKUP (.IMG)'),
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<Disk>>(
              future: _getRemovableDisks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final disks = snapshot.data ?? [];
                if (disks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.usb_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Không tìm thấy ổ đĩa di động nào',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: disks.length,
                  itemBuilder: (context, index) {
                    final disk = disks[index];
                    final path =
                        (disk.raw.startsWith('/dev/'))
                            ? disk.raw
                            : disk.devicePath;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.usb, color: Colors.white),
                        ),
                        title: Text(disk.devicePath ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${disk.busType} · ${_byteToGB(disk.size ?? 0).toStringAsFixed(2)} GB',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (path == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text(
                                    'Lỗi: Không xác định được đường dẫn ổ đĩa')));
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConfigScreen(disk: disk),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _byteToGB(int bytes) {
    return bytes / (1024 * 1024 * 1024);
  }

  Future<List<Disk>> _getRemovableDisks() async {
    final removableDisks = DisksRepository();

    var listDevices = await removableDisks.query;

    final removableDisksList =
        listDevices.where((disk) => disk.removable).toList();

    return removableDisksList;
  }
}
