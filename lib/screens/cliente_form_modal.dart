import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cliente_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'general_success_screen.dart';

class ClienteFormModal extends StatefulWidget {
  final Cliente? cliente;
  const ClienteFormModal({super.key, this.cliente});

  @override
  State<ClienteFormModal> createState() => _ClienteFormModalState();
}

class _ClienteFormModalState extends State<ClienteFormModal> {
  final _formKey = GlobalKey<FormState>();
  FirebaseService get _firebaseService => Provider.of<FirebaseService>(context, listen: false);

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _celularCtrl = TextEditingController();

  final List<int> _pastelColors = [
    0xFFA7F3D0, // Verde pastel (emerald-200)
    0xFFFDBA74, // Naranja pastel (orange-300)
    0xFFFEF08A, // Amarillo pastel (yellow-200)
    0xFFFECACA, // Rojo pastel (red-200)
    0xFFBFDBFE, // Azul pastel (blue-200)
    0xFFE9D5FF, // Morado pastel (purple-200)
    0xFFFBCFE8, // Rosa pastel (pink-200)
  ];
  int _selectedColor = 0xFFA7F3D0;
  bool _isDistinguido = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.cliente != null) {
      _nombreCtrl.text = widget.cliente!.nombre;
      _celularCtrl.text = widget.cliente!.celular;
      _selectedColor = widget.cliente!.colorPerfil;
      _isDistinguido = widget.cliente!.isDistinguido;
    } else {
      // Asignar un color aleatorio si es un nuevo cliente
      _selectedColor = _pastelColors[DateTime.now().millisecond % _pastelColors.length];
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _celularCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarCliente() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        if (widget.cliente == null) {
          final nuevoCliente = Cliente(
            nombre: _nombreCtrl.text.trim(),
            celular: _celularCtrl.text.trim(),
            colorPerfil: _selectedColor,
            isDistinguido: _isDistinguido,
          );
          await _firebaseService.addCliente(nuevoCliente);
        } else {
          widget.cliente!.nombre = _nombreCtrl.text.trim();
          widget.cliente!.celular = _celularCtrl.text.trim();
          widget.cliente!.colorPerfil = _selectedColor;
          widget.cliente!.isDistinguido = _isDistinguido;
          await _firebaseService.updateCliente(widget.cliente!);
        }

        if (mounted) {
          Navigator.pop(context); // Cerrar modal
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GeneralSuccessScreen(
                title: widget.cliente == null ? '¡Cliente Registrado!' : '¡Cliente Actualizado!',
                mainText: widget.cliente == null ? 'Nuevo Cliente' : 'Actualización Exitosa',
                subtitle: 'El cliente ${_nombreCtrl.text.trim()} ha sido guardado.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.grey[800],
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Para que el bottom sheet pueda redimensionarse con el teclado
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Calculamos el alto máximo para que no desborde si hay muchos campos
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9, // Máximo 90% de la pantalla para permitir scroll
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 24,
        right: 24,
        bottom: bottomInset > 0 ? bottomInset + 24 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pequeña barra superior del bottom sheet
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Título y botón cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.cliente == null ? 'Alta de Cliente' : 'Editar Cliente',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textLight),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Formulario desplazable
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLabel('Nombre'),
                    _buildTextField(
                      controller: _nombreCtrl,
                      hintText: 'Ej. Alejandro',
                      icon: Icons.person_outline,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Celular'),
                    _buildTextField(
                      controller: _celularCtrl,
                      hintText: 'Ej. 55 1234 5678',
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: const Text('Cliente Distinguido', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      subtitle: const Text('Asignar insignia de cliente distinguido', style: TextStyle(fontSize: 12)),
                      secondary: Icon(Icons.star, color: _isDistinguido ? Colors.amber : Colors.grey),
                      value: _isDistinguido,
                      onChanged: (bool value) {
                        setState(() {
                          _isDistinguido = value;
                        });
                      },
                      activeColor: Colors.amber,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          
          // Botón Guardar siempre visible abajo
          const SizedBox(height: 16),
          _isSaving
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ElevatedButton(
                  onPressed: _guardarCliente,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.cliente == null ? 'Guardar Cliente' : 'Actualizar Cliente'),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textLight,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }



  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return 'Campo obligatorio';
        }
        return null;
      },
    );
  }
}
