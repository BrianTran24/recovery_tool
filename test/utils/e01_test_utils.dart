import 'dart:io';
import 'package:crypto/crypto.dart';

class ExpectedFile {
  final String filename;
  final String sha1;
  final int sector;
  final int totalBytes;

  ExpectedFile({
    required this.filename,
    required this.sha1,
    required this.sector,
    required this.totalBytes,
  });

  @override
  String toString() => '$filename (Sector: $sector, Size: $totalBytes, SHA1: $sha1)';
}

class E01TestUtils {
  static List<ExpectedFile> parseReport(String reportPath) {
    final file = File(reportPath);
    if (!file.existsSync()) return [];

    final content = file.readAsStringSync();
    final blocks = content.split('\n\n');
    final results = <ExpectedFile>[];

    for (var block in blocks) {
      if (block.trim().isEmpty) continue;

      try {
        final lines = block.split('\n');
        String? filename;
        String? sha1;
        int? sector;
        int? totalBytes;

        for (var line in lines) {
          if (line.startsWith('Original Filename:')) {
            filename = line.split('Original Filename:')[1].split('  in:')[0].trim();
          } else if (line.startsWith('SHA 1:')) {
            sha1 = line.split('SHA 1:')[1].trim();
          } else if (line.contains('@ sector')) {
            final parts = line.split('@ sector');
            // We take the first sector occurrence in the block as the primary location
            if (sector == null) {
              final sectorStr = parts[1].split(';')[0].trim();
              sector = int.tryParse(sectorStr);
            }
            
            if (line.contains('total)')) {
              final totalParts = line.split('(');
              final bytesStr = totalParts.last.split('bytes')[0].trim();
              totalBytes = int.tryParse(bytesStr);
            }
          }
        }

        if (filename != null && sha1 != null && sector != null && totalBytes != null) {
          results.add(ExpectedFile(
            filename: filename,
            sha1: sha1,
            sector: sector,
            totalBytes: totalBytes,
          ));
        }
      } catch (e) {
        // Skip malformed blocks
      }
    }

    return results;
  }

  static String calculateSha1(File file) {
    final bytes = file.readAsBytesSync();
    return sha1.convert(bytes).toString();
  }
}
