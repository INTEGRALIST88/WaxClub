import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/second_screen_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.waxclub.app/second_screen');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'show') return true;
      if (call.method == 'state') return {'available': false, 'showing': false};
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('ao espelhar (Smart View/Miracast), mostra a letra na TV sozinha, com o nome da tela', () async {
    final s = SecondScreenService();
    var serverStarted = false;
    s.ensureServer = () async => serverStarted = true;
    s.applyStateForTesting({'available': true, 'showing': false, 'name': 'Samsung TV'});
    await Future<void>.delayed(Duration.zero);
    expect(s.isAvailable, isTrue);
    expect(serverStarted, isTrue, reason: 'a página da TV vem do servidor local do celular');
    final show = calls.singleWhere((c) => c.method == 'show');
    expect(show.arguments['url'], 'http://127.0.0.1:8088/?name=Samsung+TV');
  });

  test('desconectar pelo painel não reabre até o próximo espelhamento', () async {
    final s = SecondScreenService();
    s.applyStateForTesting({'available': true, 'showing': true, 'name': 'TV'});
    await s.hide(byUser: true);
    calls.clear();
    s.applyStateForTesting({'available': true, 'showing': false, 'name': 'TV'});
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c.method == 'show'), isEmpty, reason: 'o usuário tirou a letra da TV');

    // espelhamento encerrado e começado de novo: volta a abrir sozinha
    s.applyStateForTesting({'available': false, 'showing': false});
    s.applyStateForTesting({'available': true, 'showing': false, 'name': 'TV'});
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c.method == 'show'), hasLength(1));
  });

  test('sem TV espelhada, o botão abre a tela de espelhar do sistema', () async {
    final s = SecondScreenService();
    await s.openCastSettings();
    expect(calls.single.method, 'openCastSettings');
  });
}
