import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/core/service/photorec_runner.dart';
import 'package:recovery_tool/core/models/recovery_event.dart';

void main() {
  group('PhotoRec Parsing Tests', () {
    test('parseProgress identifies percentage', () {
      const line = 'Pass 0 - Reading sector 1234/5678, 45%';
      final event = PhotoRecRunner.parseProgress(line);
      expect(event, isNotNull);
      expect(event!.percent, 45.0);
    });

    test('parseProgress returns null if no percentage', () {
      const line = 'PhotoRec 7.1, Data Recovery Utility';
      final event = PhotoRecRunner.parseProgress(line);
      expect(event, isNull);
    });

    test('parseLogEntry identifies found file', () {
      const line = 'File found: f0000000.jpg at 1024';
      final event = PhotoRecRunner.parseLogEntry(line);
      expect(event, isNotNull);
      expect(event!.filename, 'f0000000.jpg');
      expect(event.fileType, 'JPG');
      expect(event.sectorOffset, 1024);
    });

    test('parseLogEntry handles complex filenames', () {
      const line = 'File found: photo_holiday_2023.png at 50000';
      final event = PhotoRecRunner.parseLogEntry(line);
      expect(event, isNotNull);
      expect(event!.filename, 'photo_holiday_2023.png');
      expect(event.fileType, 'PNG');
      expect(event.sectorOffset, 50000);
    });
  });
}
