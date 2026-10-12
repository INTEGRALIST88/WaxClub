import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/cast_frame_parser.dart';
import 'package:waxclub/services/cast_v2_client.dart';

void main() {
  group('CastFrameParser Tests (T1.1)', () {
    test('Round-trip serialization and deserialization of CastMessage', () {
      const original = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: 'urn:x-cast:com.google.cast.tp.connection',
        payloadUtf8: '{"type":"CONNECT"}',
      );

      final frameBytes = original.toProtobufBytes();
      final parser = CastFrameParser();
      final messages = parser.add(frameBytes);

      expect(messages.length, equals(1));
      final decoded = messages.first;
      expect(decoded.sourceId, equals('sender-0'));
      expect(decoded.destinationId, equals('receiver-0'));
      expect(decoded.namespace, equals('urn:x-cast:com.google.cast.tp.connection'));
      expect(decoded.payloadUtf8, equals('{"type":"CONNECT"}'));
      expect(decoded.protocolVersion, equals(0));
      expect(decoded.payloadType, equals(0));
    });

    test('Quadro entregue byte a byte reconstitui a mensagem corretamente', () {
      const original = CastMessage(
        sourceId: 'sender-42',
        destinationId: 'transport-99',
        namespace: 'urn:x-cast:com.waxclub.sync',
        payloadUtf8: '{"type":"track_loaded","title":"Little Pink Stars"}',
      );

      final frameBytes = original.toProtobufBytes();
      final parser = CastFrameParser();

      List<CastMessage> result = [];
      for (int i = 0; i < frameBytes.length; i++) {
        final chunk = [frameBytes[i]];
        final msgs = parser.add(chunk);
        result.addAll(msgs);
      }

      expect(result.length, equals(1));
      expect(result.first.sourceId, equals('sender-42'));
      expect(result.first.destinationId, equals('transport-99'));
      expect(result.first.payloadUtf8, contains('Little Pink Stars'));
    });

    test('Dois quadros concatenados no mesmo pacote TCP são ambos processados', () {
      const msg1 = CastMessage(
        sourceId: 's1',
        destinationId: 'd1',
        namespace: 'ns1',
        payloadUtf8: '{"step":1}',
      );
      const msg2 = CastMessage(
        sourceId: 's2',
        destinationId: 'd2',
        namespace: 'ns2',
        payloadUtf8: '{"step":2}',
      );

      final builder = BytesBuilder();
      builder.add(msg1.toProtobufBytes());
      builder.add(msg2.toProtobufBytes());

      final parser = CastFrameParser();
      final messages = parser.add(builder.toBytes());

      expect(messages.length, equals(2));
      expect(messages[0].sourceId, equals('s1'));
      expect(messages[0].payloadUtf8, equals('{"step":1}'));
      expect(messages[1].sourceId, equals('s2'));
      expect(messages[1].payloadUtf8, equals('{"step":2}'));
    });

    test('Quadro completo seguido por metade do próximo processa o primeiro e guarda o resto', () {
      const msg1 = CastMessage(
        sourceId: 's1',
        destinationId: 'd1',
        namespace: 'ns1',
        payloadUtf8: '{"first":true}',
      );
      const msg2 = CastMessage(
        sourceId: 's2',
        destinationId: 'd2',
        namespace: 'ns2',
        payloadUtf8: '{"second":true}',
      );

      final bytes1 = msg1.toProtobufBytes();
      final bytes2 = msg2.toProtobufBytes();

      // Chunk 1: quadro 1 completo + primeiros 6 bytes do quadro 2
      final chunk1 = <int>[...bytes1, ...bytes2.sublist(0, 6)];
      final parser = CastFrameParser();
      final result1 = parser.add(chunk1);

      expect(result1.length, equals(1));
      expect(result1.first.payloadUtf8, equals('{"first":true}'));
      expect(parser.bufferedBytes, equals(6));

      // Chunk 2: restante dos bytes do quadro 2
      final chunk2 = bytes2.sublist(6);
      final result2 = parser.add(chunk2);

      expect(result2.length, equals(1));
      expect(result2.first.payloadUtf8, equals('{"second":true}'));
      expect(parser.bufferedBytes, equals(0));
    });

    test('Suporta payload complexo com chaves {}, colchetes e caracteres Unicode acentuados', () {
      const complexJson = '{"lyrics":["Coração {descompassado}", "São Paulo [ao vivo]"], "status":"ok"}';
      const msg = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'transport-1',
        namespace: 'urn:x-cast:com.waxclub.sync',
        payloadUtf8: complexJson,
      );

      final bytes = msg.toProtobufBytes();
      final parser = CastFrameParser();
      final messages = parser.add(bytes);

      expect(messages.length, equals(1));
      expect(messages.first.payloadUtf8, equals(complexJson));
      final decodedJson = jsonDecode(messages.first.payloadUtf8) as Map<String, dynamic>;
      expect(decodedJson['lyrics'][0], equals('Coração {descompassado}'));
    });

    test('Quadro acima do tamanho máximo reseta o buffer e lança CastFrameParseException', () {
      final parser = CastFrameParser(maxFrameLength: 100);
      // Criar cabeçalho com comprimento declarado de 500 bytes (maior que maxFrameLength = 100)
      final fakeHeader = ByteData(4)..setUint32(0, 500, Endian.big);
      final dummyBytes = Uint8List.fromList([...fakeHeader.buffer.asUint8List(), ...List.filled(20, 0)]);

      expect(
        () => parser.add(dummyBytes),
        throwsA(isA<CastFrameParseException>()),
      );
      expect(parser.bufferedBytes, equals(0));
    });
  });
}
