import 'package:flutter/material.dart';
import '../models/producto_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'general_success_screen.dart';

class CarniceriaFormModal extends StatefulWidget {
  final Producto? producto;
  const CarniceriaFormModal({super.key, this.producto});

  @override
  State<CarniceriaFormModal> createState() => _CarniceriaFormModalState();
}

class _CarniceriaFormModalState extends State<CarniceriaFormModal> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _codigoCtrl = TextEditingController(); // Nuevo campo
  final TextEditingController _precioCtrl = TextEditingController();
  final TextEditingController _observacionesCtrl = TextEditingController();

  String _selectedUnidadVenta = 'kg';
  final List<String> _unidadesVenta = ['kg', 'gramo', 'pieza', 'paquete'];

  String _selectedCategoria = 'Res';
  final List<String> _categorias = ['Res', 'Cerdo', 'Cremería', 'Pollo', 'Otros'];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.producto != null) {
      _nombreCtrl.text = widget.producto!.nombre;
      _codigoCtrl.text = widget.producto!.codigo;
      _precioCtrl.text = widget.producto!.precio.toString();
      _observacionesCtrl.text = widget.producto!.observaciones;
      
      if (_unidadesVenta.contains(widget.producto!.unidadVenta)) {
        _selectedUnidadVenta = widget.producto!.unidadVenta;
      }
      
      if (_categorias.contains(widget.producto!.categoria)) {
        _selectedCategoria = widget.producto!.categoria;
      } else {
        _categorias.add(widget.producto!.categoria);
        _selectedCategoria = widget.producto!.categoria;
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _precioCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarProducto() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        if (widget.producto == null) {
          final nuevoProducto = Producto(
            nombre: _nombreCtrl.text.trim(),
            codigo: _codigoCtrl.text.trim(),
            precio: double.tryParse(_precioCtrl.text.trim()) ?? 0.0,
            observaciones: _observacionesCtrl.text.trim(),
            categoria: _selectedCategoria,
            unidadVenta: _selectedUnidadVenta,
            seccion: 'carniceria', // Fijo para carnicería
          );
          await _firebaseService.addProducto(nuevoProducto);
        } else {
          widget.producto!.nombre = _nombreCtrl.text.trim();
          widget.producto!.codigo = _codigoCtrl.text.trim();
          widget.producto!.precio = double.tryParse(_precioCtrl.text.trim()) ?? 0.0;
          widget.producto!.observaciones = _observacionesCtrl.text.trim();
          widget.producto!.categoria = _selectedCategoria;
          widget.producto!.unidadVenta = _selectedUnidadVenta;
          widget.producto!.seccion = 'carniceria'; // Asegurar que sea carniceria
          await _firebaseService.updateProducto(widget.producto!);
        }

        if (mounted) {
          Navigator.pop(context); // Cerrar modal
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GeneralSuccessScreen(
                title: widget.producto == null ? '¡Carnicería Creado!' : '¡Actualización Exitosa!',
                mainText: widget.producto == null ? 'Nuevo Corte / Producto' : 'Producto Actualizado',
                subtitle: 'El producto ${_nombreCtrl.text.trim()} ha sido guardado.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra superior
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
            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.producto == null ? 'Alta Carnicería' : 'Editar Carnicería',
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
            
            // Formulario
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Nombre del Producto / Corte'),
                            _buildTextField(
                              controller: _nombreCtrl,
                              hintText: 'Ej. Bistec de Res',
                              icon: Icons.set_meal_outlined,
                              isRequired: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Precio Base'),
                            _buildTextField(
                              controller: _precioCtrl,
                              hintText: '0.00',
                              icon: Icons.sell_outlined,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              isRequired: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
        
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Unidad de Venta'),
                            DropdownButtonFormField<String>(
                              value: _selectedUnidadVenta,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.scale, color: AppTheme.primary, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _unidadesVenta.map((String tipo) {
                                return DropdownMenuItem<String>(
                                  value: tipo,
                                  child: Text(tipo.toUpperCase(), style: const TextStyle(color: AppTheme.textDark)),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedUnidadVenta = newValue;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Categoría'),
                            DropdownButtonFormField<String>(
                              value: _selectedCategoria,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.category, color: AppTheme.primary, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _categorias.map((String cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Text(cat, style: const TextStyle(color: AppTheme.textDark)),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedCategoria = newValue;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Código Interno (Opcional)'),
                      _buildTextField(
                        controller: _codigoCtrl,
                        hintText: 'Ej. CAR-01',
                        icon: Icons.tag,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
        
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Observaciones (Opcional)'),
                      _buildTextField(
                        controller: _observacionesCtrl,
                        hintText: 'Ej. Corte delgado, con hueso, etc.',
                        icon: Icons.notes,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
        
                  _isSaving
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                      : ElevatedButton(
                          onPressed: _guardarProducto,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.producto == null ? 'Guardar Carnicería' : 'Actualizar Producto',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                            ],
                          ),
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
