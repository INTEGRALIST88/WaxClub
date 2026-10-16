import 'dart:async';
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
/// envia a um chip do WaxBrain, sempre com a moldura de regras do app, que o plugin não consegue tirar.
///
/// Divisão do trabalho: cada chip atende um pedido por vez. Com mais de um chip encaixado, pedidos ao mesmo
/// tempo (tradutor A2 e Imagined Music A3, por exemplo) vão para chips diferentes, na ordem de prioridade.
/// Se um chip estiver no limite ("muitos pedidos"), sobrecarregado ou fora do ar, ele descansa um pouco e o
/// pedido passa para o próximo; com um chip só, espera e tenta de novo. Modelo aposentado pelo provedor: o
/// app consulta a lista de modelos dele e troca sozinho.
class BrainAi {
  final BrainService brain;
  final http.Client _client;

  BrainAi({required this.brain, http.Client? client, this.retryWait = const Duration(seconds: 15)})
      : _client = client ?? http.Client();

  /// Descanso de um chip depois de limite/sobrecarga (quando o provedor não diz quanto esperar).
  final Duration retryWait;

  /// Tentativas por chip em um mesmo pedido (limite, sobrecarga, modelo trocado).
  static const int triesPerChip = 3;

  /// Tempo máximo esperando um chip livre antes de desistir do pedido.
  static const Duration maxWait = Duration(seconds: 150);

  final Set<String> _busy = {};
  final Map<String, DateTime> _restUntil = {};
  final List<Completer<void>> _waiting = [];

  /// Regras do app em todo pedido de plugin.
  static const String appRules =
      'You work inside WaxClub, a vinyl record companion app. Follow the task exactly. '
      'Never produce hateful, sexual, violent or otherwise harmful content beyond what the source text itself contains. '
      'Do not add facts you are not sure about. Answer only with what the task asks for, with no preamble.';

  /// Chips em uso agora (para testes e diagnóstico).
  Set<String> get busyChips => Set.unmodifiable(_busy);

  void _wake() {
    for (final c in List.of(_waiting)) {
      if (!c.isCompleted) c.complete();
    }
    _waiting.clear();
  }

  /// Envia o pedido ([system] + [user]) e devolve o texto da resposta.
  Future<String> complete({required String system, required String user, int maxTokens = 2048}) async {
    await brain.load();
    final tries = <String, int>{};
    final given = <String>{}; // chips que já não servem para este pedido
    final deadline = DateTime.now().add(maxWait);
    var anyCandidate = false;
    while (true) {
      final candidates = [
        for (final p in brain.plugged)
          if (p.status != BrainKeyStatus.invalid && p.chip != null && !given.contains(p.id)) p,
      ];
      if (candidates.isEmpty) throw BrainAiException(anyCandidate ? 'all_failed' : 'no_chip');
      anyCandidate = true;
      final now = DateTime.now();
      bool resting(PluggedChip p) => _restUntil[p.id]?.isAfter(now) ?? false;
      final free = candidates.where((p) => !_busy.contains(p.id) && !resting(p)).toList();
      if (free.isEmpty) {
        if (now.isAfter(deadline)) throw const BrainAiException('all_failed');
        // Todos ocupados ou descansando: espera um liberar (ou o descanso mais curto acabar)
        final restEnds = [for (final p in candidates) if (resting(p)) _restUntil[p.id]!];
        restEnds.sort();
        final wait = restEnds.isEmpty ? const Duration(seconds: 5) : restEnds.first.difference(now);
        final c = Completer<void>();
        _waiting.add(c);
        await Future.any([c.future, Future<void>.delayed(wait.isNegative ? Duration.zero : wait)]);
        _waiting.remove(c);
        continue;
      }
      final p = free.first;
      final chip = p.chip!;
      _busy.add(p.id);
      try {
        final res = await _send(chip, p.key, p.modelInUse, '$appRules\n\n$system', user, maxTokens);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final text = extractText(chip.api, jsonDecode(utf8.decode(res.bodyBytes)));
          if (text != null && text.trim().isNotEmpty) {
            _restUntil.remove(p.id);
            if (p.status != BrainKeyStatus.ok) unawaited(brain.markStatus(p.id, BrainKeyStatus.ok));
            return text.trim();
          }
          given.add(p.id); // resposta vazia (ex.: bloqueio de conteúdo): outro chip
          continue;
        }
        final code = res.statusCode;
        final n = tries[p.id] = (tries[p.id] ?? 0) + 1;
        debugPrint('[BrainAi] ${chip.id} (${p.modelInUse}) respondeu $code (tentativa $n).');
        if (code == 401 || code == 403) {
          await brain.markStatus(p.id, BrainKeyStatus.invalid); // chave recusada
          given.add(p.id);
        } else if (code == 404) {
          // Modelo aposentado/inexistente: escolhe outro pela lista do provedor e tenta de novo
          final before = p.modelInUse;
          final now2 = await brain.refreshModel(p.id);
          if (now2 == null || now2 == before || n >= triesPerChip) given.add(p.id);
        } else if (code == 429 || code == 402 || code >= 500) {
          // Limite ou sobrecarga: o chip descansa e o pedido vai para o próximo (ou espera, se for o único)
          final after = int.tryParse(res.headers['retry-after'] ?? '');
          _restUntil[p.id] = DateTime.now().add(after != null && after <= 90 ? Duration(seconds: after) : retryWait);
          if (n >= triesPerChip) {
            if (code == 429 || code == 402) unawaited(brain.markStatus(p.id, BrainKeyStatus.limit));
            given.add(p.id);
          }
        } else {
          given.add(p.id); // 400 e afins: este pedido não serve para este chip (a chave continua valendo)
        }
      } catch (e) {
        debugPrint('[BrainAi] ${chip.id} sem resposta ($e).');
        final n = tries[p.id] = (tries[p.id] ?? 0) + 1;
        _restUntil[p.id] = DateTime.now().add(retryWait);
        if (n >= triesPerChip) given.add(p.id);
      } finally {
        _busy.remove(p.id);
        _wake();
      }
    }
  }

  Future<http.Response> _send(BrainChip chip, String key, String model, String system, String user, int maxTokens) {
    const timeout = Duration(seconds: 60);
    switch (chip.api) {
      case BrainApi.gemini:
        return _client
            .post(
              Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key'),
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
                'model': model,
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
                'model': model,
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
