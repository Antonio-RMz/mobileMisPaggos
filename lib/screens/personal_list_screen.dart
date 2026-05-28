import 'package:flutter/material.dart';
import '../models/personal_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'personal_form_modal.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class PersonalListScreen extends StatefulWidget {
  const PersonalListScreen({super.key});

  @override
  State<PersonalListScreen> createState() => _PersonalListScreenState();
}

class _PersonalListScreenState extends State<PersonalListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _filtroRol = 'Todos';

  void _mostrarFormulario([Personal? personal]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PersonalFormModal(personal: personal),
    );
  }

  void _confirmarEliminacion(Personal personal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Personal'),
        content: Text('¿Estás seguro de que deseas eliminar a ${personal.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _firebaseService.deletePersonal(personal.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado exitosamente')));
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Gestión de Personal', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
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
                      onPressed: (context) => _confirmarEliminacion(p),
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
}
