import 'dart:async';

/// Representa um dispositivo receptor de transmissão encontrado na rede local.
class CastDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final bool isChromecast;
  final String? model;
  final bool isAudioOnly;
  final bool isStandBy;
  final DateTime? lastSeen;

  const CastDevice({
    required this.id,
    required this.name,
    required this.host,
    this.port = 8088,
    this.isChromecast = false,
    this.model,
    this.isAudioOnly = false,
    this.isStandBy = false,
    this.lastSeen,
  });

  CastDevice copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    bool? isChromecast,
    String? model,
    bool? isAudioOnly,
    bool? isStandBy,
    DateTime? lastSeen,
  }) {
    return CastDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      isChromecast: isChromecast ?? this.isChromecast,
      model: model ?? this.model,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      isStandBy: isStandBy ?? this.isStandBy,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  String toString() => '$name ($host:$port)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastDevice &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => host.hashCode ^ port.hashCode;
}

/// Registro e cache de dispositivos Cast com suporte a TTL (120s),
/// ordenação estável e stream reativo de mudanças.
class CastDeviceRegistry {
  final Duration ttl;
  final DateTime Function() _clock;
  final Map<String, CastDevice> _devices = {};
  final StreamController<List<CastDevice>> _streamController =
      StreamController<List<CastDevice>>.broadcast();

  CastDeviceRegistry({
    this.ttl = const Duration(seconds: 120),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Stream reativo emitindo a lista consolidada sempre que há adição ou expiração.
  Stream<List<CastDevice>> get devicesStream => _streamController.stream;

  /// Retorna lista imutável e ordenada dos dispositivos válidos.
  List<CastDevice> get devices => getDevices();

  /// Insere ou atualiza um dispositivo no registro.
  void upsert(CastDevice device) {
    final now = _clock();
    final key = '${device.host}:${device.port}';
    final existing = _devices[key];

    final updated = device.copyWith(
      lastSeen: now,
      model: device.model ?? existing?.model,
      isStandBy: device.isStandBy,
      // Uma vez identificado como só-áudio (ex.: pelo TXT "ca" do mDNS), uma sondagem posterior
      // sem essa informação (varredura /24) não pode reclassificá-lo como TV.
      isAudioOnly: device.isAudioOnly || (existing?.isAudioOnly ?? false),
      name: (device.name.isNotEmpty && !device.name.startsWith('TV ('))
          ? device.name
          : (existing?.name ?? device.name),
    );

    _devices[key] = updated;
    _cleanExpiredInternal(now);
    _notify();
  }

  /// Limpa dispositivos cuja última visualização excedeu o TTL.
  int cleanExpired([DateTime? customNow]) {
    final now = customNow ?? _clock();
    final removed = _cleanExpiredInternal(now);
    if (removed > 0) {
      _notify();
    }
    return removed;
  }

  int _cleanExpiredInternal(DateTime now) {
    final expiredKeys = <String>[];
    for (final entry in _devices.entries) {
      final seen = entry.value.lastSeen ?? now;
      if (now.difference(seen) > ttl) {
        expiredKeys.add(entry.key);
      }
    }
    for (final k in expiredKeys) {
      _devices.remove(k);
    }
    return expiredKeys.length;
  }

  /// Retorna os dispositivos ordenados:
  /// 1. TVs (não audio-only) primeiro;
  /// 2. Caixas de som / som acústico depois;
  /// 3. Em caso de empate, por nome alfabético.
  List<CastDevice> getDevices([DateTime? customNow]) {
    final now = customNow ?? _clock();
    _cleanExpiredInternal(now);

    final list = _devices.values.toList();
    list.sort((a, b) {
      // TVs primeiro, audio-only depois
      if (!a.isAudioOnly && b.isAudioOnly) return -1;
      if (a.isAudioOnly && !b.isAudioOnly) return 1;

      // Ativos antes de Standby
      if (!a.isStandBy && b.isStandBy) return -1;
      if (a.isStandBy && !b.isStandBy) return 1;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(list);
  }

  /// Esvazia o registro.
  void clear() {
    _devices.clear();
    _notify();
  }

  void _notify() {
    if (!_streamController.isClosed) {
      _streamController.add(getDevices());
    }
  }

  /// Fecha recursos do controller.
  void dispose() {
    _streamController.close();
  }
}
