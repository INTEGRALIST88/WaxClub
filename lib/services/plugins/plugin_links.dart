import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Links de instalação de plugins vindos do navegador do celular (o botão "Install" no site):
/// * `waxclub://plugin/install?id=lyrics.netease` (o botão do site, pelo link de app do Android);
/// * `https://waxclub.com.br/install/?plugin=lyrics.netease` (link para compartilhar).
///
/// O link chega mesmo antes do login: fica guardado em [pending] até a conta estar pronta, e a tela
/// principal instala o plugin. Canal nativo em `MainActivity.kt` (`com.waxclub.app/links`).
class PluginLinks {
  PluginLinks._();
  static final PluginLinks instance = PluginLinks._();

  static const MethodChannel _channel = MethodChannel('com.waxclub.app/links');

  /// Plugin pedido pelo link e ainda não instalado.
  final ValueNotifier<String?> pending = ValueNotifier<String?>(null);

  bool _started = false;

  /// Lê o link que abriu o app e passa a ouvir os próximos. Pode ser chamado mais de uma vez.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') handle(call.arguments as String?); // l10n-ignore
    });
    try {
      handle(await _channel.invokeMethod<String>('initialLink')); // l10n-ignore
    } on MissingPluginException {
      // testes / plataformas sem o canal
    } catch (e) {
      debugPrint('[PluginLinks] Link inicial indisponível: $e');
    }
  }

  /// Guarda o plugin pedido por [link], se for um link de instalação válido.
  void handle(String? link) {
    final id = pluginIdFrom(link);
    if (id != null) pending.value = id;
  }

  /// Entrega o plugin pendente (uma vez só).
  String? take() {
    final id = pending.value;
    pending.value = null;
    return id;
  }

  /// Abre uma página no navegador (ex.: a página de plugins do site).
  Future<void> openUrl(String url) async {
    try {
      await _channel.invokeMethod<bool>('openUrl', {'url': url}); // l10n-ignore
    } catch (e) {
      debugPrint('[PluginLinks] Não abriu $url: $e');
    }
  }

  /// Plugin S5: abre o seletor de arquivos do Android (celular, cartão, Google Drive) para escolher
  /// letras .lrc; devolve nome e texto de cada arquivo (vazio se cancelar).
  Future<List<({String name, String content})>> pickLyricsFiles() async {
    try {
      final list = await _channel.invokeListMethod<Map<dynamic, dynamic>>('pickLyricsFiles'); // l10n-ignore
      return [
        for (final m in list ?? const <Map<dynamic, dynamic>>[])
          (name: '${m['name'] ?? ''}', content: '${m['content'] ?? ''}'), // l10n-ignore
      ];
    } catch (e) {
      debugPrint('[PluginLinks] Seletor de arquivos indisponível: $e');
      return const [];
    }
  }

  /// Id do plugin num link de instalação, ou nulo.
  static String? pluginIdFrom(String? link) {
    if (link == null || link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    final String? id;
    if (uri.scheme == 'waxclub' && uri.host == 'plugin') { // l10n-ignore
      id = uri.queryParameters['id'];
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') && // l10n-ignore
        (uri.host == 'waxclub.com.br' || uri.host == 'www.waxclub.com.br') && // l10n-ignore
        uri.path.startsWith('/install')) {
      id = uri.queryParameters['plugin'] ?? uri.queryParameters['id'];
    } else {
      id = null;
    }
    if (id == null || !RegExp(r'^[a-z0-9]+(\.[a-z0-9]+)+$').hasMatch(id)) return null;
    return id;
  }
}
