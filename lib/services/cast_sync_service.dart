import 'curiosities_service.dart';
import 'second_screen_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/lyric_line.dart';
import '../models/track_info.dart';
import 'cast_device_registry.dart';
import 'cast_frame_parser.dart';
import 'cast_v2_client.dart';
import 'phone_announcer.dart';
import 'tv_web_receiver_html.dart';

export 'cast_device_registry.dart' show CastDevice, CastDeviceRegistry;

/// Serviço de transmissão e recepção em tempo real de letras e sincronismo de vinil.
class CastSyncService extends ChangeNotifier {
  static const int defaultPort = 8088;

  /// Anúncio do celular na rede (_waxclub._tcp) enquanto o servidor da página da TV está no ar.
  /// Substituível nos testes.
  PhoneAnnouncer announcer = PhoneAnnouncer();

  /// Segunda tela do Smart View / Miracast (letra na TV, controles no celular).
  final SecondScreenService secondScreen = SecondScreenService();

  // ─── CLIENTE GOOGLE CAST V2 (CHROMECAST BUILT-IN NA PORTA 8009 TLS) ───
  final CastV2Client _castV2Client = CastV2Client();

  // ─── REGISTRO CENTRAL DE DISPOSITIVOS DESCOBERTOS ───
  final CastDeviceRegistry _registry = CastDeviceRegistry();

  // Lista dos últimos IPs bem-sucedidos para conexão rápida
  final List<String> _lastHosts = [];

  // ─── ESTADO DO TRANSMISSOR (CLIENTE / CELULAR) ───
  WebSocket? _clientSocket;
  CastDevice? _connectedDevice;
  bool _isConnecting = false;

  // ─── SERVIDOR WEB & WEBSOCKET LOCAL NO CELULAR ───
  HttpServer? _localServer;
  final List<WebSocket> _connectedClients = [];
  String? _localIp;
  bool _isClientConfirmed = false;
  String? _clientDeviceName;

  bool get isConnected => _clientSocket != null || _connectedClients.isNotEmpty || _castV2Client.isConnected;
  bool get isConnecting => _isConnecting;

  // ─── RECONEXÃO AUTOMÁTICA (queda não solicitada pelo usuário) ───
  static const List<int> reconnectDelaysSeconds = [2, 5, 10];
  String? _chromecastHost;
  String? _chromecastName;
  bool _isReconnecting = false;
  bool get isReconnecting => _isReconnecting;

  /// Transmissão ativa ou em reconexão: a interface do celular permanece no modo "TV" durante quedas curtas.
  bool get isCastActive => isConnected || _isReconnecting;
  bool get isClientConfirmed => _isClientConfirmed;
  String? get clientDeviceName => _clientDeviceName ?? _connectedDevice?.name;
  CastDevice? get connectedDevice => _connectedDevice;
  String? get localIp => _localIp;
  int get localPort => defaultPort;
  String get webReceiverUrl => 'http://${_localIp ?? "127.0.0.1"}:$defaultPort';
  int get connectedClientCount => _connectedClients.length;

  /// Erro detalhado da última tentativa de conexão Cast
  String? get lastCastError => _castV2Client.lastError;

  /// Etapa atual da conexão com a TV
  String get castStatusStep => _castV2Client.statusStep;

  // Callback chamado quando a tela cliente confirma o handshake
  void Function(String deviceName)? onClientScreenConfirmed;

  // ─── DESCOBERTA AUTOMÁTICA EM BACKGROUND E SINGLE-FLIGHT ───
  Timer? _discoveryTimer;
  StreamSubscription<List<CastDevice>>? _registrySub;
  Future<List<CastDevice>>? _activeDiscoveryFuture;
  bool _isScanning = false;

  bool get hasDiscoveredDevices => discoveredDevices.isNotEmpty;
  bool get isScanning => _isScanning;

  /// Somente telas (TVs, sticks, displays): caixas de som e grupos de áudio não exibem letras.
  List<CastDevice> get discoveredDevices =>
      _registry.devices.where((d) => !d.isAudioOnly).toList(growable: false);
  Stream<List<CastDevice>> get devicesStream => _registry.devicesStream;

  CastSyncService() {
    _castV2Client.onDisconnected = () {
      debugPrint('[CastSyncService] ⚠️ Desconexão remota da TV detectada pelo cliente CastV2.');
      final host = _chromecastHost;
      if (host != null && !_isDisposed) {
        unawaited(_reconnectChromecast(host));
      } else {
        disconnect();
      }
    };

    _registrySub = _registry.devicesStream.listen((_) {
      notifyListeners();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SERVIDOR WEB LOCAL (TRANSMISSÃO PARA NAVEGADOR DA TV SEM APPS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtém o endereço IPv4 local do smartphone na rede Wi-Fi real (ignorando P2P/VPN).
  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);

      bool isVirtualOrP2p(String ifName) {
        final n = ifName.toLowerCase();
        return n.contains('p2p') ||
            n.contains('dummy') ||
            n.contains('tun') ||
            n.contains('tap') ||
            n.contains('rmnet') ||
            n.contains('ccmni') ||
            n.contains('ppp') ||
            n.contains('docker');
      }

      // Prioridade 1: Interface Wi-Fi física real com IP de LAN residencial
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (isVirtualOrP2p(name)) continue;

        if (name.contains('wlan') || name.contains('wifi') || name.contains('en') || name.contains('eth')) {
          for (final addr in iface.addresses) {
            final ip = addr.address;
            if (!addr.isLoopback &&
                !ip.startsWith('127.') &&
                (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.'))) {
              _localIp = ip;
              return _localIp;
            }
          }
        }
      }

      // Prioridade 2: Qualquer interface não-P2P com IPv4 válido
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (isVirtualOrP2p(name)) continue;

        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (!addr.isLoopback && !ip.startsWith('127.')) {
            _localIp = ip;
            return _localIp;
          }
        }
      }
    } catch (e) {
      debugPrint('[CastSyncService] Erro ao obter IP local: $e');
    }
    return _localIp;
  }

  /// Inicia o Servidor Web local do smartphone para que a TV acesse via navegador.
  Future<String?> startLocalServer({int port = defaultPort}) async {
    if (_localServer != null) {
      if (_localIp == null) await getLocalIpAddress();
      return _localIp;
    }

    try {
      await getLocalIpAddress();
      _localServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('[CastSyncService] 🚀 Servidor Web WaxClub ativo em http://${_localIp ?? '0.0.0.0'}:${_localServer!.port}');
      // Apps de TV (ex.: Fire TV) encontram o celular sozinhos pelo anúncio _waxclub._tcp
      unawaited(announcer.announce(port: _localServer!.port));

      _localServer!.listen(
        (HttpRequest request) async {
          final path = request.uri.path;
          if ((path == '/cast' || path == '/tv-ws') && WebSocketTransformer.isUpgradeRequest(request)) {
            final ws = await WebSocketTransformer.upgrade(request);
            _handleClientScreenWebSocket(ws);
          } else if (path == '/' || path == '/tv') {
            request.response.headers.contentType = ContentType.html;
            request.response.write(TvWebReceiverHtml.build());
            await request.response.close();
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        },
        onError: (err) {
          debugPrint('[CastSyncService] Erro no servidor local: $err');
        },
      );

      notifyListeners();
      return _localIp;
    } catch (e) {
      debugPrint('[CastSyncService] Falha ao iniciar servidor local na porta $port: $e');
      return _localIp;
    }
  }

  void _handleClientScreenWebSocket(WebSocket ws) {
    _connectedClients.add(ws);
    debugPrint('[CastSyncService] 🔌 Tela cliente conectou via WebSocket! Total telas: ${_connectedClients.length}');

    ws.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final type = json['type'] as String?;

          if (type == 'client_ready') {
            final name = json['deviceName'] as String? ?? 'TV Sala (Navegador)';
            _isClientConfirmed = true;
            _clientDeviceName = name;
            debugPrint('[CastSyncService] 🎯 TELA CLIENTE CONFIRMADA: "$name"');

            // Envia confirmação (ACK) para a TV
            ws.add(jsonEncode({'type': 'server_ack', 'status': 'confirmed'}));

            onClientScreenConfirmed?.call(name);
            notifyListeners();
          }
        } catch (e) {
          debugPrint('[CastSyncService] Erro ao ler mensagem da tela cliente: $e');
        }
      },
      onError: (err) {
        debugPrint('[CastSyncService] Erro no WebSocket da tela cliente: $err');
        _connectedClients.remove(ws);
        if (_connectedClients.isEmpty && _clientSocket == null) {
          _isClientConfirmed = false;
          _clientDeviceName = null;
        }
        notifyListeners();
      },
      onDone: () {
        debugPrint('[CastSyncService] Tela cliente desconectada.');
        _connectedClients.remove(ws);
        if (_connectedClients.isEmpty && _clientSocket == null) {
          _isClientConfirmed = false;
          _clientDeviceName = null;
        }
        notifyListeners();
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESCOBERTA REAL GOOGLE CAST (mDNS) & REDE LOCAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Executa uma varredura silenciosa em background após iniciar o app.
  void runInitialBackgroundDiscovery() {
    startLocalServer();
    secondScreen.ensureServer = () async {
      await startLocalServer();
    };
    unawaited(secondScreen.init());

    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(const Duration(milliseconds: 2500), () async {
      if (isConnected) return;
      debugPrint('[CastSyncService] 🔍 Iniciando varredura mDNS de telas na rede...');
      await discoverDevices();
    });
  }

  Future<Set<String>> _getLocalIps() async {
    final ips = <String>{'127.0.0.1', 'localhost'};
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          ips.add(addr.address);
        }
      }
    } catch (_) {}
    return ips;
  }

  /// Busca receptores de Google Cast na rede de forma idempotente (Single-Flight).
  /// Se já houver uma busca em andamento, retorna a mesma operação sem duplicar varreduras.
  Future<List<CastDevice>> discoverDevices({bool forceSubnet = false}) {
    if (_activeDiscoveryFuture != null) {
      return _activeDiscoveryFuture!;
    }

    _activeDiscoveryFuture = _performDiscovery(forceSubnet: forceSubnet).whenComplete(() {
      _activeDiscoveryFuture = null;
    });

    return _activeDiscoveryFuture!;
  }

  Future<List<CastDevice>> _performDiscovery({bool forceSubnet = false}) async {
    _isScanning = true;
    notifyListeners();

    final localIps = await _getLocalIps();

    // 1. Testa os últimos hosts conhecidos primeiro (Reconexão Rápida T1.6)
    if (_lastHosts.isNotEmpty) {
      for (final host in List.of(_lastHosts)) {
        if (!localIps.contains(host)) {
          final dev = await _resolveCastDeviceInfo(host);
          if (dev != null) {
            _registry.upsert(dev);
          }
        }
      }
    }

    // 2. Descoberta via mDNS (_googlecast._tcp.local)
    MDnsClient? mdnsClient;
    try {
      mdnsClient = MDnsClient();
      await mdnsClient.start();

      final ptrQuery = ResourceRecordQuery.serverPointer('_googlecast._tcp.local');
      final ptrStream = mdnsClient.lookup<PtrResourceRecord>(ptrQuery).timeout(
        const Duration(seconds: 8),
        onTimeout: (sink) => sink.close(),
      );

      final processedDomains = <String>{};

      await for (final PtrResourceRecord ptr in ptrStream) {
        if (!processedDomains.add(ptr.domainName)) continue;

        String friendlyName = '';
        String rawModel = '';
        int? capabilities;
        String? targetHost;

        try {
          await for (final TxtResourceRecord txt in mdnsClient.lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(ptr.domainName),
          ).timeout(const Duration(milliseconds: 1500), onTimeout: (s) => s.close())) {
            final text = txt.text;
            for (final line in text.split('\n')) {
              if (line.startsWith('fn=')) {
                friendlyName = line.substring(3).trim();
              } else if (line.startsWith('md=')) {
                rawModel = line.substring(3).trim();
              } else if (line.startsWith('ca=')) {
                capabilities = int.tryParse(line.substring(3).trim());
              }
            }
          }
        } catch (_) {}

        // Classificação: se 'ca' existe e não tem o bit de vídeo (1), marca como áudio-only
        bool isAudioOnly = false;
        if (capabilities != null && (capabilities & 1) == 0) {
          isAudioOnly = true;
        }

        try {
          await for (final SrvResourceRecord srv in mdnsClient.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          ).timeout(const Duration(milliseconds: 1500), onTimeout: (s) => s.close())) {
            targetHost = srv.target;
            break;
          }
        } catch (_) {}

        if (targetHost != null) {
          try {
            await for (final IPAddressResourceRecord ip in mdnsClient.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(targetHost),
            ).timeout(const Duration(milliseconds: 1500), onTimeout: (s) => s.close())) {
              final hostIp = ip.address.address;
              if (!localIps.contains(hostIp)) {
                final verifiedDev = await _resolveCastDeviceInfo(
                  hostIp,
                  fallbackName: friendlyName.isNotEmpty ? friendlyName : null,
                  model: rawModel.isNotEmpty ? rawModel : null,
                  isAudioOnly: isAudioOnly,
                );
                if (verifiedDev != null) {
                  _registry.upsert(verifiedDev);
                  _rememberHost(verifiedDev.host);
                }
              }
            }
          } catch (_) {}
        }
      }
      // Apps WaxClub de TV (ex.: Fire TV): servidor WebSocket próprio anunciado na rede
      await _discoverTvApps(mdnsClient, localIps);
    } catch (e) {
      debugPrint('[CastSyncService] Aviso na busca mDNS: $e');
    } finally {
      mdnsClient?.stop();
    }

    // 3. Varredura de sub-rede /24 como reforço se mDNS achou 0 dispositivos ou forçada pelo usuário
    if (discoveredDevices.isEmpty || forceSubnet) {
      final myIp = _localIp ?? await getLocalIpAddress();
      if (myIp != null && myIp.contains('.')) {
        await _probeSubnetFull(myIp, localIps);
      }
    }

    _isScanning = false;
    notifyListeners();
    return discoveredDevices;
  }

  /// Varrer todos os 254 endereços da sub-rede /24 na porta 8009 com pool de concorrência.
  Future<void> _probeSubnetFull(String myIp, Set<String> localIps) async {
    final parts = myIp.split('.');
    if (parts.length != 4) return;
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';

    final myOctet = int.tryParse(parts[3]) ?? 100;
    final allOctets = List.generate(254, (i) => i + 1)..remove(myOctet);

    // Processa em lotes de até 35 conexões em paralelo
    const batchSize = 35;
    for (int i = 0; i < allOctets.length; i += batchSize) {
      final batch = allOctets.skip(i).take(batchSize);
      final futures = batch.map((oct) async {
        final ip = '$prefix$oct';
        if (localIps.contains(ip)) return;
        try {
          final s = await Socket.connect(ip, 8009, timeout: const Duration(milliseconds: 600));
          s.destroy();

          final dev = await _resolveCastDeviceInfo(ip);
          if (dev != null) {
            _registry.upsert(dev);
            _rememberHost(dev.host);
          }
        } catch (_) {}
      });
      await Future.wait(futures);
    }
  }

  /// Adiciona um IP digitado manualmente pelo usuário no diálogo de TVs: primeiro um Chromecast
  /// (porta 8009); se não houver, um app WaxClub de TV (servidor WebSocket na [tvAppPort]).
  Future<CastDevice?> addManualIp(String rawIp, {int tvAppPort = defaultPort}) async {
    final cleanIp = rawIp.trim();
    if (!RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(cleanIp)) {
      return null;
    }

    try {
      final s = await Socket.connect(cleanIp, 8009, timeout: const Duration(milliseconds: 1200));
      s.destroy();

      final dev = await _resolveCastDeviceInfo(cleanIp);
      if (dev != null) {
        _registry.upsert(dev);
        _rememberHost(dev.host);
        return dev;
      }
    } catch (_) {}

    // Sem Chromecast: app WaxClub de TV (ex.: Fire TV) com o servidor WebSocket no ar?
    try {
      final s = await Socket.connect(cleanIp, tvAppPort, timeout: const Duration(milliseconds: 1200));
      s.destroy();
      final dev = tvAppDevice(ip: cleanIp, port: tvAppPort);
      _registry.upsert(dev);
      return dev;
    } catch (_) {}
    return null;
  }

  /// Tipos de serviço anunciados pelos apps WaxClub de TV (o nome antigo fica até o app da TV ser renomeado).
  static const List<String> tvAppServiceTypes = ['_waxclub-tv._tcp.local', '_vinylyric._tcp.local'];

  /// Aparelho de um app WaxClub de TV, a partir do anúncio na rede (TXT "fn=nome", "md=modelo").
  /// Não é Chromecast: a conexão é pelo WebSocket do próprio app ([connectToHost]).
  static CastDevice tvAppDevice({required String ip, required int port, String? txt}) {
    String? name;
    String? model;
    for (final line in (txt ?? '').split('\n')) {
      if (line.startsWith('fn=')) name = line.substring(3).trim();
      if (line.startsWith('md=')) model = line.substring(3).trim();
    }
    return CastDevice(
      id: 'tvapp:$ip:$port',
      name: (name != null && name.isNotEmpty) ? name : 'WaxClub TV ($ip)',
      host: ip,
      port: port,
      isChromecast: false,
      model: (model != null && model.isNotEmpty) ? 'WaxClub TV app · $model' : 'WaxClub TV app',
      lastSeen: DateTime.now(),
    );
  }

  /// Procura na rede os apps WaxClub de TV ([tvAppServiceTypes]) e os registra na lista de aparelhos.
  Future<void> _discoverTvApps(MDnsClient mdnsClient, Set<String> localIps) async {
    for (final serviceType in tvAppServiceTypes) {
      final processed = <String>{};
      try {
        await for (final PtrResourceRecord ptr in mdnsClient
            .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(serviceType))
            .timeout(const Duration(seconds: 3), onTimeout: (sink) => sink.close())) {
          if (!processed.add(ptr.domainName)) continue;

          String txt = '';
          try {
            await for (final TxtResourceRecord t in mdnsClient
                .lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))
                .timeout(const Duration(milliseconds: 1500), onTimeout: (s) => s.close())) {
              txt = t.text;
              break;
            }
          } catch (_) {}

          String? target;
          int? port;
          try {
            await for (final SrvResourceRecord srv in mdnsClient
                .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
                .timeout(const Duration(milliseconds: 1500), onTimeout: (s) => s.close())) {
              target = srv.target;
              port = srv.port;
              break;
            }
          } catch (_) {}
          if (target == null || port == null) continue;

          try {
            await for (final IPAddressResourceRecord ip in mdnsClient
                .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(target))
                .timeout(const Duration(milliseconds: 1500), onTimeout: (s) => s.close())) {
              final hostIp = ip.address.address;
              if (localIps.contains(hostIp)) break;
              final dev = tvAppDevice(ip: hostIp, port: port, txt: txt);
              debugPrint('[CastSyncService] 📺 App de TV encontrado: ${dev.name} ($hostIp:$port, $serviceType)');
              _registry.upsert(dev);
              break;
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[CastSyncService] Aviso na busca de apps de TV ($serviceType): $e');
      }
    }
  }

  /// Consulta metadados oficiais via Eureka (8008) e status CastV2 estruturado com CastFrameParser (8009).
  Future<CastDevice?> _resolveCastDeviceInfo(
    String ip, {
    String? fallbackName,
    String? model,
    bool isAudioOnly = false,
  }) async {
    String friendlyName = fallbackName ?? 'TV ($ip)';
    String? resolvedModel = model;
    bool detectedAudio = isAudioOnly;
    bool isStandBy = false;
    bool isReachable = false;

    // 1. Verificação HTTP Eureka (porta 8008)
    final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 900);
    try {
      final request = await client.getUrl(Uri.parse('http://$ip:8008/setup/eureka_info'));
      final response = await request.close().timeout(const Duration(milliseconds: 900));

      if (response.statusCode == 200) {
        isReachable = true;
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final rawName = json['name'] as String?;
        if (rawName != null && rawName.isNotEmpty) {
          friendlyName = rawName;
        }
        final rawModelName = json['model_name'] as String?;
        if (rawModelName != null && rawModelName.isNotEmpty) {
          resolvedModel ??= rawModelName;
        }
        if (json.containsKey('noise_level')) {
          detectedAudio = true;
        }
        // Capacidade oficial de tela, quando o firmware a informa
        final caps = (json['device_info'] as Map<String, dynamic>?)?['capabilities'] as Map<String, dynamic>?;
        if (caps != null && caps['display_supported'] == false) {
          detectedAudio = true;
        }
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }

    // 2. Verificação de status via CastV2 TLS na porta 8009 usando CastFrameParser
    try {
      final socket = await SecureSocket.connect(
        ip,
        8009,
        onBadCertificate: (_) => true,
        timeout: const Duration(milliseconds: 1200),
      );
      isReachable = true;

      final parser = CastFrameParser();
      final statusCompleter = Completer<Map<String, dynamic>?>();

      final sub = socket.listen(
        (data) {
          try {
            final messages = parser.add(data);
            for (final msg in messages) {
              if (msg.namespace == CastV2Client.nsReceiver) {
                final json = jsonDecode(msg.payloadUtf8);
                if (json is Map<String, dynamic> && json['type'] == 'RECEIVER_STATUS') {
                  if (!statusCompleter.isCompleted) {
                    statusCompleter.complete(json);
                  }
                  break;
                }
              }
            }
          } catch (_) {}
        },
        onError: (_) {
          if (!statusCompleter.isCompleted) statusCompleter.complete(null);
        },
        onDone: () {
          if (!statusCompleter.isCompleted) statusCompleter.complete(null);
        },
      );

      // Envia CONNECT e GET_STATUS
      final msgConnect = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: CastV2Client.nsConnection,
        payloadUtf8: jsonEncode({'type': 'CONNECT'}),
      );
      socket.add(msgConnect.toProtobufBytes());

      final msgStatus = CastMessage(
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: CastV2Client.nsReceiver,
        payloadUtf8: jsonEncode({'type': 'GET_STATUS', 'requestId': 1}),
      );
      socket.add(msgStatus.toProtobufBytes());

      final statusJson = await statusCompleter.future.timeout(
        const Duration(milliseconds: 1400),
        onTimeout: () => null,
      );

      await sub.cancel();
      await socket.close();

      if (statusJson != null) {
        final status = statusJson['status'] as Map<String, dynamic>?;
        if (status != null) {
          final userEq = status['userEq'] as Map<String, dynamic>?;
          if (userEq != null && (userEq.containsKey('high_shelf') || userEq.containsKey('low_shelf'))) {
            detectedAudio = true;
          }
          if (status['isStandBy'] == true) {
            isStandBy = true;
          }
        }
      }
    } catch (_) {}

    // Nem Eureka (8008) nem CastV2 (8009) responderam: dispositivo offline ou inexistente
    if (!isReachable) return null;

    if (isAudioOnlyModel(resolvedModel) || isAudioOnlyModel(friendlyName)) {
      detectedAudio = true;
    }

    return CastDevice(
      id: '$ip:8009',
      name: friendlyName,
      host: ip,
      port: 8009,
      isChromecast: true,
      model: resolvedModel,
      isAudioOnly: detectedAudio,
      isStandBy: isStandBy,
      lastSeen: DateTime.now(),
    );
  }

  static final RegExp _audioOnlyModelPattern = RegExp(
    r'google home(?! hub)|home mini|home max|nest mini|nest audio|chromecast audio|cast group|speaker|soundbar|caixa de som',
    caseSensitive: false,
  );

  /// Heurística por modelo/nome para dispositivos Cast sem tela (caixas de som, grupos de áudio).
  /// "Nest Hub"/"Home Hub" possuem tela e não são excluídos.
  static bool isAudioOnlyModel(String? modelOrName) {
    if (modelOrName == null || modelOrName.isEmpty) return false;
    return _audioOnlyModelPattern.hasMatch(modelOrName);
  }

  void _rememberHost(String host) {
    if (!_lastHosts.contains(host)) {
      _lastHosts.insert(0, host);
      if (_lastHosts.length > 5) {
        _lastHosts.removeLast();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONEXÃO DIRETA COM RETRY AUTOMÁTICO (T1.3)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Conecta o celular a um receptor com retentativa automática (até 2 tentativas).
  Future<bool> connectTo(CastDevice device) async {
    if (_isConnecting) {
      debugPrint('[CastSyncService] Já existe uma conexão em andamento. Toque ignorado.');
      return false;
    }

    if (device.isChromecast) {
      return await launchChromecast(device.host, deviceName: device.name);
    }
    return await connectToHost(device.host, port: device.port, deviceName: device.name);
  }

  /// Lança a aplicação oficial no Chromecast Built-in com até 2 tentativas automáticas.
  Future<bool> launchChromecast(String host, {String? deviceName}) async {
    if (_isConnecting) return false;

    _isConnecting = true;
    _isClientConfirmed = false;
    _connectedDevice = null;
    _clientDeviceName = null;
    notifyListeners();

    final ip = await startLocalServer();
    final stopwatch = Stopwatch()..start();

    bool launched = false;
    for (int attempt = 1; attempt <= 2; attempt++) {
      debugPrint('[CastSyncService] 📡 Tentativa $attempt/2 de conexão CastV2 com $host...');
      launched = await _castV2Client.launchApp(
        host: host,
        port: 8009,
        appId: CastV2Client.defaultAppId,
        tlsTimeout: const Duration(seconds: 8),
        launchTimeout: const Duration(seconds: 14),
      );

      if (launched) {
        debugPrint('[CastSyncService] ✅ Conexão bem-sucedida na tentativa $attempt em ${stopwatch.elapsedMilliseconds}ms');
        break;
      }

      if (attempt < 2) {
        debugPrint('[CastSyncService] ⏳ Aguardando 1.5s antes da 2ª tentativa de conexão com a TV...');
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    _isConnecting = false;

    if (launched) {
      _rememberHost(host);
      _chromecastHost = host;
      _chromecastName = deviceName;
      _connectedDevice = CastDevice(
        id: '$host:8009',
        name: deviceName ?? 'Chromecast ($host)',
        host: host,
        port: 8009,
        isChromecast: true,
      );
      _clientDeviceName = deviceName ?? 'TV Sala (Chromecast)';
      _isClientConfirmed = true;

      if (ip != null) {
        _castV2Client.sendCustomMessage({
          'type': 'connect_ws',
          'wsUrl': 'ws://$ip:$defaultPort/cast',
        });
      }

      onClientScreenConfirmed?.call(_clientDeviceName!);
      notifyListeners();
      return true;
    } else {
      _isClientConfirmed = false;
      _connectedDevice = null;
      _clientDeviceName = null;
      notifyListeners();
      return false;
    }
  }

  /// Tenta restabelecer a transmissão após uma queda não solicitada (Wi-Fi oscilando, TV fechando o socket).
  /// O lançamento adota o app que ainda está aberto na TV, sem reabri-lo do zero.
  Future<void> _reconnectChromecast(String host) async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    notifyListeners();

    for (int attempt = 0; attempt < reconnectDelaysSeconds.length; attempt++) {
      await Future.delayed(Duration(seconds: reconnectDelaysSeconds[attempt]));
      if (!_isReconnecting || _isDisposed) return; // usuário desconectou durante a espera
      debugPrint('[CastSyncService] 🔁 Reconectando à TV ($host), tentativa ${attempt + 1}/${reconnectDelaysSeconds.length}...');
      final ok = await launchChromecast(host, deviceName: _chromecastName);
      if (ok) {
        debugPrint('[CastSyncService] ✅ Transmissão restabelecida.');
        _isReconnecting = false;
        notifyListeners();
        return;
      }
    }

    debugPrint('[CastSyncService] ❌ Não foi possível restabelecer a transmissão com a TV.');
    _isReconnecting = false;
    await disconnect();
  }

  /// Conecta diretamente via endereço IP da TV.
  Future<bool> connectToHost(String host, {int port = defaultPort, String? deviceName}) async {
    await disconnect();

    _isConnecting = true;
    notifyListeners();

    try {
      final wsUrl = 'ws://$host:$port/cast';
      debugPrint('[CastSyncService] Conectando a $wsUrl...');
      final socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 4));

      _clientSocket = socket;
      _connectedDevice = CastDevice(
        id: '$host:$port',
        name: deviceName ?? 'TV ($host)',
        host: host,
        port: port,
      );

      _clientSocket!.add(jsonEncode({
        'type': 'client_ready',
        'deviceName': 'Smartphone WaxClub',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));

      _clientSocket!.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'server_ack' || json['type'] == 'client_ready') {
              _isClientConfirmed = true;
              _clientDeviceName = deviceName ?? 'TV Conectada';
              onClientScreenConfirmed?.call(_clientDeviceName!);
              notifyListeners();
            }
          } catch (_) {}
        },
        onError: (err) {
          debugPrint('[CastSyncService] Erro no socket cliente: $err');
          disconnect();
        },
        onDone: () {
          debugPrint('[CastSyncService] Conexão com TV encerrada.');
          disconnect();
        },
      );

      _isConnecting = false;
      _isClientConfirmed = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CastSyncService] Falha ao conectar na TV ($host): $e');
      _isConnecting = false;
      _clientSocket = null;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  /// Desconecta todas as transmissões ativas.
  /// Com [stopTvApp] (desconexão pedida pelo usuário), limpa a tela e fecha o aplicativo na TV.
  Future<void> disconnect({bool stopTvApp = false}) async {
    // Desconexão explícita encerra qualquer tentativa de reconexão automática
    _isReconnecting = false;
    _chromecastHost = null;
    if (secondScreen.isShowing) await secondScreen.hide(byUser: stopTvApp);
    if (stopTvApp && isConnected) {
      _sendPacket({'type': 'stop'});
    }
    await _castV2Client.disconnect(stopReceiverApp: stopTvApp);
    for (final ws in List.of(_connectedClients)) {
      try {
        ws.close();
      } catch (_) {}
    }
    _connectedClients.clear();

    if (_clientSocket != null) {
      try {
        await _clientSocket!.close();
      } catch (_) {}
      _clientSocket = null;
    }

    _connectedDevice = null;
    _isConnecting = false;
    _isClientConfirmed = false;
    _clientDeviceName = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ENVIO DE DADOS (TRANSMISSÃO CELULAR -> TV)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Envia a faixa para a TV. [side] é o lado do disco ("A", "B"...), exibido no selo.
  void sendTrack(TrackInfo track, List<LyricLine> lyrics, {String? side}) {
    if (!isConnected) return;

    final packet = {
      'type': 'track_loaded',
      'track': {
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'coverUrl': track.coverUrl,
        'offsetSeconds': track.offsetSeconds,
        'durationMs': track.durationMs,
        'lrcContent': track.lrcContent,
        if (side != null && side.isNotEmpty) 'side': side,
      },
      'lyrics': lyrics.map((l) => {
        'ms': l.timestamp.inMilliseconds,
        'text': l.text,
        // tradução da linha (plugin A2), mostrada embaixo dela na TV
        if (l.translation != null) 'tr': l.translation,
      }).toList(),
    };

    _sendPacket(packet);
  }

  void sendSync({
    required double position,
    required int activeLineIndex,
    required double speedFactor,
    required String status,
    required String statusMessage,
    required bool isPaused,
    required bool isMicActive,
    String? nextTitle,
    double? speedStdErr,
    bool awaitingNeedle = false,
    double lyricBias = 0,
  }) {
    if (!isConnected) return;

    final packet = {
      'type': 'sync_update',
      'position': position,
      'activeLine': activeLineIndex,
      'speedFactor': speedFactor,
      'status': status,
      'statusMessage': statusMessage,
      'isPaused': isPaused,
      'isMicActive': isMicActive,
      if (nextTitle != null) 'nextTitle': nextTitle,
      if (speedStdErr != null) 'speedStdErr': speedStdErr,
      if (awaitingNeedle) 'awaitingNeedle': true,
      // ajuste manual da letra (±0.5 s) para a TV mostrar a confirmação
      'lyricBias': lyricBias,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _sendPacket(packet);
  }

  void sendStop() {
    if (!isConnected) return;
    _sendPacket({'type': 'stop'});
  }

  /// Avisa a TV que o disco está sendo virado: ela levanta a agulha e anima o giro do disco,
  /// trocando a letra do lado no selo para [nextSide] ("B", por exemplo).
  /// Curiosidades e notícias da faixa (em inglês) para a TV mostrar quando não há letra.
  /// [sideStart]: 1ª faixa do lado (as do disco e as notícias entram antes das da faixa).
  void sendCuriosities(RecordCuriosities c, {bool sideStart = false}) {
    if (!isConnected) return;
    Map<String, dynamic> item(Curiosity x, String kind) => {
          'kind': kind,
          'text': x.text,
          'source': x.source,
          if (x.date != null) 'date': x.date!.toUtc().toIso8601String(),
        };
    _sendPacket({
      'type': 'curiosities',
      'sideStart': sideStart,
      'items': [
        for (final x in c.album) item(x, 'record'),
        for (final x in c.news) item(x, 'news'),
        for (final x in c.track) item(x, 'track'),
      ],
    });
  }

  void sendSideFlip({String? nextSide}) {
    if (!isConnected) return;
    _sendPacket({
      'type': 'side_flip',
      if (nextSide != null && nextSide.isNotEmpty) 'nextSide': nextSide,
    });
  }

  /// Plugin A3 "Imagined Music": roteiro visual da música atual para a TV. [scenes] = cenas com o
  /// instante de início (ms), a foto e o crédito; [quotes] = frases do modo imersivo (ms e texto);
  /// [mode] = 'lyrics' (imagens atrás da letra) ou 'immersive'. Lista vazia de cenas desliga as imagens.
  /// [title] = música do roteiro: a TV só o usa quando essa música está na tela.
  void sendImagine({
    required String mode,
    required List<Map<String, dynamic>> scenes,
    List<Map<String, dynamic>> quotes = const [],
    String? title,
  }) {
    if (!isConnected) return;
    _sendPacket({'type': 'imagine', 'mode': mode, if (title != null) 'title': title, 'scenes': scenes, 'quotes': quotes});
  }

  void _sendPacket(Map<String, dynamic> data) {
    if (_castV2Client.isConnected) {
      _castV2Client.sendCustomMessage(data);
    }

    final encoded = jsonEncode(data);

    try {
      _clientSocket?.add(encoded);
    } catch (e) {
      debugPrint('[CastSyncService] Erro no envio cliente: $e');
    }

    for (final ws in List.of(_connectedClients)) {
      try {
        ws.add(encoded);
      } catch (e) {
        debugPrint('[CastSyncService] Erro no envio para tela: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _discoveryTimer?.cancel();
    _registrySub?.cancel();
    _registry.dispose();
    disconnect();
    unawaited(announcer.withdraw());
    _localServer?.close(force: true);
    _localServer = null;
    super.dispose();
  }
}
