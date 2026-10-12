import 'package:flutter/material.dart';

/// Botão "Vire o disco" que pulsa enquanto o app aguarda a virada do lado do disco.
///
/// [wide] = botão largo do painel de controle (modo TV); caso contrário, botão flutuante sobre a letra.
class FlipSideButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool wide;
  final String label;

  const FlipSideButton({
    super.key,
    required this.onPressed,
    this.wide = false,
    this.label = 'FLIP THE RECORD',
  });

  @override
  State<FlipSideButton> createState() => _FlipSideButtonState();
}

class _FlipSideButtonState extends State<FlipSideButton> with SingleTickerProviderStateMixin {
  static const Color _color = Color(0xFFFFB300); // âmbar: destaca do roxo/ciano habituais

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Transform.scale(
          scale: 1.0 + 0.05 * t,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.wide ? 16 : 30),
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: 0.35 + 0.35 * t),
                  blurRadius: 10 + 18 * t,
                  spreadRadius: 1 + 3 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.wide ? _buildWide() : _buildFab(),
    );
  }

  Widget _buildWide() {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _color,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: widget.onPressed,
        icon: const Icon(Icons.flip_camera_android_rounded, size: 26),
        label: Text(
          widget.label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: widget.onPressed,
      backgroundColor: _color,
      foregroundColor: Colors.black,
      icon: const Icon(Icons.flip_camera_android_rounded),
      label: Text(
        widget.label,
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
      ),
    );
  }
}
