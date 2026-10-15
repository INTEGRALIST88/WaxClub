import 'package:flutter/material.dart';

/// Resultado do teste de uma chave de IA.
enum BrainKeyStatus {
  /// Chave aceita pelo provedor.
  ok,

  /// Chave recusada (apagada, errada ou sem permissão).
  invalid,

  /// Limite de uso atingido (grátis do dia ou crédito acabou); volta a funcionar depois.
  limit,

  /// Sem internet ou provedor fora do ar: não deu para testar.
  offline;

  static BrainKeyStatus parse(String? s) =>
      BrainKeyStatus.values.firstWhere((v) => v.name == s, orElse: () => BrainKeyStatus.ok);
}

/// Um chip do WaxBrain: um provedor de IA cuja chave (API key) o usuário encaixa (modelo BYOK).
/// Nenhum vem encaixado de fábrica.
class BrainChip {
  /// Identificador estável (banco de dados, cofre do celular): gemini, groq, openrouter...
  final String id;

  /// Nome do provedor como aparece no chip.
  final String name;

  /// Empresa / produto, linha de baixo do chip.
  final String vendor;

  /// Tem uso gratuito da API, sem cartão.
  final bool free;

  /// Página onde o usuário cria e copia a chave (aberta no navegador do celular).
  final String keyPageUrl;

  /// Formato da chave, para reconhecê-la na área de transferência.
  final RegExp keyPattern;

  /// Formato genérico demais para adivinhar o provedor sozinho (só vale com o chip escolhido).
  final bool ambiguousPattern;

  /// Cor do chip aceso.
  final Color color;

  /// Teste gratuito da chave: endereço e cabeçalhos (não gasta cota de IA).
  final Uri Function(String key) checkUrl;
  final Map<String, String> Function(String key) checkHeaders;

  const BrainChip({
    required this.id,
    required this.name,
    required this.vendor,
    required this.free,
    required this.keyPageUrl,
    required this.keyPattern,
    this.ambiguousPattern = false,
    required this.color,
    required this.checkUrl,
    required this.checkHeaders,
  });

  /// A chave tem o formato deste provedor.
  bool matches(String key) => keyPattern.hasMatch(key);

  /// Final da chave para mostrar sem expô-la ("…a1b2").
  static String hintOf(String key) => key.length <= 4 ? key : key.substring(key.length - 4);

  static Map<String, String> _bearer(String key) => {'Authorization': 'Bearer $key'};

  /// Todos os chips, grátis primeiro. Endereços e formatos conferidos em out/2026; os provedores mudam,
  /// então a validação pela chamada de teste é o que vale.
  static final List<BrainChip> all = [
    BrainChip(
      id: 'gemini',
      name: 'Gemini',
      vendor: 'Google AI Studio',
      free: true,
      keyPageUrl: 'https://aistudio.google.com/apikey',
      keyPattern: RegExp(r'^AIza[0-9A-Za-z_\-]{35}$'),
      color: const Color(0xFF8AB4F8),
      checkUrl: (k) => Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=1&key=$k'),
      checkHeaders: (_) => const {},
    ),
    BrainChip(
      id: 'groq',
      name: 'Groq',
      vendor: 'GroqCloud',
      free: true,
      keyPageUrl: 'https://console.groq.com/keys',
      keyPattern: RegExp(r'^gsk_[A-Za-z0-9]{20,}$'),
      color: const Color(0xFFF55036),
      checkUrl: (_) => Uri.parse('https://api.groq.com/openai/v1/models'),
      checkHeaders: _bearer,
    ),
    BrainChip(
      id: 'openrouter',
      name: 'OpenRouter',
      vendor: 'OpenRouter',
      free: true,
      keyPageUrl: 'https://openrouter.ai/settings/keys',
      keyPattern: RegExp(r'^sk-or-v1-[A-Za-z0-9]{20,}$'),
      color: const Color(0xFF7C7FF5),
      checkUrl: (_) => Uri.parse('https://openrouter.ai/api/v1/key'),
      checkHeaders: _bearer,
    ),
    BrainChip(
      id: 'mistral',
      name: 'Mistral',
      vendor: 'Mistral AI',
      free: true,
      keyPageUrl: 'https://console.mistral.ai/api-keys',
      keyPattern: RegExp(r'^[A-Za-z0-9]{32}$'),
      ambiguousPattern: true,
      color: const Color(0xFFFF8A00),
      checkUrl: (_) => Uri.parse('https://api.mistral.ai/v1/models'),
      checkHeaders: _bearer,
    ),
    BrainChip(
      id: 'openai',
      name: 'ChatGPT',
      vendor: 'OpenAI API',
      free: false,
      keyPageUrl: 'https://platform.openai.com/api-keys',
      keyPattern: RegExp(r'^sk-(?!ant-|or-)[A-Za-z0-9_\-]{20,}$'),
      color: const Color(0xFF10A37F),
      checkUrl: (_) => Uri.parse('https://api.openai.com/v1/models'),
      checkHeaders: _bearer,
    ),
    BrainChip(
      id: 'anthropic',
      name: 'Claude',
      vendor: 'Anthropic API',
      free: false,
      keyPageUrl: 'https://console.anthropic.com/settings/keys',
      keyPattern: RegExp(r'^sk-ant-[A-Za-z0-9_\-]{20,}$'),
      color: const Color(0xFFD97757),
      checkUrl: (_) => Uri.parse('https://api.anthropic.com/v1/models?limit=1'),
      checkHeaders: (k) => {'x-api-key': k, 'anthropic-version': '2023-06-01'},
    ),
    BrainChip(
      id: 'xai',
      name: 'Grok',
      vendor: 'xAI API',
      free: false,
      keyPageUrl: 'https://console.x.ai',
      keyPattern: RegExp(r'^xai-[A-Za-z0-9]{20,}$'),
      color: const Color(0xFFD0D0D0),
      checkUrl: (_) => Uri.parse('https://api.x.ai/v1/models'),
      checkHeaders: _bearer,
    ),
  ];

  static BrainChip? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Reconhece uma chave copiada. Com [expected], só aceita o formato daquele chip (necessário para os de
  /// formato genérico, como o Mistral); sem ele, adivinha o provedor pelos formatos inconfundíveis.
  static ({BrainChip chip, String key})? detect(String? text, {BrainChip? expected}) {
    final key = (text ?? '').trim();
    if (key.isEmpty || key.length > 300 || key.contains(RegExp(r'\s'))) return null;
    if (expected != null) return expected.matches(key) ? (chip: expected, key: key) : null;
    for (final c in all) {
      if (!c.ambiguousPattern && c.matches(key)) return (chip: c, key: key);
    }
    return null;
  }
}
