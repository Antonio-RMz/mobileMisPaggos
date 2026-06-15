import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/personal_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'personal_form_modal.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../utils/overlay_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/string_utils.dart';

class PersonalListScreen extends StatefulWidget {
  const PersonalListScreen({super.key});

  @override
  State<PersonalListScreen> createState() => _PersonalListScreenState();
}

class _PersonalListScreenState extends State<PersonalListScreen> {
  FirebaseService get _firebaseService => Provider.of<FirebaseService>(context, listen: false);
  String _filtroRol = 'Todos';

  void _mostrarFormulario([Personal? personal]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PersonalFormModal(personal: personal),
    );
  }

  Future<void> _eliminarPersonal(Personal p) async {
    bool pinValid = await _mostrarDialogoPIN(context);
    if (!pinValid) return;

    if (!mounted) return;
    _firebaseService.deletePersonal(p.id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado exitosamente')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Gestión de Repartidores'),
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: AppTheme.primary),
            onSelected: (val) => setState(() => _filtroRol = val),
            itemBuilder: (context) => ['Todos', 'Empleado', 'Repartidor'].map((rol) {
              return PopupMenuItem(value: rol, child: Text(rol));
            }).toList(),
          ),
        ],
      ),
      body: StreamBuilder<List<Personal>>(
        stream: _firebaseService.getPersonalStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var personalList = snapshot.data!;
          if (_filtroRol != 'Todos') {
            personalList = personalList.where((p) => p.rol == _filtroRol).toList();
          }

          if (personalList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No hay personal registrado', style: TextStyle(color: AppTheme.textLight)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: personalList.length,
            itemBuilder: (context, index) {
              final p = personalList[index];
              return Slidable(
                key: ValueKey(p.id),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _mostrarFormulario(p),
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'Editar',
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                    ),
                    SlidableAction(
                      onPressed: (context) => _eliminarPersonal(p),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Borrar',
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                    ),
                  ],
                ),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: p.activo ? AppTheme.primary.withOpacity(0.1) : Colors.grey[200],
                      child: Icon(
                        p.rol == 'Repartidor' ? Icons.delivery_dining : Icons.person,
                        color: p.activo ? AppTheme.primary : Colors.grey,
                      ),
                    ),
                    title: Text(p.nombre, style: TextStyle(fontWeight: FontWeight.bold, decoration: p.activo ? null : TextDecoration.lineThrough)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(p.rol, style: TextStyle(color: p.rol == 'Repartidor' ? Colors.orange[800] : AppTheme.textLight, fontWeight: FontWeight.w600)),
                        if (p.telefono.isNotEmpty) Text('Tel: ${p.telefono}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: p.activo 
                      ? const Chip(label: Text('Activo', style: TextStyle(fontSize: 10, color: Colors.green)), backgroundColor: Color(0xFFE8F5E9), padding: EdgeInsets.zero)
                      : const Chip(label: Text('Inactivo', style: TextStyle(fontSize: 10, color: Colors.red)), backgroundColor: Color(0xFFFFEBEE), padding: EdgeInsets.zero),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: _mostrarFormulario,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Nuevo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<bool> _mostrarDialogoPIN(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final masterPin = prefs.getString('master_pin');

    if (masterPin == null || masterPin.isEmpty) {
      // Si no hay PIN configurado, permitir acceso
      return true;
    }

    String inputPin = '';
    bool pinCorrecto = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Se requiere PIN de Seguridad', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        content: TextField(
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          maxLength: 4,
          onChanged: (val) => inputPin = val,
          decoration: InputDecoration(
            hintText: '****',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.lock),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (inputPin == masterPin) {
                pinCorrecto = true;
                Navigator.pop(ctx);
              } else {
                OverlayHelper.showError(ctx, message: 'PIN incorrecto');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return pinCorrecto;
  }
}
