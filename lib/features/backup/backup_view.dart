import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recovery_tool/core/service/recovery_service.dart';
import 'package:recovery_tool/core/models/recovery_event.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';

class BackupView extends StatefulWidget {
  final String sourcePath;
  final String outputPath;
  final int diskSize;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const BackupView({
    super.key,
    required this.sourcePath,
    required this.outputPath,
    required this.diskSize,
    required this.onCancel,
    required this.onDone,
  });

  @override
  State<BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends State<BackupView> {
  bool _isBackingUp = false;
  double _progress = 0;
  String _status = '';
  StreamSubscription? _subscription;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackup();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startBackup() {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isBackingUp = true;
      _progress = 0;
      _logs.clear();
      _status = l10n.scanProcessing;
    });

    final recoveryService = context.read<RecoveryService>();
    _subscription = recoveryService.startBackup(
      sourcePath: widget.sourcePath,
      outputPath: widget.outputPath,
    ).listen(
      (event) {
        if (event is ProgressEvent) {
          setState(() {
            _progress = event.percent / 100.0;
            _status = '${(event.percent).toStringAsFixed(1)}%';
          });
        } else if (event is DoneEvent) {
          setState(() {
            _isBackingUp = false;
            _progress = 1.0;
            _status = l10n.success;
          });
          _showDoneDialog();
        } else if (event is ErrorEvent) {
          setState(() {
            _isBackingUp = false;
            _logs.add('Error: ${event.message}');
          });
        }
      },
      onError: (error) {
        setState(() {
          _isBackingUp = false;
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
          l10n.backupCompleteDesc(widget.outputPath),
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
                l10n.backupTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _buildProgress(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(AppLocalizations l10n) {
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
                color: AppTheme.cyberCyan,
                backgroundColor: AppTheme.cyberCyan.withValues(alpha: 0.1),
              ),
            ),
            Column(
              children: [
                Text(
                  _status,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppTheme.cyberCyan),
                ),
                const Text('PROGRESS', style: TextStyle(color: Colors.white54, letterSpacing: 4, fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 64),
        Text(
          l10n.backupProcessing,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 4),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64),
          child: Text(
            'Source: ${widget.sourcePath}\nTarget: ${widget.outputPath}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ),
        const SizedBox(height: 48),
        OutlinedButton(
          onPressed: () {
            _subscription?.cancel();
            setState(() {
              _isBackingUp = false;
            });
            widget.onCancel();
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white24),
            foregroundColor: Colors.white54,
          ),
          child: Text(l10n.scanCancel),
        ),
      ],
    );
  }
}
