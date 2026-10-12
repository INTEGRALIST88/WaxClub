import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/cast_v2_client.dart';

class FakeCastSocket implements CastSocket {
  final StreamController<List<int>> _controller = StreamController<List<int>>();
  final List<CastMessage> sentMessages = [];
  bool isClosed = false;

  @override
  Stream<List<int>> get stream => _controller.stream;

  @override
  void add(List<int> data) {
    if (isClosed) return;
    try {
      // Tenta decodificar a mensagem enviada
      final frameLength = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 4))).getUint32(0, Endian.big);
      if (data.length >= 4 + frameLength) {
        final protoBytes = Uint8List.fromList(data.sublist(4, 4 + frameLength));
        final msg = CastMessage.fromProtobufBytes(protoBytes);
        sentMessages.add(msg);
      }
    } catch (_) {}
  }

  void emit(List<int> bytes) {
    if (!_controller.isClosed) {
      _controller.add(bytes);
    }
  }

  void emitMessage(CastMessage msg) {
    emit(msg.toProtobufBytes());
  }

  @override
  Future<void> close() async {
    isClosed = true;
    await _controller.close();
  }
}

void main() {
  group('CastMessage Serialization', () {
    test('CastMessage serializes to valid CastV2 frame format', () {
      final msg = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: 'urn:x-cast:com.google.cast.tp.connection',
        payloadUtf8: jsonEncode({'type': 'CONNECT'}),
      );

      final bytes = msg.toProtobufBytes();
      expect(bytes.length, greaterThan(4));

      final byteData = ByteData.sublistView(bytes);
      final declaredLength = byteData.getUint32(0, Endian.big);
      expect(bytes.length - 4, equals(declaredLength));
      expect(bytes[4], equals(0x08));
      expect(bytes[5], equals(0x00));
    });

    test('CastMessage serializes LAUNCH request with App ID 27687E0B', () {
      final msg = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: 'urn:x-cast:com.google.cast.receiver',
        payloadUtf8: jsonEncode({
          'type': 'LAUNCH',
          'appId': '27687E0B',
          'requestId': 1,
        }),
      );

      final bytes = msg.toProtobufBytes();
      final byteData = ByteData.sublistView(bytes);
      final declaredLength = byteData.getUint32(0, Endian.big);
      expect(bytes.length - 4, equals(declaredLength));

      final contentString = String.fromCharCodes(bytes);
      expect(contentString.contains('27687E0B'), isTrue);
      expect(contentString.contains('urn:x-cast:com.google.cast.receiver'), isTrue);
    });
  });

  group('CastV2Client State & Lifecycle Tests (T1.2)', () {
    test('App já rodando na TV pula LAUNCH e conecta direto ao transportId', () async {
      late FakeCastSocket fakeSocket;
      final client = CastV2Client(
        socketConnector: (host, port, {Duration timeout = const Duration(seconds: 8)}) async {
          fakeSocket = FakeCastSocket();
          // Simula resposta imediata de GET_STATUS com app já em execução
          Future.delayed(const Duration(milliseconds: 20), () {
            fakeSocket.emitMessage(CastMessage(
              sourceId: 'receiver-0',
              destinationId: 'sender-0',
              namespace: CastV2Client.nsReceiver,
              payloadUtf8: jsonEncode({
                'type': 'RECEIVER_STATUS',
                'status': {
                  'applications': [
                    {
                      'appId': '27687E0B',
                      'displayName': 'WaxClub TV',
                      'transportId': 'transport-waxclub-123',
                    }
                  ]
                }
              }),
            ));
          });
          return fakeSocket;
        },
      );

      final ok = await client.launchApp(
        host: '192.168.1.100',
        tlsTimeout: const Duration(seconds: 2),
        launchTimeout: const Duration(seconds: 4),
      );

      expect(ok, isTrue);
      expect(client.isConnected, isTrue);
      expect(client.transportId, equals('transport-waxclub-123'));

      // Verifica se NÃO enviou o comando LAUNCH
      final hasLaunch = fakeSocket.sentMessages.any((m) =>
          m.namespace == CastV2Client.nsReceiver && m.payloadUtf8.contains('"LAUNCH"'));
      expect(hasLaunch, isFalse, reason: 'Não deve disparar LAUNCH se o app já está rodando');

      // Verifica se conectou ao transportId
      final connectedToTransport = fakeSocket.sentMessages.any((m) =>
          m.destinationId == 'transport-waxclub-123' &&
          m.namespace == CastV2Client.nsConnection &&
          m.payloadUtf8.contains('"CONNECT"'));
      expect(connectedToTransport, isTrue);

      await client.disconnect();
    });

    test('PING recebido da TV responde automaticamente com PONG', () async {
      late FakeCastSocket fakeSocket;
      final client = CastV2Client(
        socketConnector: (host, port, {Duration timeout = const Duration(seconds: 8)}) async {
          fakeSocket = FakeCastSocket();
          Future.delayed(const Duration(milliseconds: 20), () {
            fakeSocket.emitMessage(CastMessage(
              sourceId: 'receiver-0',
              destinationId: 'sender-0',
              namespace: CastV2Client.nsReceiver,
              payloadUtf8: jsonEncode({
                'type': 'RECEIVER_STATUS',
                'status': {
                  'applications': [
                    {
                      'appId': '27687E0B',
                      'transportId': 'transport-pong-test',
                    }
                  ]
                }
              }),
            ));
          });
          return fakeSocket;
        },
      );

      await client.launchApp(host: '192.168.1.50');

      // Simula TV enviando PING no canal de heartbeat
      fakeSocket.emitMessage(const CastMessage(
        sourceId: 'transport-pong-test',
        destinationId: 'sender-0',
        namespace: CastV2Client.nsHeartbeat,
        payloadUtf8: '{"type":"PING"}',
      ));

      await Future.delayed(const Duration(milliseconds: 30));

      final sentPong = fakeSocket.sentMessages.any((m) =>
          m.namespace == CastV2Client.nsHeartbeat &&
          m.destinationId == 'transport-pong-test' &&
          m.payloadUtf8.contains('"PONG"'));
      expect(sentPong, isTrue, reason: 'Deve responder com PONG imediatamente');

      await client.disconnect();
    });

    test('Fechamento remoto (CLOSE) notifica callback onDisconnected', () async {
      late FakeCastSocket fakeSocket;
      bool notified = false;

      final client = CastV2Client(
        socketConnector: (host, port, {Duration timeout = const Duration(seconds: 8)}) async {
          fakeSocket = FakeCastSocket();
          Future.delayed(const Duration(milliseconds: 20), () {
            fakeSocket.emitMessage(CastMessage(
              sourceId: 'receiver-0',
              destinationId: 'sender-0',
              namespace: CastV2Client.nsReceiver,
              payloadUtf8: jsonEncode({
                'type': 'RECEIVER_STATUS',
                'status': {
                  'applications': [
                    {
                      'appId': '27687E0B',
                      'transportId': 'transport-close-test',
                    }
                  ]
                }
              }),
            ));
          });
          return fakeSocket;
        },
      );
      client.onDisconnected = () {
        notified = true;
      };

      await client.launchApp(host: '192.168.1.50');
      expect(client.isConnected, isTrue);

      // Simula TV enviando CLOSE para a aplicação
      fakeSocket.emitMessage(const CastMessage(
        sourceId: 'transport-close-test',
        destinationId: 'sender-0',
        namespace: CastV2Client.nsConnection,
        payloadUtf8: '{"type":"CLOSE"}',
      ));

      await Future.delayed(const Duration(milliseconds: 30));
      expect(notified, isTrue);
      expect(client.isConnected, isFalse);
    });

    test('sendCustomMessage envia estritamente ao transportId e nunca ao receiver-0', () async {
      late FakeCastSocket fakeSocket;
      final client = CastV2Client(
        socketConnector: (host, port, {Duration timeout = const Duration(seconds: 8)}) async {
          fakeSocket = FakeCastSocket();
          Future.delayed(const Duration(milliseconds: 20), () {
            fakeSocket.emitMessage(CastMessage(
              sourceId: 'receiver-0',
              destinationId: 'sender-0',
              namespace: CastV2Client.nsReceiver,
              payloadUtf8: jsonEncode({
                'type': 'RECEIVER_STATUS',
                'status': {
                  'applications': [
                    {
                      'appId': '27687E0B',
                      'transportId': 'transport-isolated',
                    }
                  ]
                }
              }),
            ));
          });
          return fakeSocket;
        },
      );

      await client.launchApp(host: '192.168.1.50');
      fakeSocket.sentMessages.clear();

      client.sendCustomMessage({'type': 'sync_update', 'activeLine': 5});

      expect(fakeSocket.sentMessages.length, equals(1));
      expect(fakeSocket.sentMessages.first.destinationId, equals('transport-isolated'));
      expect(fakeSocket.sentMessages.first.namespace, equals(CastV2Client.nsCustomSync));

      // Nenhuma mensagem foi enviada ao receiver-0
      final sentToReceiver0 = fakeSocket.sentMessages.any((m) => m.destinationId == 'receiver-0');
      expect(sentToReceiver0, isFalse);

      await client.disconnect();
    });
  });
}
