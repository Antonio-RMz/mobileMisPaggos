import 'package:flutter/material.dart';
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
  final FirebaseService _firebaseService = FirebaseService();

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _apPaternoCtrl = TextEditingController();
  final TextEditingController _apMaternoCtrl = TextEditingController();
  final TextEditingController _celularCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _observacionesCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();
  final TextEditingController _apodoCtrl = TextEditingController();
  final TextEditingController _referenciasDireccionCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.cliente != null) {
      _nombreCtrl.text = widget.cliente!.nombre;
      _apPaternoCtrl.text = widget.cliente!.apPaterno;
      _apMaternoCtrl.text = widget.cliente!.apMaterno;
      _celularCtrl.text = widget.cliente!.celular;
      _telefonoCtrl.text = widget.cliente!.telefono;
      _correoCtrl.text = widget.cliente!.correo;
      _observacionesCtrl.text = widget.cliente!.observaciones;
      _direccionCtrl.text = widget.cliente!.direccion;
      _apodoCtrl.text = widget.cliente!.apodo;
      _referenciasDireccionCtrl.text = widget.cliente!.referenciasDireccion;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apPaternoCtrl.dispose();
    _apMaternoCtrl.dispose();
    _celularCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _observacionesCtrl.dispose();
    _direccionCtrl.dispose();
    _apodoCtrl.dispose();
    _referenciasDireccionCtrl.dispose();
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
            apPaterno: _apPaternoCtrl.text.trim(),
            apMaterno: _apMaternoCtrl.text.trim(),
            celular: _celularCtrl.text.trim(),
            correo: _correoCtrl.text.trim(),
            telefono: _telefonoCtrl.text.trim(),
            observaciones: _observacionesCtrl.text.trim(),
            direccion: _direccionCtrl.text.trim(),
            apodo: _apodoCtrl.text.trim(),
            referenciasDireccion: _referenciasDireccionCtrl.text.trim(),
          );
          await _firebaseService.addCliente(nuevoCliente);
        } else {
          widget.cliente!.nombre = _nombreCtrl.text.trim();
          widget.cliente!.apPaterno = _apPaternoCtrl.text.trim();
          widget.cliente!.apMaterno = _apMaternoCtrl.text.trim();
          widget.cliente!.celular = _celularCtrl.text.trim();
          widget.cliente!.correo = _correoCtrl.text.trim();
          widget.cliente!.telefono = _telefonoCtrl.text.trim();
          widget.cliente!.observaciones = _observacionesCtrl.text.trim();
          widget.cliente!.direccion = _direccionCtrl.text.trim();
          widget.cliente!.apodo = _apodoCtrl.text.trim();
          widget.cliente!.referenciasDireccion = _referenciasDireccionCtrl.text.trim();
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

                    _buildLabel('Apellido Paterno'),
                    _buildTextField(
                      controller: _apPaternoCtrl,
                      hintText: 'Ej. Valdés',
                      icon: Icons.person_outline,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Apellido Materno'),
                    _buildTextField(
                      controller: _apMaternoCtrl,
                      hintText: 'Ej. Gómez',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Teléfono Móvil (Celular)'),
                    _buildTextField(
                      controller: _celularCtrl,
                      hintText: '+52 55 1234 5678',
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Teléfono Fijo'),
                    _buildTextField(
                      controller: _telefonoCtrl,
                      hintText: '55 9876 5432',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Correo Electrónico'),
                    _buildTextField(
                      controller: _correoCtrl,
                      hintText: 'alejandro@empresa.com',
                      icon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Observaciones'),
                    _buildTextField(
                      controller: _observacionesCtrl,
                      hintText: 'Información adicional...',
                      icon: Icons.notes,
                    ),
                    _buildLabel('Apodo'),
                    _buildTextField(
                      controller: _apodoCtrl,
                      hintText: 'Ej. Alex',
                      icon: Icons.person_pin,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Dirección'),
                    _buildTextField(
                      controller: _direccionCtrl,
                      hintText: 'Calle, Número, Colonia...',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Referencias de Dirección'),
                    _buildTextField(
                      controller: _referenciasDireccionCtrl,
                      hintText: 'Entre calles, fachada, etc.',
                      icon: Icons.map_outlined,
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
