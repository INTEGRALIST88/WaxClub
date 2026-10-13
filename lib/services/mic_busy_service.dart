import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Estado do microfone durante uma captura do WaxClub.
class MicStatus {
  /// O Android está silenciando a captura do WaxClub (Android 10+).
  final bool silenced;

  /// Capturas ativas no aparelho, incluindo a do WaxClub.
  final int recordings;

  const MicStatus({required this.silenced, required this.recordings});

  /// Outros apps gravando ao mesmo tempo que o WaxClub.
  int get otherRecordings => recordings > 1 ? recordings - 1 : 0;

  /// O microfone está bloqueado por outro app: o sistema silenciou o WaxClub, ou outro app está
  /// gravando e o áudio capturado veio praticamente mudo ([peakDb] em dBFS).
  bool blocksCapture(double? peakDb) {
    if (silenced) return true;
    return otherRecordings > 0 && peakDb != null && peakDb < blockedPeakDb;
  }

  /// Pico abaixo disso é silêncio digital (o Android entrega zeros quando corta a captura).
  static const double blockedPeakDb = -80.0;
}

/// Consulta ao Android se outro app (acessibilidade, assistente de voz, chamada) está ocupando o microfone.
/// O Android não deixa o WaxClub tomar o microfone de volta; o app só pode avisar o usuário.
class MicBusyService {
  static const MethodChannel _channel = MethodChannel('com.waxclub.app/mic');

  const MicBusyService();

  /// Estado atual; nulo fora do Android ou se a consulta falhar.
  Future<MicStatus?> check() async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('status');
      if (r == null) return null;
      return MicStatus(
        silenced: r['silenced'] == true,
        recordings: (r['recordings'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('[MicBusyService] Estado do microfone indisponível: $e');
      return null;
    }
  }
}
