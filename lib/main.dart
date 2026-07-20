import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:disks_desktop/disks_desktop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/features/config/config_screen.dart';
import 'package:recovery_tool/features/onboarding/onboarding_screen.dart';
import 'package:recovery_tool/features/settings/settings_screen.dart';
import 'package:recovery_tool/core/providers/locale_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';

void main() {
  runZonedGuarded(() {
    runApp(const ProviderScope(child: MyApp()));
  }, (error, stackTrace) {
    // Handle uncaught errors here
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stackTrace');
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Recovery Tool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('vi'),
      ],
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const MyHomePage(),
      },
    );
  }
}

enum HomeTool { devices, restore, settings }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  HomeTool _selectedTool = HomeTool.devices;
  bool _isCollapsed = false;

  Future<void> _pickBackupImage() async {
    final l10n = AppLocalizations.of(context)!;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['img', 'bin', 'dd', 'raw'],
      dialogTitle: l10n.selectBackupImage,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfigScreen(disk: _buildImageDisk(path)),
        ),
      );
    }
  }

  Disk _buildImageDisk(String path) {
    final size = File(path).lengthSync();
    return Disk(
      blockSize: 512,
      busType: 'IMAGE',
      description: 'Backup Image File',
      device: path,
      devicePath: path,
      readOnly: true,
      removable: false,
      system: false,
      logicalBlockSize: 512,
      mountpoints: const [],
      raw: path,
      size: size,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Cyber Background
          Positioned.fill(
            child: CustomPaint(
              painter: HomeCircuitPainter(
                color: AppTheme.cyberCyan.withValues(alpha: 0.05),
              ),
            ),
          ),
          Row(
            children: [
              // Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                width: _isCollapsed ? 80 : 280,
                decoration: BoxDecoration(
                  color: AppTheme.cyberDeepNavy.withValues(alpha: 0.8),
                  border: Border(
                    right: BorderSide(
                      color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Branding Area
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 0 : 20),
                      child: Row(
                        mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: const DecorationImage(
                                image: AssetImage('assets/logo.jpeg'),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.cyberCyan.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          if (!_isCollapsed) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.appTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.cyberCyan,
                                  letterSpacing: 1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Navigation Items
                    _SidebarItem(
                      icon: Icons.usb_rounded,
                      label: l10n.sidebarDevices,
                      isSelected: _selectedTool == HomeTool.devices,
                      isCollapsed: _isCollapsed,
                      onTap: () => setState(() => _selectedTool = HomeTool.devices),
                    ),
                    _SidebarItem(
                      icon: Icons.restore_page_rounded,
                      label: l10n.sidebarRestore,
                      isSelected: _selectedTool == HomeTool.restore,
                      isCollapsed: _isCollapsed,
                      onTap: () => setState(() => _selectedTool = HomeTool.restore),
                    ),
                    _SidebarItem(
                      icon: Icons.settings_rounded,
                      label: l10n.sidebarSettings,
                      isSelected: _selectedTool == HomeTool.settings,
                      isCollapsed: _isCollapsed,
                      onTap: () => setState(() => _selectedTool = HomeTool.settings),
                    ),
                    const Spacer(),
                    // System Status & Toggle
                    Padding(
                      padding: EdgeInsets.fromLTRB(_isCollapsed ? 0 : 24, 0, _isCollapsed ? 0 : 16, 20),
                      child: Column(
                        crossAxisAlignment: _isCollapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                        children: [
                          if (!_isCollapsed) ...[
                            Text(
                              l10n.systemStatus,
                              style: TextStyle(
                                color: AppTheme.cyberCyan.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                            children: [
                              if (!_isCollapsed)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.greenAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.online,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                // Center the status dot and toggle button slightly separated or overlapping in a column?
                                // User asked for same row, so let's keep it in a small row but centered.
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (_isCollapsed) const SizedBox(width: 8), // Small gap when collapsed
                              IconButton(
                                onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                                icon: Icon(
                                  _isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                                  color: AppTheme.cyberCyan,
                                  size: 20,
                                ),
                                tooltip: _isCollapsed ? l10n.expand : l10n.collapse,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: Column(
                  children: [
                    // Custom Header
                    const SizedBox(height: 24),
                    Expanded(
                      child: _buildContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTool) {
      case HomeTool.devices:
        return _buildDevicesContent();
      case HomeTool.restore:
        return _buildRestoreContent();
      case HomeTool.settings:
        return const SettingsScreen();
    }
  }

  Widget _buildDevicesContent() {
    final l10n = AppLocalizations.of(context)!;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.systemReady,
                  style: TextStyle(
                    color: AppTheme.cyberCyan.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.connectedDevices,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        FutureBuilder<List<Disk>>(
          future: _getRemovableDisks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppTheme.cyberCyan)),
              );
            }

            final disks = snapshot.data ?? [];
            if (disks.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.cyberCyan.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.1)),
                        ),
                        child: Icon(Icons.usb_off_rounded, size: 64, color: AppTheme.cyberCyan.withValues(alpha: 0.3)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.noDevicesDetected,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () => setState(() {}),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.cyberCyan),
                          foregroundColor: AppTheme.cyberCyan,
                        ),
                        child: Text(l10n.tryRescan),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final disk = disks[index];
                    final path = (disk.raw.startsWith('/dev/')) ? disk.raw : disk.devicePath;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (path == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('Error: Could not identify device path')));
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ConfigScreen(disk: disk),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.cyberGlass,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.usb_rounded, color: AppTheme.cyberCyan),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        disk.raw.startsWith('/dev/')
                                            ? (disk.devicePath ?? l10n.unknownDevice)
                                            : 'Image: ${disk.devicePath ?? l10n.unknownDevice}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${disk.busType} ${l10n.interface} • ${_byteToGB(disk.size ?? 0).toStringAsFixed(2)} GB',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppTheme.cyberCyan),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: disks.length,
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildRestoreContent() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.systemReady,
            style: TextStyle(
              color: AppTheme.cyberCyan.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.restoreData,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _pickBackupImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.cyberCyan.withValues(alpha: 0.2),
                    AppTheme.cyberBlue.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.cyberCyan.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.file_copy_rounded, color: AppTheme.cyberCyan, size: 48),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.selectBackupImage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.supportedFormats,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.cyberCyan,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.browseFile,
                      style: const TextStyle(
                        color: AppTheme.cyberDeepNavy,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? AppTheme.cyberCyan.withValues(alpha: 0.1) : Colors.transparent,
              border: isSelected
                  ? Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.3))
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.cyberCyan : Colors.white54,
                  size: 20,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeCircuitPainter extends CustomPainter {
  final Color color;

  HomeCircuitPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final random = math.Random(42); // Fixed seed for consistency on Home
    
    // Tech grid
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint..color = color.withValues(alpha: 0.03));
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint..color = color.withValues(alpha: 0.03));
    }

    // Circuit paths
    for (int i = 0; i < 6; i++) {
      final path = Path();
      double startX = random.nextDouble() * size.width;
      double startY = random.nextDouble() * size.height;
      path.moveTo(startX, startY);
      
      double curX = startX;
      double curY = startY;
      
      for (int j = 0; j < 3; j++) {
        if (random.nextBool()) {
          curX += 100 * (random.nextBool() ? 1 : -1);
        } else {
          curY += 100 * (random.nextBool() ? 1 : -1);
        }
        path.lineTo(curX, curY);
        canvas.drawCircle(Offset(curX, curY), 1.5, paint..style = PaintingStyle.fill..color = color.withValues(alpha: 0.1));
        paint.style = PaintingStyle.stroke;
      }
      canvas.drawPath(path, paint..color = color.withValues(alpha: 0.1));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
