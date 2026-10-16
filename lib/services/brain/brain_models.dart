import 'dart:convert';
import 'brain_chips.dart';

/// Escolha do modelo de cada chip a partir da lista que o próprio provedor devolve. Os provedores aposentam
/// modelos o tempo todo (ex.: Llama 3.3 no Groq e no OpenRouter grátis em 2026); um nome fixo no app quebra
/// o chip. Com a lista, o app escolhe o melhor modelo disponível pela ordem de preferência abaixo.
class BrainModels {
  BrainModels._();

  /// Endereço da lista de modelos de cada provedor.
  static Uri listUrl(BrainChip chip, String key) {
    switch (chip.api) {
      case BrainApi.gemini:
        return Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=200&key=$key');
      case BrainApi.anthropic:
        return Uri.parse('https://api.anthropic.com/v1/models?limit=100');
      case BrainApi.openAiCompatible:
        return Uri.parse('${chip.chatBase}/models');
    }
  }

  /// Preferências por chip (pedaços do nome, do melhor para o pior) e o que nunca serve para texto.
  static const Map<String, List<String>> _prefer = {
    'gemini': ['flash-lite-latest', 'flash-latest', 'flash-lite', 'flash'],
    'groq': ['gpt-oss-120b', 'gpt-oss-20b', 'qwen', 'llama', 'kimi', 'gemma'],
    'openrouter': ['gemma', 'llama', 'qwen', 'deepseek', 'mistral', 'nemotron', 'glm', 'gpt-oss'],
    'mistral': ['mistral-small-latest', 'mistral-medium-latest', 'mistral-small', 'mistral-medium', 'mistral-large'],
    'openai': ['gpt-4o-mini', 'gpt-4.1-mini', 'gpt-5-mini', 'mini'],
    'anthropic': ['haiku', 'sonnet'],
    'xai': ['grok-3-mini', 'mini', 'grok'],
    'deepseek': ['v4-flash', 'flash', 'chat', 'v4'],
  };

  static const List<String> _avoid = [
    'embed', 'tts', 'whisper', 'audio', 'image', 'vision-only', 'guard', 'moderation', 'transcribe', 'realtime',
    'search', 'live', 'native-audio', 'computer-use', 'robotics', 'aqa', 'imagen', 'veo', 'compound', 'codestral',
    'ocr', 'dall-e', 'babbage', 'davinci', 'thinking', 'reasoner',
  ];

  /// Ids de modelo de texto na resposta da lista (formatos do Gemini, Anthropic e OpenAI).
  static List<String> parse(BrainChip chip, String body) {
    try {
      final j = jsonDecode(body);
      if (chip.api == BrainApi.gemini) {
        return [
          for (final m in (j['models'] as List<dynamic>? ?? const []))
            if (m is Map<String, dynamic> &&
                ((m['supportedGenerationMethods'] as List<dynamic>?) ?? const []).contains('generateContent'))
              '${m['name']}'.replaceFirst('models/', ''),
        ];
      }
      final out = <String>[];
      for (final m in (j['data'] as List<dynamic>? ?? const [])) {
        if (m is! Map<String, dynamic>) continue;
        final id = '${m['id'] ?? ''}';
        if (id.isEmpty) continue;
        // OpenRouter: só os grátis (o WaxBrain usa as cotas gratuitas de cada um)
        if (chip.id == 'openrouter') {
          final p = m['pricing'];
          final free = id.endsWith(':free') ||
              (p is Map && '${p['prompt']}' == '0' && '${p['completion']}' == '0');
          if (!free) continue;
        }
        out.add(id);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Melhor modelo da lista para o chip (nulo se nenhum servir). O modelo atual fica se ainda existir.
  static String? pick(BrainChip chip, List<String> ids, {String? current}) {
    final usable = [
      for (final id in ids)
        if (!_avoid.any((a) => id.toLowerCase().contains(a))) id,
    ];
    if (usable.isEmpty) return null;
    if (current != null && usable.contains(current)) return current;
    if (usable.contains(chip.model)) return chip.model;
    for (final pref in _prefer[chip.id] ?? const <String>[]) {
      // entre os que batem, o de nome mais curto costuma ser o "principal" (sem data/variante)
      final hits = usable.where((id) => id.toLowerCase().contains(pref)).toList()
        ..sort((a, b) {
          final pa = a.contains('preview') || a.contains('exp') ? 1 : 0;
          final pb = b.contains('preview') || b.contains('exp') ? 1 : 0;
          return pa != pb ? pa - pb : a.length - b.length;
        });
      if (hits.isNotEmpty) return hits.first;
    }
    return usable.first;
  }
}
