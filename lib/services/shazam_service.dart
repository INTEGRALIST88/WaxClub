import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/track_info.dart';
import 'shazam_signature_generator.dart';

/// Cliente HTTP para a API de reconhecimento reverso do Shazam (Discovery v5).
class ShazamService {
  final http.Client _client = http.Client();

  /// Motivo da última falha de reconhecimento (ex.: 'no_match', 'http_429', 'network: ...'), ou null após sucesso.
  /// Registrado no log de sessão para diagnosticar músicas não reconhecidas.
  String? lastFailureReason;

  /// Quantidade de picos espectrais da última assinatura (pouca energia/sinal fraco quando muito baixa).
  int lastPeaksCount = 0;

  /// Envia amostra de áudio e retorna as informações da faixa identificada.
  /// A taxa de amostragem é extraída diretamente do cabeçalho do WAV.
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async {
    try {
      final wavInfo = ShazamSignatureGenerator.parseWavInfo(audioBytes);
      // Prioridade absoluta: taxa real do cabeçalho WAV (chunk fmt)
      final effectiveRate = wavInfo.dataOffset > 0 ? wavInfo.sampleRate : (sampleRate ?? 16000);

      final signatureUri = ShazamSignatureGenerator.generateSignatureFromAudio(
        audioBytes,
        originalSampleRate: effectiveRate,
      );

      final totalSamples = wavInfo.numChannels > 0
          ? (wavInfo.dataLength ~/ (2 * wavInfo.numChannels))
          : (audioBytes.length ~/ 2);
      // Duração declarada = duração da assinatura (16 kHz, com o preenchimento final), como no SongRec
      final sampleDurationMs = ((ShazamSignatureGenerator.lastNumberSamples / 16000) * 1000).round();

      final peaksCount = ShazamSignatureGenerator.lastExtractedPeaksCount;
      final bandCounts = ShazamSignatureGenerator.lastBandsPeaksCount;
      lastPeaksCount = peaksCount;
      debugPrint('[ShazamService] Enviando áudio: rateReal=${effectiveRate}Hz, canais=${wavInfo.numChannels}, samples=$totalSamples, dur=${sampleDurationMs}ms, picos=$peaksCount ($bandCounts)');
      return await recognizeSignature(signatureUri, sampleDurationMs: sampleDurationMs);
    } catch (e) {
      debugPrint('[ShazamService] Erro ao reconhecer áudio: $e');
      lastFailureReason = 'signature: $e';
      return null;
    }
  }

  /// Executa a chamada HTTP POST para o endpoint Discovery v5 do Shazam (estilo shazamio iPhone).
  /// Gera dinamicamente novos UUIDs a cada requisição para evitar colisões e respostas em cache nulo.
  Future<TrackInfo?> recognizeSignature(String signatureUri, {int sampleDurationMs = 4000}) async {
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final uuidUpper = const Uuid().v4().toUpperCase();
    final uuidLower = const Uuid().v4().toLowerCase();

    final url = Uri.parse(
      'https://amp.shazam.com/discovery/v5/en/US/iphone/-/tag/$uuidUpper/$uuidLower'
      '?sync=true&webv3=true&sampling=true&connected=&shazamapiversion=v3&sharehub=true&hubv5minorversion=v5.1&video=v3',
    );

    final payload = {
      'geolocation': {
        'altitude': 300,
        'latitude': 45.0,
        'longitude': 2.0,
      },
      'signature': {
        'samplems': sampleDurationMs,
        'timestamp': timestampMs,
        'uri': signatureUri,
      },
      'timestamp': timestampMs,
      'timezone': 'America/Sao_Paulo',
    };

    final headers = {
      'X-Shazam-Platform': 'IPHONE',
      'X-Shazam-AppVersion': '14.1.0',
      'Accept': '*/*',
      'Accept-Language': 'en',
      'Content-Type': 'application/json',
      'User-Agent': 'Shazam/3685 CFNetwork/1197 Darwin/20.0.0',
    };

    try {
      final response = await _client
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        final bodySnippet = response.body.substring(0, math.min(180, response.body.length));
        debugPrint('[ShazamService] ⚠️ Resposta inesperada do Shazam: HTTP ${response.statusCode} (tagId: $uuidLower, body=$bodySnippet)');
        lastFailureReason = 'http_${response.statusCode}';
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final track = data['track'] as Map<String, dynamic>?;
      if (track == null) {
        final peaks = ShazamSignatureGenerator.lastExtractedPeaksCount;
        debugPrint('[ShazamService] ℹ️ Shazam respondeu sem correspondência (tagId: $uuidLower, picos: $peaks, dur: ${sampleDurationMs}ms).');
        lastFailureReason = 'no_match';
        return null; // Nenhuma faixa correspondente identificada
      }

      final title = track['title'] as String? ?? 'Desconhecido';
      final artist = track['subtitle'] as String? ?? 'Artista Desconhecido';
      final coverUrl = track['images']?['coverart'] as String?;

      // Extrai o offset temporal retornado pelo Shazam na correspondência
      double offsetSeconds = 0.0;
      final matches = data['matches'] as List<dynamic>?;
      if (matches != null && matches.isNotEmpty) {
        final firstMatch = matches.first as Map<String, dynamic>;
        final offset = firstMatch['offset'];
        if (offset is num) {
          offsetSeconds = offset.toDouble();
        }
      }

      debugPrint('[ShazamService] ✅ FAIXA IDENTIFICADA: "$title" por "$artist" (offset: ${offsetSeconds.toStringAsFixed(1)}s, tagId: $uuidLower)');
      lastFailureReason = null;

      return TrackInfo(
        title: title,
        artist: artist,
        coverUrl: coverUrl,
        offsetSeconds: offsetSeconds,
      );
    } catch (e) {
      debugPrint('[ShazamService] Erro no HTTP post: $e');
      lastFailureReason = 'network: ${e.runtimeType}';
      return null;
    }
  }

  /// Provê uma simulação realista de reconhecimento para testes e desenvolvimento
  /// sem necessidade de ter um disco de vinil tocando no ambiente de teste.
  static TrackInfo getMockTrack({
    String title = 'Bohemian Rhapsody',
    String artist = 'Queen',
    double offsetSeconds = 15.0,
  }) {
    return TrackInfo(
      title: title,
      artist: artist,
      album: 'A Night at the Opera',
      coverUrl: 'https://images.unsplash.com/photo-1539185441755-769473a23570?w=600&q=80',
      offsetSeconds: offsetSeconds,
    );
  }

  void dispose() {
    _client.close();
  }
}
