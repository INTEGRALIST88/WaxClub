import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/ui/widgets/curiosity_badge.dart';

void main() {
  test('o brilho de cada ⓘ vai até o fim mesmo se a duração mudar depois (antes congelava no meio)', () {
    final shine = AnimationController(vsync: const TestVSync(), duration: const Duration(seconds: 1));
    // A coleção carregou depois de a lista aparecer: 8 discos → duração maior
    shine.duration = Duration(milliseconds: 8 * CuriosityBadge.stepMs + CuriosityBadge.glowMs);

    shine.value = 0.5;
    expect(CuriosityBadge.progress(shine, 0), 1.0, reason: 'o primeiro já brilhou');
    expect(CuriosityBadge.progress(shine, 7), 0.0, reason: 'o último ainda vai brilhar');

    shine.value = 1.0;
    for (var i = 0; i < 8; i++) {
      expect(CuriosityBadge.progress(shine, i), 1.0, reason: 'no fim, todos terminaram (nenhum parado no meio)');
    }
    shine.dispose();
  });
}
