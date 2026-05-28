import 'package:flutter/material.dart';
import '../models/personal_model.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'general_success_screen.dart';

class PersonalFormModal extends StatefulWidget {
  final Personal? personal;
  const PersonalFormModal({super.key, this.personal});

  @override
  State<PersonalFormModal> createState() => _PersonalFormModalState();
}

class _PersonalFormModalState extends State<PersonalFormModal> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  String _selectedRol = 'Empleado';
  final List<String> _roles = ['Empleado', 'Repartidor'];
  
  bool _activo = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.personal != null) {
      _nombreCtrl.text = widget.personal!.nombre;
      _telefonoCtrl.text = widget.personal!.telefono;
      _selectedRol = widget.personal!.rol;
      _activo = widget.personal!.activo;

      _cargarCuentaUsuario();
    }
  }

  Future<void> _cargarCuentaUsuario() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(widget.personal!.id).get();
      if (doc.exists && mounted) {
        setState(() {
          _usernameCtrl.text = doc.data()?['username'] ?? '';
          _passwordCtrl.text = doc.data()?['password'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user account: $e');
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarPersonal() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        if (widget.personal == null) {
          final nuevoPersonal = Personal(
            nombre: _nombreCtrl.text.trim(),
            telefono: _telefonoCtrl.text.trim(),
            rol: _selectedRol,
            activo: _activo,
          );
          String nuevoId = await _firebaseService.addPersonal(nuevoPersonal);
          
          if (nuevoId.isNotEmpty) {
            await _firebaseService.crearCuentaUsuario(
              personalId: nuevoId,
              username: _usernameCtrl.text.trim(),
              password: _passwordCtrl.text.trim(),
              rol: _selectedRol,
            );
          }
        } else {
          widget.personal!.nombre = _nombreCtrl.text.trim();
          widget.personal!.telefono = _telefonoCtrl.text.trim();
          widget.personal!.rol = _selectedRol;
          widget.personal!.activo = _activo;
          await _firebaseService.updatePersonal(widget.personal!);

          await _firebaseService.actualizarCuentaUsuario(
            personalId: widget.personal!.id,
            username: _usernameCtrl.text.trim(),
            password: _passwordCtrl.text.trim(),
            rol: _selectedRol,
          );
        }

        if (mounted) {
          Navigator.pop(context); // Cierra el modal
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GeneralSuccessScreen(
                title: widget.personal == null ? '¡Personal Creado!' : '¡Actualización Exitosa!',
                mainText: widget.personal == null ? 'Nuevo $_selectedRol' : 'Datos Actualizados',
                subtitle: 'El $_selectedRol ${_nombreCtrl.text.trim()} ha sido guardado.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16, left: 24, right: 24,
        bottom: bottomInset > 0 ? bottomInset + 24 : 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.personal == null ? 'Alta de Personal' : 'Editar Personal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLabel('Nombre Completo'),
                  _buildTextField(controller: _nombreCtrl, hintText: 'Ej. Juan Pérez', icon: Icons.person_outline, isRequired: true),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Teléfono'),
                            _buildTextField(controller: _telefonoCtrl, hintText: 'Ej. 5512345678', icon: Icons.phone_android, keyboardType: TextInputType.phone),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Rol'),
                            DropdownButtonFormField<String>(
                              value: _selectedRol,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.work_outline, color: AppTheme.primary, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedRol = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (widget.personal != null)
                    SwitchListTile(
                      title: const Text('Activo', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Si se inactiva, no aparecerá en las opciones de asignación.'),
                      value: _activo,
                      activeColor: AppTheme.primary,
                      onChanged: (val) => setState(() => _activo = val),
                      contentPadding: EdgeInsets.zero,
                    ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.vpn_key_outlined, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text('Cuenta de Acceso', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildLabel('Usuario'),
                        _buildTextField(controller: _usernameCtrl, hintText: 'Ej. rep_juan', icon: Icons.alternate_email, isRequired: true),
                        const SizedBox(height: 12),
                        _buildLabel('Contraseña'),
                        _buildTextField(controller: _passwordCtrl, hintText: 'Contraseña segura', icon: Icons.lock_outline, isRequired: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                      : ElevatedButton(
                          onPressed: _guardarPersonal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: Text(widget.personal == null ? 'Guardar' : 'Actualizar', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: AppTheme.textLight, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, required IconData icon, TextInputType keyboardType = TextInputType.text, bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) return 'Campo obligatorio';
        return null;
      },
    );
  }
}
