import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/mic_busy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.waxclub.app/mic');

  test('microfone silenciado pelo sistema bloqueia a captura', () {
    expect(const MicStatus(silenced: true, recordings: 1).blocksCapture(-20), isTrue);
  });

  test('outro app gravando + áudio mudo = bloqueado; com som, não', () {
    const status = MicStatus(silenced: false, recordings: 2);
    expect(status.otherRecordings, 1);
    expect(status.blocksCapture(-120), isTrue, reason: 'silêncio digital');
    expect(status.blocksCapture(-35), isFalse, reason: 'o WaxClub ainda ouve o disco');
  });

  test('só o WaxClub gravando nunca é bloqueio, mesmo em silêncio (agulha fora do disco)', () {
    expect(const MicStatus(silenced: false, recordings: 1).blocksCapture(-120), isFalse);
  });

  test('lê o estado do Android pelo canal com.waxclub.app/mic', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'status');
      return {'silenced': true, 'recordings': 2, 'sdk': 33};
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final status = await const MicBusyService().check();
    expect(status?.silenced, isTrue);
    expect(status?.recordings, 2);
  });

  test('fora do Android (sem o canal) devolve nulo', () async {
    expect(await const MicBusyService().check(), isNull);
  });
}
