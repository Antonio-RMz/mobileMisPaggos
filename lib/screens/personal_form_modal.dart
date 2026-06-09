import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  FirebaseService get _firebaseService => Provider.of<FirebaseService>(context, listen: false);

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();

  String _selectedRol = 'Repartidor';
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
      _activo = widget.personal!.activo;
    }
  }


  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
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
        } else {
          widget.personal!.nombre = _nombreCtrl.text.trim();
          widget.personal!.telefono = _telefonoCtrl.text.trim();
          widget.personal!.rol = _selectedRol;
          widget.personal!.activo = _activo;
          await _firebaseService.updatePersonal(widget.personal!);
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
                Text(widget.personal == null ? 'Alta de Repartidor' : 'Editar Repartidor', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
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
