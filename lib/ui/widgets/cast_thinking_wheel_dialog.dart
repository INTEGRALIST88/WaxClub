import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/cast_sync_service.dart';
import '../theme/app_theme.dart';

/// Diálogo unificado de Transmissão para TV (Google Cast & Web Receiver).
class CastThinkingWheelDialog extends StatefulWidget {
  final CastSyncService castService;
  final VoidCallback onConnected;

  const CastThinkingWheelDialog({
    super.key,
    required this.castService,
    required this.onConnected,
  });

  static Future<void> show(
    BuildContext context, {
    required CastSyncService castService,
    required VoidCallback onConnected,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CastThinkingWheelDialog(
        castService: castService,
        onConnected: onConnected,
      ),
    );
  }

  @override
  State<CastThinkingWheelDialog> createState() => _CastThinkingWheelDialogState();
}

class _CastThinkingWheelDialogState extends State<CastThinkingWheelDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _autoDismissTimer;
  StreamSubscription<List<CastDevice>>? _devicesSub;
  bool _confirmedTriggered = false;

  // Estado da navegação interna do diálogo
  CastDevice? _selectedDevice;
  bool _showBrowserFallback = false;
  bool _showManualIp = false;
  final TextEditingController _ipController = TextEditingController();
  String _statusMessage = l10n.castWaitingConfirm;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    widget.castService.addListener(_onServiceUpdate);

    // Escuta fluxo reativo progressivo de dispositivos
    _devicesSub = widget.castService.devicesStream.listen((_) {
      if (mounted) setState(() {});
    });

    // 1. Assegura servidor local ativo
    widget.castService.startLocalServer();

    // 2. Dispara busca idempotente (single-flight)
    _startDeviceDiscovery();
  }

  void _startDeviceDiscovery({bool forceSubnet = false}) {
    widget.castService.discoverDevices(forceSubnet: forceSubnet);
  }

  void _onServiceUpdate() {
    if (!mounted) return;

    if (widget.castService.isClientConfirmed && !_confirmedTriggered) {
      _confirmedTriggered = true;
      setState(() {
        _statusMessage = l10n.castScreenConfirmed;
      });

      _autoDismissTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onConnected();
        }
      });
    } else {
      setState(() {});
    }
  }

  void _selectAndConnect(CastDevice device) async {
    if (widget.castService.isConnecting) return;

    setState(() {
      _selectedDevice = device;
      _statusMessage = l10n.castConnectingTo(device.name);
    });

    final success = await widget.castService.connectTo(device);
    if (!success && mounted) {
      setState(() {
        _statusMessage = widget.castService.lastCastError ?? l10n.castNoResponse;
      });
    }
  }

  void _handleManualIpSubmit() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    setState(() {
      _statusMessage = l10n.castLookingAtIp(ip);
    });

    final dev = await widget.castService.addManualIp(ip);
    if (dev != null) {
      _selectAndConnect(dev);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.surfaceLight,
            content: Text(l10n.castNothingAtIp(ip), style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    }
  }

  void _resetToDeviceSelection() {
    widget.castService.disconnect(stopTvApp: true);
    setState(() {
      _selectedDevice = null;
      _showBrowserFallback = false;
      _statusMessage = l10n.castWaitingConfirm;
    });
    _startDeviceDiscovery();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _devicesSub?.cancel();
    _ipController.dispose();
    widget.castService.removeListener(_onServiceUpdate);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = widget.castService.isClientConfirmed;
    final isScanning = widget.castService.isScanning;
    final devices = widget.castService.discoveredDevices;
    final webUrl = widget.castService.webReceiverUrl;

    final isConnectingMode = _selectedDevice != null || _showBrowserFallback;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isConfirmed ? AppTheme.cream : Colors.white12,
            width: isConfirmed ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isConfirmed
                  ? AppTheme.cream.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: isConnectingMode
            ? _buildConnectingView(isConfirmed, webUrl)
            : _buildDeviceSelectionView(isScanning, devices),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FASE 1: LISTA E SELEÇÃO DE APARELHOS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDeviceSelectionView(bool isScanning, List<CastDevice> devices) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.cast, color: AppTheme.cream, size: 22),
                SizedBox(width: 10),
                Text(
                  l10n.castToTv,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (isScanning)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.cream,
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.cream, size: 20),
                    tooltip: l10n.searchAgain,
                    onPressed: () => _startDeviceDiscovery(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Barra de status da busca com contador progressivo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isScanning
                ? AppTheme.cream.withValues(alpha: 0.1)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isScanning ? AppTheme.cream.withValues(alpha: 0.25) : Colors.white10,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isScanning ? Icons.radar : Icons.devices,
                size: 16,
                color: isScanning ? AppTheme.cream : Colors.white70,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isScanning
                      ? l10n.castSearching(devices.length)
                      : (devices.isNotEmpty
                          ? l10n.castDevicesAvailable(devices.length)
                          : l10n.castNoTvFound),
                  style: TextStyle(
                    fontSize: 12,
                    color: isScanning ? AppTheme.cream : Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // LISTA DE APARELHOS
        if (devices.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, idx) {
                final dev = devices[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: dev.isStandBy
                          ? Colors.amber.withValues(alpha: 0.3)
                          : AppTheme.cream.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _selectAndConnect(dev),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (dev.isAudioOnly ? AppTheme.rust : AppTheme.cream)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                dev.isAudioOnly ? Icons.speaker_rounded : Icons.tv_rounded,
                                size: 20,
                                color: dev.isAudioOnly ? AppTheme.orange : AppTheme.cream,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dev.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      if (dev.isStandBy)
                                        Text(
                                          l10n.castIdlePrefix,
                                          style: TextStyle(fontSize: 11, color: Colors.amber),
                                        ),
                                      if (dev.model != null && dev.model!.isNotEmpty)
                                        Flexible(
                                          child: Text(
                                            dev.model!,
                                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )
                                      else
                                        Text(
                                          dev.host,
                                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.cream,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n.connectCaps,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else if (!isScanning)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 36, color: Colors.white38),
                const SizedBox(height: 8),
                Text(
                  l10n.noScreenFound,
                  style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.sameWifiHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textInactive),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Botões de ação complementar: Buscar na rede / Digitar IP
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.network_check, size: 15),
              label: Text(l10n.searchNetwork, style: const TextStyle(fontSize: 11.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cream,
                side: const BorderSide(color: AppTheme.cream),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: () => _startDeviceDiscovery(forceSubnet: true),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 15),
              label: Text(_showManualIp ? l10n.hideIp : l10n.addByIp, style: const TextStyle(fontSize: 11.5)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: () {
                setState(() {
                  _showManualIp = !_showManualIp;
                });
              },
            ),
          ],
        ),

        // Campo para digitar IP manualmente
        if (_showManualIp) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: l10n.ipExample,
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cream,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
                onPressed: _handleManualIpSubmit,
                child: Text(l10n.add, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],

        const SizedBox(height: 12),
        // Alternativa via navegador
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _showBrowserFallback = true;
              _statusMessage = l10n.openAddressInBrowser;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, size: 15, color: Colors.white70),
                SizedBox(width: 8),
                Text(
                  l10n.castViaBrowser,
                  style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: Colors.white38),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FASE 2: RODA DE PENSAMENTO (CONECTANDO)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildConnectingView(bool isConfirmed, String webUrl) {
    final targetName = _selectedDevice?.name ?? l10n.tvBrowser;
    final isConnecting = widget.castService.isConnecting;
    final isFailed = !isConfirmed && !isConnecting && !_showBrowserFallback;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.cream, size: 20),
              tooltip: l10n.back,
              onPressed: _resetToDeviceSelection,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Flexible(
              child: Text(
                targetName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // RODA DE PENSAMENTO ANIMADA
        SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animController.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(160, 160),
                      painter: _ThinkingWheelPainter(
                        isConfirmed: isConfirmed,
                        isFailed: isFailed,
                      ),
                    ),
                  );
                },
              ),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isConfirmed
                          ? AppTheme.cream
                          : (isFailed ? Colors.redAccent : Colors.white24),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isConfirmed
                                ? AppTheme.cream
                                : (isFailed ? Colors.redAccent : AppTheme.orange))
                            .withValues(alpha: 0.3),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Icon(
                    isConfirmed
                        ? Icons.check_circle_rounded
                        : (isFailed ? Icons.error_outline_rounded : Icons.tv_rounded),
                    color: isConfirmed
                        ? AppTheme.cream
                        : (isFailed ? Colors.redAccent : Colors.white),
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          isConfirmed
              ? l10n.screenConnected
              : (isFailed ? l10n.connectionFailed : l10n.syncingWithTv),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isConfirmed
                ? AppTheme.cream
                : (isFailed ? Colors.redAccent : Colors.white),
          ),
        ),
        const SizedBox(height: 8),

        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textInactive,
            height: 1.35,
          ),
        ),

        if (_showBrowserFallback && !isConfirmed) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cream.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cream.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  l10n.openThisAddress,
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  webUrl,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cream,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        if (isFailed)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l10n.tryAgainCaps),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cream,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  if (_selectedDevice != null) {
                    _selectAndConnect(_selectedDevice!);
                  }
                },
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetToDeviceSelection,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: Text(l10n.changeTv),
              ),
            ],
          )
        else if (!isConfirmed)
          TextButton(
            onPressed: _resetToDeviceSelection,
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
            child: Text(l10n.cancelAndGoBack),
          ),
      ],
    );
  }
}

class _ThinkingWheelPainter extends CustomPainter {
  final bool isConfirmed;
  final bool isFailed;

  _ThinkingWheelPainter({
    required this.isConfirmed,
    required this.isFailed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final basePaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, basePaint);

    final sweepGradient = SweepGradient(
      colors: isConfirmed
          ? [AppTheme.cream.withValues(alpha: 0.0), AppTheme.cream]
          : (isFailed
              ? [Colors.redAccent.withValues(alpha: 0.0), Colors.redAccent]
              : [
                  AppTheme.orange.withValues(alpha: 0.0),
                  AppTheme.cream,
                ]),
    );

    final activePaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.5 * math.pi,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ThinkingWheelPainter oldDelegate) {
    return oldDelegate.isConfirmed != isConfirmed || oldDelegate.isFailed != isFailed;
  }
}
