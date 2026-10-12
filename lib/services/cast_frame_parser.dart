import 'dart:convert';
import 'dart:typed_data';
import 'cast_v2_client.dart';

/// Exceção lançada quando ocorre um erro na análise de pacotes CastV2.
class CastFrameParseException implements Exception {
  final String message;
  const CastFrameParseException(this.message);

  @override
  String toString() => 'CastFrameParseException: $message';
}

/// Acumula bytes recebidos de uma conexão TCP/TLS CastV2 e decodifica
/// mensagens Protocol Buffers completas de forma orientada a stream.
///
/// Tolera:
/// - Quadros partidos em múltiplos pacotes TCP;
/// - Múltiplos quadros recebidos em um único chunk;
/// - Bytes residuais para o próximo quadro.
/// Possui limite configurável de tamanho de quadro para proteger memória (default: 1 MiB).
class CastFrameParser {
  static const int defaultMaxFrameLength = 1024 * 1024; // 1 MiB

  final int maxFrameLength;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  CastFrameParser({this.maxFrameLength = defaultMaxFrameLength});

  /// Quantidade atual de bytes em espera no buffer.
  int get bufferedBytes => _buffer.length;

  /// Limpa o buffer de frames.
  void clear() {
    _buffer.clear();
  }

  /// Adiciona um pedaço (chunk) de bytes recebidos da rede e retorna
  /// todas as mensagens [CastMessage] completas decodificadas.
  List<CastMessage> add(List<int> chunk) {
    if (chunk.isEmpty) return const [];

    _buffer.add(chunk);
    final messages = <CastMessage>[];

    // O enquadramento exige pelo menos 4 bytes de cabeçalho Big-Endian
    Uint8List currentBytes = _buffer.toBytes();

    int offset = 0;
    while (currentBytes.length - offset >= 4) {
      final headerData = ByteData.sublistView(currentBytes, offset, offset + 4);
      final frameLength = headerData.getUint32(0, Endian.big);

      if (frameLength > maxFrameLength) {
        clear();
        throw CastFrameParseException(
          'Quadro CastV2 excede o limite máximo permitido ($frameLength > $maxFrameLength bytes). Buffer resetado.',
        );
      }

      final totalRequired = 4 + frameLength;
      if (currentBytes.length - offset < totalRequired) {
        // Quadro incompleto: aguardar mais dados da rede
        break;
      }

      // Extrai os bytes exatos do corpo protobuf
      final protoBytes = Uint8List.sublistView(
        currentBytes,
        offset + 4,
        offset + totalRequired,
      );

      try {
        final message = parseProtobufMessage(protoBytes);
        messages.add(message);
      } catch (e) {
        // Se falhar o parse do protobuf individual, registramos e continuamos
      }

      offset += totalRequired;
    }

    // Preserva apenas os bytes que sobraram no buffer
    _buffer.clear();
    if (offset < currentBytes.length) {
      _buffer.add(currentBytes.sublist(offset));
    }

    return messages;
  }

  /// Decodifica os campos de uma mensagem protobuf CastMessage serializada.
  static CastMessage parseProtobufMessage(Uint8List bytes) {
    int offset = 0;
    int protocolVersion = 0;
    String sourceId = '';
    String destinationId = '';
    String namespace = '';
    int payloadType = 0;
    String payloadUtf8 = '';
    Uint8List? payloadBinary;

    while (offset < bytes.length) {
      final varintResult = _readVarint(bytes, offset);
      final key = varintResult.value;
      offset = varintResult.nextOffset;

      final fieldNumber = key >> 3;
      final wireType = key & 0x07;

      switch (wireType) {
        case 0: // Varint
          final valResult = _readVarint(bytes, offset);
          final value = valResult.value;
          offset = valResult.nextOffset;

          if (fieldNumber == 1) {
            protocolVersion = value;
          } else if (fieldNumber == 5) {
            payloadType = value;
          }
          break;

        case 2: // Length-delimited (string ou bytes)
          final lenResult = _readVarint(bytes, offset);
          final length = lenResult.value;
          offset = lenResult.nextOffset;

          if (offset + length > bytes.length) {
            throw const CastFrameParseException('Campo protobuf ultrapassa comprimento da mensagem');
          }

          final fieldBytes = bytes.sublist(offset, offset + length);
          offset += length;

          if (fieldNumber == 2) {
            sourceId = utf8.decode(fieldBytes, allowMalformed: true);
          } else if (fieldNumber == 3) {
            destinationId = utf8.decode(fieldBytes, allowMalformed: true);
          } else if (fieldNumber == 4) {
            namespace = utf8.decode(fieldBytes, allowMalformed: true);
          } else if (fieldNumber == 6) {
            payloadUtf8 = utf8.decode(fieldBytes, allowMalformed: true);
          } else if (fieldNumber == 7) {
            payloadBinary = Uint8List.fromList(fieldBytes);
          }
          break;

        case 1: // 64-bit
          offset += 8;
          break;

        case 5: // 32-bit
          offset += 4;
          break;

        default:
          throw CastFrameParseException('Wire type protobuf não suportado: $wireType');
      }
    }

    return CastMessage(
      sourceId: sourceId,
      destinationId: destinationId,
      namespace: namespace,
      payloadUtf8: payloadUtf8,
      protocolVersion: protocolVersion,
      payloadType: payloadType,
      payloadBinary: payloadBinary,
    );
  }

  static _VarintResult _readVarint(Uint8List bytes, int offset) {
    int result = 0;
    int shift = 0;
    int currentOffset = offset;

    while (currentOffset < bytes.length) {
      final b = bytes[currentOffset++];
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) {
        return _VarintResult(result, currentOffset);
      }
      shift += 7;
      if (shift >= 64) {
        throw const CastFrameParseException('Varint com overflow de 64 bits');
      }
    }
    throw const CastFrameParseException('Varint truncado no final do buffer');
  }
}

class _VarintResult {
  final int value;
  final int nextOffset;
  const _VarintResult(this.value, this.nextOffset);
}
