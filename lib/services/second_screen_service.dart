import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Segunda tela pelo Smart View / Miracast (Android Presentation, SecondScreenController.kt).
///
/// Quando o usuário espelha o celular numa TV (Smart View da Samsung, "Transmitir"/Miracast em outros
/// celulares), o Android cria uma tela de apresentação. O WaxClub mostra nela só a letra (a mesma página
/// da TV, servida pelo celular) e o celular vira o painel de controle. Não usa o navegador da TV nem app
/// instalado na TV.
class SecondScreenService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.waxclub.app/second_screen');

  /// Garante o servidor local da página da TV antes de abrir a segunda tela.
  Future<void> Function()? ensureServer;

  bool _available = false;
  bool _showing = false;
  String? _name;
  bool _dismissedByUser = false;
  bool _initialized = false;

  /// Há uma TV espelhada (tela de apresentação) disponível.
  bool get isAvailable => _available;

  /// A letra está sendo mostrada na TV espelhada.
  bool get isShowing => _showing;

  /// Nome da tela (ex.: "Samsung TV", "Smart View").
  String? get displayName => _name;

  /// Começa a acompanhar as telas (chamado na abertura do app).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'state') _apply(call.arguments);
        return null;
      });
      _apply(await _channel.invokeMethod<Object?>('state'));
    } on MissingPluginException {
      // fora do Android
    } catch (e) {
      debugPrint('[SecondScreen] Indisponível: $e');
    }
  }

  @visibleForTesting
  void applyStateForTesting(Object? state) => _apply(state);

  void _apply(Object? raw) {
    if (raw is! Map) return;
    final wasAvailable = _available;
    _available = raw['available'] == true;
    _showing = raw['showing'] == true;
    _name = raw['name'] as String?;
    // Espelhamento encerrado: na próxima vez a letra volta a abrir sozinha
    if (!_available) _dismissedByUser = false;
    notifyListeners();
    // Acabou de espelhar: mostra a letra na TV automaticamente (o usuário pediu a TV ao espelhar)
    if (_available && !wasAvailable && !_showing && !_dismissedByUser) {
      show();
    }
  }

  /// Mostra a letra na TV espelhada. Retorna `false` sem TV espelhada.
  Future<bool> show() async {
    try {
      await ensureServer?.call();
      final name = Uri.encodeQueryComponent(_name ?? 'Smart View');
      final ok = await _channel.invokeMethod<bool>('show', {'url': 'http://127.0.0.1:8088/?name=$name'}) ?? false;
      if (ok) _dismissedByUser = false;
      return ok;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('[SecondScreen] Falha ao mostrar: $e');
      return false;
    }
  }

  /// Tira a letra da TV. [byUser]: não reabre sozinha até o próximo espelhamento.
  Future<void> hide({bool byUser = false}) async {
    if (byUser) _dismissedByUser = true;
    try {
      await _channel.invokeMethod<void>('hide');
    } on MissingPluginException {
      // fora do Android
    } catch (e) {
      debugPrint('[SecondScreen] Falha ao esconder: $e');
    }
  }

  /// Abre a tela do sistema para espelhar (Smart View / Transmitir / Miracast).
  Future<bool> openCastSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openCastSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
