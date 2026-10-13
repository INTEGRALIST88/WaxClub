import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/track_entry.dart';

List<TrackEntry> _record(List<String> sides) => [
      for (var i = 0; i < sides.length; i++) TrackEntry(position: i + 1, title: 'Faixa ${i + 1}', side: sides[i]),
    ];

void main() {
  test('LP simples: o disco acaba no fim do lado B', () {
    final lp = _record(['A', 'A', 'B', 'B']);
    expect(WaxClubEngine.isLastSideOfRecord(lp, 'A'), isFalse);
    expect(WaxClubEngine.isLastSideOfRecord(lp, 'B'), isTrue);
  });

  test('disco duplo: o disco só acaba no fim do último lado (D)', () {
    final duplo = _record(['A', 'B', 'C', 'D']);
    expect(WaxClubEngine.isLastSideOfRecord(duplo, 'B'), isFalse, reason: 'fim do lado B não é o fim do disco duplo');
    expect(WaxClubEngine.isLastSideOfRecord(duplo, 'C'), isFalse);
    expect(WaxClubEngine.isLastSideOfRecord(duplo, 'd'), isTrue);
  });

  test('sem lados na lista de faixas não dá para saber', () {
    expect(WaxClubEngine.isLastSideOfRecord(_record(['', '']), 'A'), isFalse);
    expect(WaxClubEngine.isLastSideOfRecord(const [], 'B'), isFalse);
  });

  test('chave MANUAL começa desligada e liga/desliga', () {
    final engine = WaxClubEngine();
    expect(engine.isManualMode, isFalse);
    engine.setManualMode(true);
    expect(engine.isManualMode, isTrue);
    engine.setManualMode(false);
    expect(engine.isManualMode, isFalse);
    engine.dispose();
  });
}
