import 'package:flutter/material.dart';

class OverlayHelper {
  /// Muestra un flash verde de éxito
  static void showSuccess(BuildContext context, {String message = 'Operación Exitosa'}) {
    _showOverlay(context, message, Colors.green[500]!, Icons.check_circle_outline);
  }

  /// Muestra un flash rojo de error
  static void showError(BuildContext context, {String message = 'Ocurrió un error'}) {
    _showOverlay(context, message, Colors.red[500]!, Icons.error_outline);
  }

  static void _showOverlay(BuildContext context, String message, Color color, IconData icon) {
    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedOverlay(
        message: message,
        color: color,
        icon: icon,
        onComplete: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _AnimatedOverlay extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onComplete;

  const _AnimatedOverlay({
    required this.message,
    required this.color,
    required this.icon,
    required this.onComplete,
  });

  @override
  State<_AnimatedOverlay> createState() => _AnimatedOverlayState();
}

class _AnimatedOverlayState extends State<_AnimatedOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    
    // Curva de entrada
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Animamos entrada
    _controller.forward();

    // Esperar y animar salida
    Future.delayed(const Duration(milliseconds: 1400), () async {
      if (mounted) {
        await _controller.reverse(); // Fade out
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false, // Bloquea los toques detrás del overlay mientras dure (1.7s en total)
        child: FadeTransition(
          opacity: _opacityAnim,
          child: Container(
            color: widget.color.withOpacity(0.9), // Fondo del color cubriendo la pantalla
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 100, color: Colors.white),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none, // Necesario porque Overlay no tiene Material ancestor a veces
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
