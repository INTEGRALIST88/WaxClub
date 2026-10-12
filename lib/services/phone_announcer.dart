import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../app_info.dart';

/// Anuncia o celular na rede local via mDNS/DNS-SD como [serviceType], para os apps de TV
/// (ex.: o receptor do Fire TV) encontrarem sozinhos o servidor da página da TV e o WebSocket.
///
/// O anúncio é feito pelo NsdManager do Android (canal [channelName], em MainActivity.kt).
/// Registros TXT: fn = nome amigável, md = modelo, v = versão do protocolo, app/ver = app e versão,
/// path = página da TV, ws = caminho do WebSocket.
class PhoneAnnouncer {
  static const String serviceType = '_waxclub._tcp';
  static const String channelName = 'com.waxclub.app/nsd';
  static const String protocolVersion = '1';

  final MethodChannel _channel;
  bool _announced = false;
  bool get isAnnounced => _announced;

  PhoneAnnouncer({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName);

  /// Registros TXT do anúncio.
  static Map<String, String> txtRecords() => {
        'v': protocolVersion,
        'app': 'waxclub',
        'ver': kAppVersion,
        'path': '/',
        'ws': '/cast',
      };

  /// Anuncia (ou reanuncia) o celular na [port] do servidor local. Falhas não interrompem o app.
  Future<void> announce({required int port}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('register', {
        'serviceType': serviceType,
        'serviceName': kAppName,
        'port': port,
        'attributes': txtRecords(),
      });
      _announced = ok ?? true;
      debugPrint('[PhoneAnnouncer] 📣 Celular anunciado na rede como $serviceType (porta $port).');
    } on MissingPluginException {
      // Fora do Android (testes, desktop): sem anúncio
    } catch (e) {
      debugPrint('[PhoneAnnouncer] Falha ao anunciar na rede: $e');
    }
  }

  /// Retira o anúncio da rede.
  Future<void> withdraw() async {
    if (!_announced) return;
    _announced = false;
    try {
      await _channel.invokeMethod<void>('unregister');
    } on MissingPluginException {
      // sem anúncio fora do Android
    } catch (e) {
      debugPrint('[PhoneAnnouncer] Falha ao retirar o anúncio: $e');
    }
  }
}
