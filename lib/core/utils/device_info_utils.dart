import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoUtils {
  static Future<String> getHWID() async {
    String rawId = '';
    try {
      if (Platform.isWindows) {
        final cpuResult = await Process.run('wmic', ['cpu', 'get', 'processorid']);
        final mbResult = await Process.run('wmic', ['baseboard', 'get', 'serialnumber']);
        rawId = '${cpuResult.stdout}${mbResult.stdout}'.trim();
      } else if (Platform.isMacOS) {
        final result = await Process.run('ioreg', ['-rd1', '-c', 'IOPlatformExpertDevice']);
        final output = result.stdout.toString();
        final match = RegExp(r'"IOPlatformSerialNumber" = "([^"]+)"').firstMatch(output);
        rawId = match?.group(1) ?? 'macos-unknown';
      } else if (Platform.isLinux) {
        final file = File('/etc/machine-id');
        if (await file.exists()) {
          rawId = await file.readAsString();
        } else {
          rawId = 'linux-unknown';
        }
      } else {
        rawId = 'unknown-platform';
      }
    } catch (e) {
      debugPrint('Error getting HWID: $e');
      rawId = 'error-hwid';
    }

    // Hash the raw ID to ensure a consistent format and privacy
    final bytes = utf8.encode(rawId);
    final digest = sha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  static String getDeviceName() {
    return Platform.localHostname;
  }
}
