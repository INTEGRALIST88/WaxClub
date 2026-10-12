import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/sync_state.dart';

void main() {
  group('VinylTelemetry copyWith nullable clearing (T0.1)', () {
    test('default values', () {
      const telemetry = VinylTelemetry();
      expect(telemetry.isUserListening, isFalse);
      expect(telemetry.trackDurationSeconds, isNull);
      expect(telemetry.predictedNextTrackTitle, isNull);
      expect(telemetry.diagnosticMessage, isNull);
      expect(telemetry.sideEndLabel, isNull);
    });

    test('preserves values when copyWith called without clear flags', () {
      const telemetry = VinylTelemetry(
        trackDurationSeconds: 180.0,
        predictedNextTrackTitle: 'Next Song',
        diagnosticMessage: 'Listening...',
        sideEndLabel: 'Fim do lado A',
        isUserListening: true,
      );

      final copy = telemetry.copyWith(status: CalibrationStatus.calibrated);
      expect(copy.status, CalibrationStatus.calibrated);
      expect(copy.trackDurationSeconds, 180.0);
      expect(copy.predictedNextTrackTitle, 'Next Song');
      expect(copy.diagnosticMessage, 'Listening...');
      expect(copy.sideEndLabel, 'Fim do lado A');
      expect(copy.isUserListening, isTrue);
    });

    test('clears nullable fields when explicit clear flags are true', () {
      const telemetry = VinylTelemetry(
        trackDurationSeconds: 240.0,
        predictedNextTrackTitle: 'Track 2',
        diagnosticMessage: 'Calibrating',
        sideEndLabel: 'Fim do lado B',
        isUserListening: true,
      );

      final cleared = telemetry.copyWith(
        clearTrackDuration: true,
        clearPredictedNext: true,
        clearDiagnosticMessage: true,
        clearSideEndLabel: true,
        isUserListening: false,
      );

      expect(cleared.trackDurationSeconds, isNull);
      expect(cleared.predictedNextTrackTitle, isNull);
      expect(cleared.diagnosticMessage, isNull);
      expect(cleared.sideEndLabel, isNull);
      expect(cleared.isUserListening, isFalse);
    });

    test('updating a value while other is cleared', () {
      const telemetry = VinylTelemetry(
        trackDurationSeconds: 200.0,
        sideEndLabel: 'Fim do lado A',
      );

      final updated = telemetry.copyWith(
        clearSideEndLabel: true,
        predictedNextTrackTitle: 'New Song',
      );

      expect(updated.sideEndLabel, isNull);
      expect(updated.trackDurationSeconds, 200.0);
      expect(updated.predictedNextTrackTitle, 'New Song');
    });
  });
}
