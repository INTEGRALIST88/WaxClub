import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/app_info.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/phone_announcer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(PhoneAnnouncer.channelName);
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'register' ? true : null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('anuncia o celular como _waxclub._tcp com porta, nome e campos para a TV conectar', () async {
    final announcer = PhoneAnnouncer();
    await announcer.announce(port: 8088);

    expect(announcer.isAnnounced, isTrue);
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(calls.single.method, 'register');
    expect(args['serviceType'], '_waxclub._tcp');
    expect(args['serviceName'], kAppName);
    expect(args['port'], 8088);
    final txt = Map<String, String>.from(args['attributes'] as Map);
    expect(txt['ws'], '/cast');
    expect(txt['path'], '/');
    expect(txt['v'], PhoneAnnouncer.protocolVersion);
    expect(txt['ver'], kAppVersion);

    await announcer.withdraw();
    expect(calls.last.method, 'unregister');
    expect(announcer.isAnnounced, isFalse);
  });

  test('servidor da página da TV anuncia ao subir e retira o anúncio ao fechar', () async {
    final service = CastSyncService();
    await service.startLocalServer(port: 0); // porta livre qualquer
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final register = calls.firstWhere((c) => c.method == 'register');
    final port = (register.arguments as Map)['port'] as int;
    expect(port, greaterThan(0));

    service.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calls.last.method, 'unregister');
  });

  test('fora do Android (sem o canal nativo) o app segue sem anúncio', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    final announcer = PhoneAnnouncer();
    await announcer.announce(port: 8088);
    expect(announcer.isAnnounced, isFalse);
    await announcer.withdraw();
  });
}
