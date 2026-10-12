import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'cast_frame_parser.dart';

/// Falhas tipadas de conexão com o Google Cast com mensagens claras em português.
enum CastFailureType {
  timeoutTls,
  appNaoAbriu,
  semStatus,
  recusado,
  socketFechado,
  erroGenerico,
}

class CastFailure {
  final CastFailureType type;
  final String message;
  final Object? cause;

  const CastFailure(this.type, this.message, [this.cause]);

  @override
  String toString() => message;
}

/// Interface abstrata de socket para comunicação CastV2,
/// permitindo injeção de sockets falsos em testes automatizados.
abstract class CastSocket {
  Stream<List<int>> get stream;
  void add(List<int> data);
  Future<void> close();
}

/// Implementação real de [CastSocket] sobre [SecureSocket].
class RealCastSocket implements CastSocket {
  final SecureSocket _socket;

  RealCastSocket(this._socket);

  static Future<CastSocket> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final s = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (_) => true, // Certificados autoassinados do Cast
      timeout: timeout,
    );
    return RealCastSocket(s);
  }

  @override
  Stream<List<int>> get stream => _socket;

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  Future<void> close() => _socket.close();
}

/// Representa uma mensagem do protocolo Google CastV2 enquadrada em Protocol Buffers.
class CastMessage {
  final int protocolVersion;
  final String sourceId;
  final String destinationId;
  final String namespace;
  final int payloadType;
  final String payloadUtf8;
  final Uint8List? payloadBinary;

  const CastMessage({
    required this.sourceId,
    required this.destinationId,
    required this.namespace,
    required this.payloadUtf8,
    this.protocolVersion = 0,
    this.payloadType = 0,
    this.payloadBinary,
  });

  /// Decodifica uma mensagem a partir de bytes protobuf puros.
  factory CastMessage.fromProtobufBytes(Uint8List bytes) {
    return CastFrameParser.parseProtobufMessage(bytes);
  }

  /// Serializa a mensagem para bytes no formato Protocol Buffers
  /// com cabeçalho de 4 bytes Big-Endian (tamanho do payload).
  Uint8List toProtobufBytes() {
    final builder = BytesBuilder();

    // Field 1: protocol_version (varint) -> tag = (1 << 3) | 0 = 0x08
    builder.addByte(0x08);
    _writeVarint(builder, protocolVersion);

    // Field 2: source_id (string) -> tag = (2 << 3) | 2 = 0x12
    _writeStringField(builder, 2, sourceId);

    // Field 3: destination_id (string) -> tag = (3 << 3) | 2 = 0x1A
    _writeStringField(builder, 3, destinationId);

    // Field 4: namespace (string) -> tag = (4 << 3) | 2 = 0x22
    _writeStringField(builder, 4, namespace);

    // Field 5: payload_type (varint) -> tag = (5 << 3) | 0 = 0x28
    builder.addByte(0x28);
    _writeVarint(builder, payloadType);

    // Field 6: payload_utf8 (string) -> tag = (6 << 3) | 2 = 0x32
    if (payloadUtf8.isNotEmpty) {
      _writeStringField(builder, 6, payloadUtf8);
    }

    // Field 7: payload_binary (bytes) -> tag = (7 << 3) | 2 = 0x3A
    if (payloadBinary != null && payloadBinary!.isNotEmpty) {
      const tag = (7 << 3) | 2;
      _writeVarint(builder, tag);
      _writeVarint(builder, payloadBinary!.length);
      builder.add(payloadBinary!);
    }

    final protoBytes = builder.toBytes();

    // Prefixo de enquadramento CASTV2: 4 bytes Big-Endian com o tamanho do payload
    final frame = BytesBuilder();
    final header = ByteData(4)..setUint32(0, protoBytes.length, Endian.big);
    frame.add(header.buffer.asUint8List());
    frame.add(protoBytes);

    return frame.toBytes();
  }

  static void _writeStringField(BytesBuilder builder, int fieldNumber, String value) {
    final bytes = utf8.encode(value);
    final tag = (fieldNumber << 3) | 2;
    _writeVarint(builder, tag);
    _writeVarint(builder, bytes.length);
    builder.add(bytes);
  }

  static void _writeVarint(BytesBuilder builder, int value) {
    int v = value;
    while (v >= 0x80) {
      builder.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    builder.addByte(v & 0x7F);
  }
}

/// Cliente nativo Google CastV2 (porta 8009 TLS) robusto e orientado a estado.
class CastV2Client {
  static const int castPort = 8009;
  static const String nsConnection = 'urn:x-cast:com.google.cast.tp.connection';
  static const String nsReceiver = 'urn:x-cast:com.google.cast.receiver';
  static const String nsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
  static const String nsCustomSync = 'urn:x-cast:com.waxclub.sync';

  static const String defaultAppId = '27687E0B'; // WaxClub TV oficial Google Cast ID

  // Fábrica de socket injetável para testes unitários
  final Future<CastSocket> Function(String host, int port, {Duration timeout}) socketConnector;

  CastSocket? _socket;
  StreamSubscription<List<int>>? _socketSub;
  Timer? _heartbeatTimer;
  Timer? _pollingTimer;
  final CastFrameParser _frameParser = CastFrameParser();

  int _requestId = 1;
  bool _isConnected = false;
  bool _receiverAck = false;
  String? _transportId;
  String? _appSessionId;
  String? _launchingAppId;
  String? _lastError;
  CastFailure? _lastFailure;
  String _statusStep = 'Disconnected';

  Map<String, dynamic>? _pendingTrackLoaded;

  /// Callback chamado quando a TV fecha a conexão remotamente
  VoidCallback? onDisconnected;

  bool get isConnected => _isConnected;
  bool get receiverAck => _receiverAck;
  String? get transportId => _transportId;
  String? get lastError => _lastError;
  CastFailure? get lastFailure => _lastFailure;
  String get statusStep => _statusStep;

  CastV2Client({
    Future<CastSocket> Function(String host, int port, {Duration timeout})? socketConnector,
  }) : socketConnector = socketConnector ?? RealCastSocket.connect;

  /// Conecta ao Chromecast via TLS (porta 8009) e lança ou adota a aplicação Web Receiver.
  Future<bool> launchApp({
    required String host,
    int port = castPort,
    String appId = defaultAppId,
    Duration tlsTimeout = const Duration(seconds: 8),
    Duration launchTimeout = const Duration(seconds: 25),
  }) async {
    try {
      await disconnect();
      _lastError = null;
      _lastFailure = null;
      _launchingAppId = appId;
      _receiverAck = false;
      _statusStep = 'Connecting to Chromecast over TLS ($host:$port)...';

      debugPrint('[CastV2Client] Conectando TLS a $host:$port para App ID $appId...');

      try {
        _socket = await socketConnector(host, port, timeout: tlsTimeout);
      } catch (e) {
        _setFailure(CastFailureType.timeoutTls, 'Timed out connecting to the TV over TLS ($host): $e', e);
        return false;
      }

      _isConnected = true;
      _statusStep = 'TLS connection established. Negotiating channels...';

      final launchCompleter = Completer<bool>();

      // Inicia escuta estruturada via CastFrameParser
      _socketSub = _socket!.stream.listen(
        (data) {
          try {
            final messages = _frameParser.add(data);
            for (final msg in messages) {
              _processReceivedMessage(msg, launchCompleter);
            }
          } catch (err) {
            debugPrint('[CastV2Client] Erro no processamento de quadros: $err');
          }
        },
        onError: (err) {
          debugPrint('[CastV2Client] Erro no socket CastV2: $err');
          _setFailure(CastFailureType.socketFechado, 'TV communication channel error: $err', err);
          if (!launchCompleter.isCompleted) launchCompleter.complete(false);
          _handleRemoteDisconnection();
        },
        onDone: () {
          debugPrint('[CastV2Client] Conexão CastV2 finalizada pela TV.');
          _setFailure(CastFailureType.socketFechado, 'The TV closed the connection.');
          if (!launchCompleter.isCompleted) launchCompleter.complete(false);
          _handleRemoteDisconnection();
        },
      );

      // 1. Handshake de Conexão com o receiver principal
      _sendToReceiver0(nsConnection, {'type': 'CONNECT'});

      // 2. Consulta de Status inicial para verificar se o app já está rodando
      _statusStep = 'Checking TV status...';
      _sendToReceiver0(nsReceiver, {'type': 'GET_STATUS', 'requestId': _requestId++});

      // 3. Heartbeat PING periódico a cada 5s
      _startHeartbeat();

      // Dispara ciclo de inicialização controlado
      final startTime = DateTime.now();
      bool launchCommandSent = false;
      DateTime? lastLaunchTime;

      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
        if (!_isConnected || launchCompleter.isCompleted) {
          timer.cancel();
          return;
        }

        final elapsed = DateTime.now().difference(startTime);
        if (elapsed > launchTimeout) {
          timer.cancel();
          if (!launchCompleter.isCompleted) {
            _setFailure(
              CastFailureType.appNaoAbriu,
              'Startup timed out (${launchTimeout.inSeconds}s). The TV did not finish opening the app.',
            );
            launchCompleter.complete(false);
          }
          return;
        }

        // Se ainda não temos transportId e ainda não enviamos LAUNCH (ou se já passaram 10s do primeiro LAUNCH)
        if (_transportId == null) {
          if (!launchCommandSent) {
            launchCommandSent = true;
            lastLaunchTime = DateTime.now();
            _statusStep = 'Starting app ID $appId on the TV...';
            debugPrint('[CastV2Client] Despachando comando LAUNCH para $appId...');
            _sendToReceiver0(nsReceiver, {
              'type': 'LAUNCH',
              'appId': appId,
              'requestId': _requestId++,
            });
          } else if (lastLaunchTime != null && DateTime.now().difference(lastLaunchTime!) > const Duration(seconds: 10)) {
            // Reenvia LAUNCH uma vez após 10s se cold start do stick demorou
            lastLaunchTime = DateTime.now();
            debugPrint('[CastV2Client] Reenviando LAUNCH de reforço para $appId...');
            _sendToReceiver0(nsReceiver, {
              'type': 'LAUNCH',
              'appId': appId,
              'requestId': _requestId++,
            });
          } else {
            // Poll com GET_STATUS
            _sendToReceiver0(nsReceiver, {'type': 'GET_STATUS', 'requestId': _requestId++});
          }
        }
      });

      final success = await launchCompleter.future;
      _pollingTimer?.cancel();
      _pollingTimer = null;

      if (success) {
        // Envia mensagem pendente de música se houver
        if (_pendingTrackLoaded != null && _transportId != null) {
          sendCustomMessage(_pendingTrackLoaded!);
          _pendingTrackLoaded = null;
        }
        return true;
      } else {
        await disconnect();
        return false;
      }
    } catch (e) {
      _setFailure(CastFailureType.erroGenerico, 'Unexpected Cast launch failure ($host): $e', e);
      await disconnect();
      return false;
    }
  }

  void _processReceivedMessage(CastMessage msg, Completer<bool> launchCompleter) {
    // 1. Tratamento automático de HEARTBEAT: responder PONG a todo PING recebido
    if (msg.namespace == nsHeartbeat) {
      try {
        final payload = jsonDecode(msg.payloadUtf8);
        if (payload is Map && payload['type'] == 'PING') {
          _send(CastMessage(
            sourceId: 'sender-0',
            destinationId: msg.sourceId,
            namespace: nsHeartbeat,
            payloadUtf8: jsonEncode({'type': 'PONG'}),
          ));
        }
      } catch (_) {}
      return;
    }

    // 2. Confirmação do canal oficial WaxClub
    if (msg.namespace == nsCustomSync) {
      try {
        final data = jsonDecode(msg.payloadUtf8);
        if (data is Map && data['type'] == 'client_ready') {
          debugPrint('[CastV2Client] ✅ Receptor confirmou client_ready no canal customizado!');
          _receiverAck = true;
        }
      } catch (_) {}
      return;
    }

    // 3. Fechamento remoto detectado via CLOSE no namespace de conexão
    if (msg.namespace == nsConnection) {
      try {
        final data = jsonDecode(msg.payloadUtf8);
        if (data is Map && data['type'] == 'CLOSE') {
          if (msg.sourceId == _transportId) {
            debugPrint('[CastV2Client] ⚠️ Aplicação na TV fechada remotamente (CLOSE recebido de $_transportId).');
            _handleRemoteDisconnection();
          }
        }
      } catch (_) {}
      return;
    }

    // 4. Tratamento de RECEIVER_STATUS e LAUNCH_ERROR
    if (msg.namespace == nsReceiver) {
      try {
        final json = jsonDecode(msg.payloadUtf8);
        if (json is! Map<String, dynamic>) return;

        final type = json['type'] as String?;

        if (type == 'RECEIVER_STATUS') {
          final status = json['status'] as Map<String, dynamic>?;
          final apps = status?['applications'] as List<dynamic>?;

          if (apps != null && apps.isNotEmpty) {
            Map<String, dynamic>? targetApp;
            for (final a in apps) {
              if (a is Map<String, dynamic> && a['appId'] == _launchingAppId) {
                targetApp = a;
                break;
              }
            }

            if (targetApp != null) {
              final newTransportId = targetApp['transportId'] as String?;
              final displayName = targetApp['displayName'] as String? ?? 'WaxClub TV';
              _appSessionId = targetApp['sessionId'] as String? ?? _appSessionId;

              if (newTransportId != null && _transportId != newTransportId) {
                _transportId = newTransportId;
                debugPrint('[CastV2Client] 🎯 App "$displayName" rodando! TransportId: $_transportId');

                // Conecta imediatamente ao canal da aplicação
                _send(CastMessage(
                  sourceId: 'sender-0',
                  destinationId: _transportId!,
                  namespace: nsConnection,
                  payloadUtf8: jsonEncode({'type': 'CONNECT'}),
                ));

                // Handshake inicial no canal de sincronismo
                _send(CastMessage(
                  sourceId: 'sender-0',
                  destinationId: _transportId!,
                  namespace: nsCustomSync,
                  payloadUtf8: jsonEncode({'type': 'hello'}),
                ));

                _statusStep = 'Web receiver running on the TV (transport ID: $_transportId)';

                if (!launchCompleter.isCompleted) {
                  launchCompleter.complete(true);
                }
              }
            } else if (_transportId != null) {
              // Aplicação não está mais na lista de executando
              debugPrint('[CastV2Client] ⚠️ Aplicação não está mais ativa no status da TV.');
              _handleRemoteDisconnection();
            }
          }
        } else if (type == 'LAUNCH_ERROR') {
          final reason = json['reason'] as String? ?? 'NOT_FOUND';
          _setFailure(CastFailureType.recusado, 'A TV recusou o aplicativo: $reason');
          debugPrint('[CastV2Client] ⚠️ LAUNCH_ERROR da TV: $reason');
          if (!launchCompleter.isCompleted) {
            launchCompleter.complete(false);
          }
        }
      } catch (e) {
        debugPrint('[CastV2Client] Erro ao analisar status do receiver: $e');
      }
    }
  }

  void _sendToReceiver0(String namespace, Map<String, dynamic> payload) {
    _send(CastMessage(
      sourceId: 'sender-0',
      destinationId: 'receiver-0',
      namespace: namespace,
      payloadUtf8: jsonEncode(payload),
    ));
  }

  /// Envia mensagem customizada de sincronismo/faixa SOMENTE para o transportId da aplicação.
  /// Nunca envia para receiver-0. Se ainda não há transportId, armazena a mensagem se for track_loaded.
  void sendCustomMessage(Map<String, dynamic> data) {
    if (_transportId == null) {
      if (data['type'] == 'track_loaded') {
        _pendingTrackLoaded = data;
      }
      return;
    }

    if (!_isConnected || _socket == null) return;

    _send(CastMessage(
      sourceId: 'sender-0',
      destinationId: _transportId!,
      namespace: nsCustomSync,
      payloadUtf8: jsonEncode(data),
    ));
  }

  void _send(CastMessage message) {
    if (_socket == null) return;
    try {
      final bytes = message.toProtobufBytes();
      _socket!.add(bytes);
    } catch (e) {
      debugPrint('[CastV2Client] Erro ao enviar mensagem CastV2: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isConnected && _socket != null) {
        // Heartbeat no nível de plataforma (receiver-0), que mantém a conexão TLS viva
        _send(CastMessage(
          sourceId: 'sender-0',
          destinationId: 'receiver-0',
          namespace: nsHeartbeat,
          payloadUtf8: jsonEncode({'type': 'PING'}),
        ));
      }
    });
  }

  void _setFailure(CastFailureType type, String message, [Object? cause]) {
    _lastFailure = CastFailure(type, message, cause);
    _lastError = message;
    _statusStep = message;
  }

  void _handleRemoteDisconnection() {
    if (_isConnected) {
      debugPrint('[CastV2Client] ⚠️ Conexão com a TV perdida. Motivo: ${_lastError ?? "app ausente no status da TV"}');
      _isConnected = false;
      _transportId = null;
      _statusStep = 'Disconnected';
      onDisconnected?.call();
    }
  }

  /// Encerra a conexão. Com [stopReceiverApp], fecha também o aplicativo na TV (comando STOP do
  /// receiver), para que a tela da TV volte ao estado normal em vez de continuar exibindo o WaxClub.
  Future<void> disconnect({bool stopReceiverApp = false}) async {
    if (stopReceiverApp && _isConnected && _socket != null) {
      if (_transportId != null) {
        _send(CastMessage(
          sourceId: 'sender-0',
          destinationId: _transportId!,
          namespace: nsConnection,
          payloadUtf8: jsonEncode({'type': 'CLOSE'}),
        ));
      }
      if (_appSessionId != null) {
        _sendToReceiver0(nsReceiver, {
          'type': 'STOP',
          'sessionId': _appSessionId,
          'requestId': _requestId++,
        });
        debugPrint('[CastV2Client] ⏹️ STOP enviado à TV (sessionId: $_appSessionId).');
      }
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isConnected = false;
    _receiverAck = false;
    _transportId = null;
    _appSessionId = null;
    _launchingAppId = null;
    _pendingTrackLoaded = null;
    _frameParser.clear();

    if (_socketSub != null) {
      try {
        await _socketSub!.cancel();
      } catch (_) {}
      _socketSub = null;
    }

    if (_socket != null) {
      try {
        await _socket!.close();
      } catch (_) {}
      _socket = null;
    }
  }
}
