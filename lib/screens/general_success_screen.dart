import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class GeneralSuccessScreen extends StatefulWidget {
  final String title;
  final String mainText;
  final String subtitle;
  final String? whatsAppPhone;
  final String? whatsAppMessage;

  const GeneralSuccessScreen({
    super.key,
    required this.title,
    required this.mainText,
    required this.subtitle,
    this.whatsAppPhone,
    this.whatsAppMessage,
  });

  @override
  State<GeneralSuccessScreen> createState() => _GeneralSuccessScreenState();
}

class _GeneralSuccessScreenState extends State<GeneralSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _compartirPorWhatsApp() async {
    if (widget.whatsAppPhone == null || widget.whatsAppMessage == null) return;
    
    String cleanPhone = widget.whatsAppPhone!.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10) cleanPhone = '52$cleanPhone';
    
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(widget.whatsAppMessage!)}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
          children: [
            const Spacer(),
            // Animación de Éxito
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppTheme.success, size: 100),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.mainText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.accent,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ),
            const Spacer(),
            
            // Botones de acción
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (widget.whatsAppPhone != null && widget.whatsAppMessage != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _compartirPorWhatsApp,
                        icon: const Icon(Icons.share, color: Colors.green),
                        label: const Text('Compartir Comprobante (WhatsApp)'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Cerrar success screen
                    },
                    child: const Text(
                      'Cerrar y Volver',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
