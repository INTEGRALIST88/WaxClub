import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/cast_device_registry.dart';

void main() {
  group('CastDeviceRegistry Tests (T1.4)', () {
    test('Ordenação estável: TVs primeiro, áudio-only depois, desempate por nome', () {
      final registry = CastDeviceRegistry();

      registry.upsert(const CastDevice(
        id: '1',
        name: 'Zeta Soundbar',
        host: '192.168.1.10',
        isAudioOnly: true,
      ));
      registry.upsert(const CastDevice(
        id: '2',
        name: 'Sala TV',
        host: '192.168.1.11',
        isAudioOnly: false,
      ));
      registry.upsert(const CastDevice(
        id: '3',
        name: 'Quarto TV',
        host: '192.168.1.12',
        isAudioOnly: false,
      ));
      registry.upsert(const CastDevice(
        id: '4',
        name: 'Alpha Speaker',
        host: '192.168.1.13',
        isAudioOnly: true,
      ));

      final devices = registry.getDevices();
      expect(devices.length, equals(4));

      // As duas TVs primeiro, ordenadas por nome: Quarto TV, Sala TV
      expect(devices[0].name, equals('Quarto TV'));
      expect(devices[0].isAudioOnly, isFalse);
      expect(devices[1].name, equals('Sala TV'));
      expect(devices[1].isAudioOnly, isFalse);

      // Os dois dispositivos só-áudio depois, ordenados por nome: Alpha Speaker, Zeta Soundbar
      expect(devices[2].name, equals('Alpha Speaker'));
      expect(devices[2].isAudioOnly, isTrue);
      expect(devices[3].name, equals('Zeta Soundbar'));
      expect(devices[3].isAudioOnly, isTrue);
    });

    test('Expiração com relógio injetável remove dispositivos com mais de 120s', () {
      DateTime simulatedTime = DateTime(2026, 1, 1, 12, 0, 0);
      final registry = CastDeviceRegistry(
        clock: () => simulatedTime,
        ttl: const Duration(seconds: 120),
      );

      registry.upsert(const CastDevice(
        id: '1',
        name: 'TV Sala',
        host: '192.168.1.20',
      ));

      expect(registry.getDevices(simulatedTime).length, equals(1));

      // Avança 60 segundos: ainda ativo
      simulatedTime = simulatedTime.add(const Duration(seconds: 60));
      expect(registry.getDevices(simulatedTime).length, equals(1));

      // Avança mais 65 segundos (total 125s > 120s): expirou
      simulatedTime = simulatedTime.add(const Duration(seconds: 65));
      expect(registry.getDevices(simulatedTime).length, equals(0));
    });

    test('Dispositivos em StandBy não são eliminados e ficam identificados', () {
      final registry = CastDeviceRegistry();

      registry.upsert(const CastDevice(
        id: 'standby-tv',
        name: 'TV Sala (Em Espera)',
        host: '192.168.1.33',
        isStandBy: true,
      ));

      final devices = registry.getDevices();
      expect(devices.length, equals(1));
      expect(devices.first.isStandBy, isTrue);
      expect(devices.first.host, equals('192.168.1.33'));
    });

    test('devicesStream emite updates ao inserir dispositivos', () async {
      final registry = CastDeviceRegistry();
      final emissions = <List<CastDevice>>[];

      final sub = registry.devicesStream.listen((list) {
        emissions.add(list);
      });

      registry.upsert(const CastDevice(id: '1', name: 'TV 1', host: '192.168.1.1'));
      registry.upsert(const CastDevice(id: '2', name: 'TV 2', host: '192.168.1.2'));

      await Future.delayed(const Duration(milliseconds: 20));
      expect(emissions.length, equals(2));
      expect(emissions.last.length, equals(2));

      await sub.cancel();
      registry.dispose();
    });
  });
}
