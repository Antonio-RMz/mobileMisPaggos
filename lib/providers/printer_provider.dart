import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/printer_service.dart';

class PrinterProvider extends ChangeNotifier {
  final PrinterService _printerService = PrinterService();
  
  // Variables de configuración de la etiqueta
  double _etiquetaAncho = 50.0;
  double _etiquetaAlto = 25.0;
  double _offsetX = 4.0;
  
  // Estado de la conexión
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _savedMacAddress;
  BluetoothDevice? _connectedDevice;

  // Dispositivos escaneados
  List<BluetoothDevice> _pairedDevices = [];

  // Getters
  double get etiquetaAncho => _etiquetaAncho;
  double get etiquetaAlto => _etiquetaAlto;
  double get offsetX => _offsetX;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get savedMacAddress => _savedMacAddress;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get pairedDevices => _pairedDevices;

  PrinterProvider() {
    _loadSavedSettings();
  }

  /// Carga la configuración guardada en SharedPreferences
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _etiquetaAncho = prefs.getDouble('printer_width') ?? 50.0;
    _etiquetaAlto = prefs.getDouble('printer_height') ?? 25.0;
    _offsetX = prefs.getDouble('printer_offset_x') ?? 4.0;
    _savedMacAddress = prefs.getString('printer_mac_address');
    notifyListeners();
    
    // Auto-conectar después de cargar la MAC
    if (_savedMacAddress != null && _savedMacAddress!.isNotEmpty) {
      autoConnect();
    }
  }

  /// Guarda una nueva configuración de tamaño
  Future<void> updateSettings({
    required double width,
    required double height,
    required double offset,
  }) async {
    _etiquetaAncho = width;
    _etiquetaAlto = height;
    _offsetX = offset;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('printer_width', width);
    await prefs.setDouble('printer_height', height);
    await prefs.setDouble('printer_offset_x', offset);
    
    notifyListeners();
  }

  /// Escanea dispositivos emparejados
  Future<void> scanDevices() async {
    _pairedDevices = await _printerService.getPairedPrinters();
    notifyListeners();
  }

  /// Conecta a un dispositivo específico y guarda su MAC
  Future<String> connectToDevice(BluetoothDevice device) async {
    _isConnecting = true;
    notifyListeners();

    String result = await _printerService.connect(device.address);

    _isConnected = (result == "OK");
    _isConnecting = false;
    
    if (_isConnected) {
      _connectedDevice = device;
      _savedMacAddress = device.address;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_mac_address', device.address);
    }

    notifyListeners();
    return result;
  }

  Future<void> autoConnect() async {
    if (_savedMacAddress != null && _savedMacAddress!.isNotEmpty) {
      _isConnecting = true;
      notifyListeners();

      try {
        String result = await _printerService.connect(_savedMacAddress!);
        _isConnected = (result == "OK");
      } catch (e) {
        _isConnected = false;
      }
      
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Desconecta el dispositivo actual
  Future<void> disconnect() async {
    await _printerService.disconnect();
    _isConnected = false;
    _connectedDevice = null;
    notifyListeners();
  }

  /// Imprime un texto de prueba
  Future<void> printTest(String text) async {
    if (!_isConnected) return;
    
    await _printerService.printTest(
      width: _etiquetaAncho,
      height: _etiquetaAlto,
      offsetX: _offsetX,
      text: text,
    );
  }

  /// Imprime un ticket de entrega (Venta)
  Future<void> printDeliveryTicket(dynamic ticket) async {
    if (!_isConnected) return;

    await _printerService.printDeliveryTicket(
      width: _etiquetaAncho,
      height: _etiquetaAlto,
      offsetX: _offsetX,
      ticket: ticket,
    );
  }
}
