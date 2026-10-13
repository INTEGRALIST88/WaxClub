import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/sync_state.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/ui/widgets/vinyl_status_footer.dart';
import 'package:waxclub/ui/widgets/wood_mic_button.dart';

void main() {
  for (final width in const [360.0, 320.0, 800.0]) {
    testWidgets('barra inferior com microfone no centro cabe em ${width.toInt()} de largura', (tester) async {
      tester.view.physicalSize = Size(width, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: VinylStatusFooter(
            telemetry: const VinylTelemetry(
              status: CalibrationStatus.playingUncalibrated,
              isMicActive: true,
              countdownSeconds: 12,
            ),
            track: const TrackInfo(title: 'Coming Around Again', artist: 'Carly Simon', offsetSeconds: 0),
            onPlayPause: () {},
            onStop: () {},
            isListening: true,
            onMicPressed: () => tapped = true,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull, reason: 'nada pode estourar na barra');
      expect(find.text('Calibrating in 12s'), findsOneWidget);
      expect(find.byType(WoodMicButton), findsOneWidget);

      // o microfone fica no centro da barra
      final mic = tester.getCenter(find.byType(WoodMicButton));
      expect((mic.dx - width / 2).abs(), lessThan(width * 0.12));

      await tester.tap(find.byType(WoodMicButton));
      expect(tapped, isTrue);
    });
  }
}
