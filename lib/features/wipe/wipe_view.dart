import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recovery_tool/core/service/recovery_service.dart';
import 'package:recovery_tool/core/models/recovery_event.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';

class WipeView extends StatefulWidget {
  final String sourcePath;
  final int diskSize;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const WipeView({
    super.key,
    required this.sourcePath,
    required this.diskSize,
    required this.onCancel,
    required this.onDone,
  });

  @override
  State<WipeView> createState() => _WipeViewState();
}

class _WipeViewState extends State<WipeView> {
  bool _isWiping = false;
  double _progress = 0;
  String _status = '';
  int _passes = 1;
  int _wipeType = 1; // 1 = Random, 0 = Zeros
  bool _confirmed = false;
  StreamSubscription? _subscription;
  final List<String> _logs = [];

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startWipe() {
    if (!_confirmed) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isWiping = true;
      _progress = 0;
      _logs.clear();
      _status = l10n.scanProcessing;
    });

    final recoveryService = context.read<RecoveryService>();
    _subscription = recoveryService.startWipe(
      sourcePath: widget.sourcePath,
      passes: _passes,
      wipeType: _wipeType,
    ).listen(
      (event) {
        if (event is ProgressEvent) {
          setState(() {
            _progress = event.percent / 100.0;
            _status = '${(event.percent).toStringAsFixed(1)}%';
          });
        } else if (event is DoneEvent) {
          setState(() {
            _isWiping = false;
            _progress = 1.0;
            _status = l10n.success;
          });
          _showDoneDialog();
        } else if (event is ErrorEvent) {
          setState(() {
            _isWiping = false;
            _logs.add('Error: ${event.message}');
          });
        }
      },
      onError: (error) {
        setState(() {
          _isWiping = false;
          _logs.add('Stream Error: $error');
        });
      },
    );
  }

  void _showDoneDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cyberDeepNavy,
        title: Text(l10n.success, style: const TextStyle(color: AppTheme.cyberCyan)),
        content: Text(
          l10n.wipeCompleteDesc,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDone();
            },
            child: Text(l10n.close, style: const TextStyle(color: AppTheme.cyberCyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.cyberCyan),
              ),
              const SizedBox(width: 16),
              Text(
                l10n.wipeDataTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _isWiping ? _buildWipingProgress() : _buildConfiguration(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfiguration() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cyberGlass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sd_card_rounded, color: AppTheme.cyberCyan, size: 48),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sourcePath,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(widget.diskSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Warning Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                    const SizedBox(width: 16),
                    Text(
                      l10n.criticalWarning,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.wipeWarningDesc,
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Options
          const Text(
            'CẤU HÌNH XOÁ',
            style: TextStyle(color: AppTheme.cyberCyan, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildOptionTile(
            title: 'Số lần ghi đè (Passes)',
            subtitle: _passes == 1 ? 'Nhanh (1 lần)' : 'An toàn (3 lần - Chuẩn DoD)',
            icon: Icons.repeat_rounded,
            trailing: DropdownButton<int>(
              value: _passes,
              dropdownColor: AppTheme.cyberDeepNavy,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 Lần', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 3, child: Text('3 Lần', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 7, child: Text('7 Lần', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) => setState(() => _passes = val ?? 1),
            ),
          ),
          const SizedBox(height: 12),
          _buildOptionTile(
            title: 'Kiểu ghi đè',
            subtitle: _wipeType == 1 ? 'Dữ liệu ngẫu nhiên (An toàn hơn)' : 'Ghi số 0 (Nhanh hơn)',
            icon: Icons.security_rounded,
            trailing: Switch(
              value: _wipeType == 1,
              activeTrackColor: AppTheme.cyberCyan,
              onChanged: (val) => setState(() => _wipeType = val ? 1 : 0),
            ),
          ),
          const SizedBox(height: 48),
          // Confirmation
          CheckboxListTile(
            value: _confirmed,
            onChanged: (val) => setState(() => _confirmed = val ?? false),
            title: Text(
              l10n.confirmWipeCheckbox,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            activeColor: AppTheme.cyberCyan,
            checkColor: AppTheme.cyberDeepNavy,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 24),
          // Start Button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _confirmed ? _startWipe : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.red.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                l10n.startWipeNow,
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({required String title, required String subtitle, required IconData icon, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cyberGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.cyberCyan, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildWipingProgress() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 12,
                color: Colors.red,
                backgroundColor: Colors.red.withValues(alpha: 0.1),
              ),
            ),
            Column(
              children: [
                Text(
                  _status,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.red),
                ),
                const Text('TIẾN ĐỘ', style: TextStyle(color: Colors.white54, letterSpacing: 4, fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 64),
        Text(
          'ĐANG XOÁ DỮ LIỆU...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.bold, letterSpacing: 4),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 64),
          child: Text(
            'Vui lòng không rút thiết bị hoặc đóng ứng dụng cho đến khi quá trình hoàn tất.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ),
        const SizedBox(height: 48),
        OutlinedButton(
          onPressed: () {
            _subscription?.cancel();
            setState(() {
              _isWiping = false;
            });
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white24),
            foregroundColor: Colors.white54,
          ),
          child: const Text('HỦY BỎ'),
        ),
      ],
    );
  }
}
