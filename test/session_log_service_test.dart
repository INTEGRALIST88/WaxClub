import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/session_log_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_log_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SessionLogService Tests (T0.5)', () {
    test('grava e lê eventos em formato JSON Lines', () async {
      final logService = SessionLogService(storageDirectory: tempDir);

      await logService.log('track_recognized', {
        'title': 'Song 1',
        'artist': 'Artist A',
      });
      await logService.log('calibration_done', {
        'speedFactor': 1.018,
      });

      final tailContent = await logService.tail(lines: 10);
      expect(tailContent, contains('track_recognized'));
      expect(tailContent, contains('calibration_done'));
      expect(tailContent, contains('Song 1'));
    });

    test('concorrência: gravações simultâneas não quebram o arquivo', () async {
      final logService = SessionLogService(storageDirectory: tempDir);

      final futures = <Future<void>>[];
      for (int i = 0; i < 20; i++) {
        futures.add(logService.log('event_$i', {'idx': i}));
      }
      await Future.wait(futures);

      final tail = await logService.tail(lines: 50);
      final lines = tail.split('\n');
      expect(lines.length, equals(20));
    });
  });
}
