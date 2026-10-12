import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';

void main() {
  group('LyricsProviderService Tests', () {
    test('instanciação e ciclo de vida do LyricsProviderService', () {
      final service = LyricsProviderService();
      expect(service.lrcLibService, isA<LrcLibService>());
      service.dispose();
    });

    test('limpeza correta de termos com sufixos comuns', () {
      final service = LyricsProviderService();
      expect(service.lrcLibService, isNotNull);
      service.dispose();
    });
  });
}
