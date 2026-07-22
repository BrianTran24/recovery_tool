import 'dart:io';
import 'package:crypto/crypto.dart';

class FileFragment {
  final int sector;
  final int numSectors;
  final int remainingBytes;
  final int totalBytesInFragment;

  FileFragment({
    required this.sector,
    required this.numSectors,
    required this.remainingBytes,
    required this.totalBytesInFragment,
  });
}

class ExpectedFile {
  final String filename;
  final String sha1;
  final String sourceImage;
  final List<FileFragment> fragments;
  final int totalBytes;

  ExpectedFile({
    required this.filename,
    required this.sha1,
    required this.sourceImage,
    required this.fragments,
    required this.totalBytes,
  });

  int get firstSector => fragments.isNotEmpty ? fragments.first.sector : -1;

  @override
  String toString() => '$filename (Sectors: ${fragments.map((f) => f.sector).join(',')}, Size: $totalBytes, SHA1: $sha1)';
}

class E01TestUtils {
  static List<ExpectedFile> parseReport(String reportPath) {
    final file = File(reportPath);
    if (!file.existsSync()) return [];

    final content = file.readAsStringSync();
    // Split by "Original Filename:" but keep it in the block
    final rawBlocks = content.split('Original Filename:');
    final results = <ExpectedFile>[];

    for (var rawBlock in rawBlocks) {
      if (rawBlock.trim().isEmpty) continue;
      final block = 'Original Filename:$rawBlock';

      try {
        final lines = block.split('\n');
        String? filename;
        String? sha1;
        String? sourceImage;
        final fragments = <FileFragment>[];
        int? totalBytes;

        for (var line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.startsWith('Original Filename:')) {
            final parts = trimmedLine.split('Original Filename:')[1].split('  in:');
            filename = parts[0].trim();
            if (parts.length > 1) {
              sourceImage = parts[1].trim();
            }
          } else if (trimmedLine.startsWith('SHA 1:')) {
            sha1 = trimmedLine.split('SHA 1:')[1].trim();
          } else if (trimmedLine.contains('@ sector')) {
            // Extract fragment info
            // Example: @ sector      224 ;    64  512-byte sectors                (  32768 bytes total)
            // Example: @ sector    12416 ;    77  512-byte sectors and 235 bytes  (  39659 bytes total)
            final sectorParts = trimmedLine.split('@ sector');
            final afterSector = sectorParts[1].split(';');
            final sector = int.tryParse(afterSector[0].trim());
            
            if (sector != null) {
              final infoParts = afterSector[1].split('512-byte sectors');
              final numSectors = int.tryParse(infoParts[0].trim()) ?? 0;
              
              int remainingBytes = 0;
              if (infoParts[1].contains('and')) {
                final remParts = infoParts[1].split('and');
                remainingBytes = int.tryParse(remParts[1].split('bytes')[0].trim()) ?? 0;
              }
              
              int fragmentTotal = 0;
              if (trimmedLine.contains('(')) {
                final totalParts = trimmedLine.split('(');
                fragmentTotal = int.tryParse(totalParts.last.split('bytes')[0].trim()) ?? 0;
              }

              fragments.add(FileFragment(
                sector: sector,
                numSectors: numSectors,
                remainingBytes: remainingBytes,
                totalBytesInFragment: fragmentTotal,
              ));
            }
          }
        }

        // Calculate total bytes from fragments if not explicitly found in a single line (though usually it is)
        int calculatedTotalBytes = fragments.fold(0, (sum, f) => sum + f.totalBytesInFragment);

        if (filename != null && sha1 != null && fragments.isNotEmpty) {
          results.add(ExpectedFile(
            filename: filename,
            sha1: sha1,
            sourceImage: sourceImage ?? 'unknown',
            fragments: fragments,
            totalBytes: calculatedTotalBytes,
          ));
        }
      } catch (e) {
        print('Error parsing block: $e');
      }
    }

    return results;
  }

  static String calculateSha1(File file) {
    final bytes = file.readAsBytesSync();
    return sha1.convert(bytes).toString();
  }
}
