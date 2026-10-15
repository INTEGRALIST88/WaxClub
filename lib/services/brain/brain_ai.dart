import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'brain_chips.dart';
import 'brain_service.dart';

/// Falha ao usar a IA: nenhum chip encaixado, ou todos sem limite / recusados / sem resposta.
class BrainAiException implements Exception {
  final String reason; // 'no_chip', 'all_failed'
  const BrainAiException(this.reason);
  @override
  String toString() => 'BrainAiException($reason)';
}

/// Executor de IA do WaxClub: os plugins de IA não têm código, só um pedido (prompt); este executor o
/// envia ao primeiro chip pronto do WaxBrain e, se o chip estiver no limite, recusar a chave ou não
/// responder, passa ao próximo. Sempre com a moldura de regras do app, que o plugin não consegue tirar.
class BrainAi {
  final BrainService brain;
  final http.Client _client;

  BrainAi({required this.brain, http.Client? client}) : _client = client ?? http.Client();

  /// Regras do app em todo pedido de plugin.
  static const String appRules =
      'You work inside WaxClub, a vinyl record companion app. Follow the task exactly. '
      'Never produce hateful, sexual, violent or otherwise harmful content beyond what the source text itself contains. '
      'Do not add facts you are not sure about. Answer only with what the task asks for, with no preamble.';

  /// Envia o pedido ([system] + [user]) e devolve o texto da resposta.
  Future<String> complete({required String system, required String user, int maxTokens = 2048}) async {
    await brain.load();
    final candidates = [
      for (final p in brain.plugged)
        if (p.status != BrainKeyStatus.invalid && p.chip != null) p,
    ];
    if (candidates.isEmpty) throw const BrainAiException('no_chip');
    for (final p in candidates) {
      final chip = p.chip!;
      try {
        final res = await _send(chip, p.key, '$appRules\n\n$system', user, maxTokens);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final text = extractText(chip.api, jsonDecode(utf8.decode(res.bodyBytes)));
          if (text != null && text.trim().isNotEmpty) return text.trim();
          continue;
        }
        final status = BrainService.statusForHttp(res.statusCode);
        debugPrint('[BrainAi] ${chip.id} respondeu ${res.statusCode}; tentando o próximo chip.');
        if (status == BrainKeyStatus.limit || status == BrainKeyStatus.invalid) {
          await brain.markStatus(chip.id, status);
        }
      } catch (e) {
        debugPrint('[BrainAi] ${chip.id} sem resposta ($e); tentando o próximo chip.');
      }
    }
    throw const BrainAiException('all_failed');
  }

  Future<http.Response> _send(BrainChip chip, String key, String system, String user, int maxTokens) {
    const timeout = Duration(seconds: 60);
    switch (chip.api) {
      case BrainApi.gemini:
        return _client
            .post(
              Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${chip.model}:generateContent?key=$key'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'systemInstruction': {
                  'parts': [
                    {'text': system}
                  ]
                },
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': user}
                    ]
                  }
                ],
                'generationConfig': {'temperature': 0.3, 'maxOutputTokens': maxTokens},
              }),
            )
            .timeout(timeout);
      case BrainApi.anthropic:
        return _client
            .post(
              Uri.parse('https://api.anthropic.com/v1/messages'),
              headers: {'Content-Type': 'application/json', ...chip.checkHeaders(key)},
              body: jsonEncode({
                'model': chip.model,
                'max_tokens': maxTokens,
                'system': system,
                'messages': [
                  {'role': 'user', 'content': user}
                ],
              }),
            )
            .timeout(timeout);
      case BrainApi.openAiCompatible:
        return _client
            .post(
              Uri.parse('${chip.chatBase}/chat/completions'),
              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
              body: jsonEncode({
                'model': chip.model,
                'temperature': 0.3,
                'max_tokens': maxTokens,
                'messages': [
                  {'role': 'system', 'content': system},
                  {'role': 'user', 'content': user},
                ],
              }),
            )
            .timeout(timeout);
    }
  }

  /// Texto da resposta em cada formato de API; nulo se a resposta não trouxer texto.
  static String? extractText(BrainApi api, dynamic j) {
    try {
      switch (api) {
        case BrainApi.gemini:
          final parts = j['candidates'][0]['content']['parts'] as List<dynamic>;
          return parts.map((p) => p['text'] ?? '').join();
        case BrainApi.anthropic:
          final content = j['content'] as List<dynamic>;
          return content.where((c) => c['type'] == 'text').map((c) => c['text']).join();
        case BrainApi.openAiCompatible:
          return j['choices'][0]['message']['content'] as String?;
      }
    } catch (_) {
      return null;
    }
  }
}
