import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../providers/printer_provider.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _offsetController;

  @override
  void initState() {
    super.initState();
    final printerProvider = Provider.of<PrinterProvider>(context, listen: false);
    _widthController = TextEditingController(text: printerProvider.etiquetaAncho.toString());
    _heightController = TextEditingController(text: printerProvider.etiquetaAlto.toString());
    _offsetController = TextEditingController(text: printerProvider.offsetX.toString());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (printerProvider.pairedDevices.isEmpty) {
        _requestPermissionsAndScan();
      }
    });
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionsAndScan() async {
    // Solicitar permisos de Bluetooth y Ubicación necesarios en Android
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    if (allGranted) {
      if (mounted) {
        Provider.of<PrinterProvider>(context, listen: false).scanDevices();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se requieren permisos de Bluetooth para buscar la impresora')),
        );
      }
    }
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      final double width = double.parse(_widthController.text);
      final double height = double.parse(_heightController.text);
      final double offset = double.parse(_offsetController.text);

      Provider.of<PrinterProvider>(context, listen: false)
          .updateSettings(width: width, height: height, offset: offset);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerProvider = Provider.of<PrinterProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Impresora'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de Dispositivos Bluetooth
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Dispositivos Bluetooth',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _requestPermissionsAndScan,
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Escanear'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (printerProvider.pairedDevices.isEmpty)
                      const Text('No se encontraron dispositivos vinculados. Asegúrate de vincular la impresora en los ajustes de Bluetooth de Android.')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: printerProvider.pairedDevices.length,
                        itemBuilder: (context, index) {
                          BluetoothDevice device = printerProvider.pairedDevices[index];
                          bool isThisDeviceConnected = printerProvider.isConnected && printerProvider.savedMacAddress == device.address;

                          return ListTile(
                            leading: const Icon(Icons.print),
                            title: Text(device.name ?? 'Dispositivo Desconocido'),
                            subtitle: Text(device.address),
                            trailing: isThisDeviceConnected
                                ? const Chip(
                                    label: Text('Conectado', style: TextStyle(fontSize: 12)),
                                    backgroundColor: Colors.green,
                                    labelStyle: TextStyle(color: Colors.white),
                                  )
                                : ElevatedButton(
                                      onPressed: printerProvider.isConnecting
                                          ? null
                                          : () async {
                                              String result = await printerProvider.connectToDevice(device);
                                              bool success = (result == "OK");
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(success ? 'Conectado a ${device.name}' : 'Error: $result'),
                                                    backgroundColor: success ? Colors.green : Colors.red,
                                                    duration: const Duration(seconds: 4),
                                                  ),
                                                );
                                              }
                                            },
                                    child: const Text('Conectar'),
                                  ),
                          );
                        },
                      ),
                    if (printerProvider.isConnected) ...[
                      const Divider(),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            printerProvider.disconnect();
                          },
                          icon: const Icon(Icons.bluetooth_disabled, color: Colors.red),
                          label: const Text('Desconectar', style: TextStyle(color: Colors.red)),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Sección de Configuración TSPL
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parámetros de la Etiqueta (TSPL)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _widthController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Ancho (mm)',
                                border: OutlineInputBorder(),
                                suffixText: 'mm',
                              ),
                              validator: (value) => value!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Alto (mm)',
                                border: OutlineInputBorder(),
                                suffixText: 'mm',
                              ),
                              validator: (value) => value!.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _offsetController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Desplazamiento (Offset X)',
                          border: OutlineInputBorder(),
                          suffixText: 'mm',
                          helperText: 'Ajuste fino para alinear la impresión al centro.',
                        ),
                        validator: (value) => value!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar Parámetros'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botón de Prueba de Impresión
            ElevatedButton.icon(
              onPressed: printerProvider.isConnected
                  ? () {
                      printerProvider.printTest("HOLA XPRINTER!");
                    }
                  : null,
              icon: const Icon(Icons.print),
              label: const Text('Imprimir Etiqueta de Prueba'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
