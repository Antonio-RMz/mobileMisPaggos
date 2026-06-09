import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/ticket_model.dart';

class PrinterService {
  BluetoothConnection? _connection;

  // UUID estándar para SPP
  // flutter_bluetooth_serial lo usa por defecto, pero lo mantenemos por referencia si es necesario
  
  /// Intenta conectarse a un dispositivo por su MAC Address
  Future<String> connect(String macAddress) async {
    try {
      // Cierra la conexión existente si hay una
      await disconnect();

      _connection = await BluetoothConnection.toAddress(macAddress);
      if (_connection?.isConnected ?? false) {
        return "OK";
      } else {
        return "No se pudo establecer la conexión.";
      }
    } catch (e) {
      print('Error conectando a la impresora: $e');
      return e.toString();
    }
  }

  /// Cierra la conexión actual
  Future<void> disconnect() async {
    if (_connection != null && _connection!.isConnected) {
      await _connection!.close();
      _connection = null;
    }
  }

  /// Envía un texto de prueba a la impresora usando TSPL
  Future<void> printTest({
    required double width,
    required double height,
    required double offsetX,
    required String text,
  }) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('La impresora no está conectada');
    }

    String tsplCommand = buildTsplCommand(
      width: width,
      height: height,
      offsetX: offsetX,
      data: text,
    );

    // Enviar comandos por Bluetooth SPP
    _connection!.output.add(Uint8List.fromList(utf8.encode(tsplCommand)));
    await _connection!.output.allSent;
  }

  /// Construye el comando TSPL
  String buildTsplCommand({
    required double width,
    required double height,
    required double offsetX,
    required String data,
  }) {
    String safeData = _removeAccents(data);
    StringBuffer buffer = StringBuffer();
    
    // Configuración de la etiqueta (Medidas en mm)
    buffer.writeln('SIZE $width mm, $height mm');
    // Gap entre etiquetas (asumimos 2mm estándar para térmicas)
    buffer.writeln('GAP 2 mm, 0 mm');
    // Offset o margen
    buffer.writeln('REFERENCE $offsetX, 0');
    // Limpiar buffer de imagen
    buffer.writeln('CLS');
    // Dibujar texto en X: 10, Y: 10, Fuente "3", Rotación 0, Multiplicador X y Y en 1
    buffer.writeln('TEXT 10,10,"3",0,1,1,"$safeData"');
    // Imprimir 1 copia
    buffer.writeln('PRINT 1');
    
    return buffer.toString();
  }

  /// Envía un ticket de entrega a la impresora
  Future<void> printDeliveryTicket({
    required double width,
    required double height,
    required double offsetX,
    required Ticket ticket,
  }) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('La impresora no está conectada');
    }

    Uint8List payload = await _buildDeliveryTicketTspl(
      width: width,
      height: height,
      offsetX: offsetX,
      ticket: ticket,
    );

    _connection!.output.add(payload);
    await _connection!.output.allSent;
  }

  /// Construye el comando TSPL para el ticket de entrega con soporte binario (imagen)
  Future<Uint8List> _buildDeliveryTicketTspl({
    required double width,
    required double height,
    required double offsetX,
    required Ticket ticket,
  }) async {
    List<int> bytes = [];
    StringBuffer buffer = StringBuffer();
    
    buffer.writeln('SIZE $width mm, $height mm');
    buffer.writeln('GAP 2 mm, 0 mm');
    buffer.writeln('REFERENCE $offsetX, 0');
    buffer.writeln('CLS');
    
    // Título o Logo
    buffer.writeln('TEXT 10,10,"2",0,1,1,"TK: ${ticket.folio}"');
    
    String safeCliente = _removeAccents(ticket.clienteNombre);
    buffer.writeln('TEXT 10,40,"2",0,1,1,"CLI: $safeCliente"');
    
    String repartidor = ticket.repartidorNombre ?? 'No asignado';
    String safeRepartidor = _removeAccents(repartidor);
    buffer.writeln('TEXT 10,70,"2",0,1,1,"REP: $safeRepartidor"');
    
    // Total de la Venta
    String total = "\$${ticket.totalVenta.toStringAsFixed(2)}";
    buffer.writeln('TEXT 10,100,"2",0,1,1,"TOTAL: $total"');
    
    bytes.addAll(utf8.encode(buffer.toString()));
    buffer.clear();

    // Intentar imprimir el ícono
    try {
      final ByteData data = await rootBundle.load('assets/images/iconoEtiqueta.png');
      final Uint8List imgBytes = data.buffer.asUint8List();
      img.Image? decodedImage = img.decodeImage(imgBytes);
      
      if (decodedImage != null) {
        // Redimensionar a aprox 15mm x 15mm. A 203 DPI, 15mm son ~120 pixeles.
        img.Image resized = img.copyResize(decodedImage, width: 120, height: 120);
        
        int widthBytes = (resized.width + 7) ~/ 8;
        int heightDots = resized.height;
        
        // Lo ponemos en la esquina derecha, más grande y un poco más a la izquierda (X=260, Y=70)
        String bitmapCmd = 'BITMAP 260,70,$widthBytes,$heightDots,0,';
        bytes.addAll(utf8.encode(bitmapCmd));
        
        // Generar bitmap data (1 bit por pixel, MSB a LSB)
        for (int y = 0; y < heightDots; y++) {
          for (int xByte = 0; xByte < widthBytes; xByte++) {
            int byteVal = 0;
            for (int bit = 0; bit < 8; bit++) {
              int x = xByte * 8 + bit;
              bool isDark = false;
              if (x < resized.width) {
                img.Pixel pixel = resized.getPixel(x, y);
                num lum = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
                if (lum < 180 && pixel.a > 128) {
                  isDark = true;
                }
              }
              
              if (!isDark) {
                byteVal |= (1 << (7 - bit));
              }
            }
            bytes.add(byteVal);
          }
        }
        bytes.addAll(utf8.encode('\r\n'));
      }
    } catch (e) {
      print('Error procesando el iconoEtiqueta: $e');
    }

    // Mensaje de agradecimiento regresado a Y=150 para que no se salga de la etiqueta de 25mm de alto
    buffer.writeln('TEXT 10,150,"1",0,1,1,"¡AGRADECEMOS TU COMPRA!"');
    
    buffer.writeln('PRINT 1');
    bytes.addAll(utf8.encode(buffer.toString()));
    
    return Uint8List.fromList(bytes);
  }

  /// Remueve acentos y caracteres especiales no soportados por la impresora
  String _removeAccents(String str) {
    var withDia = 'áéíóúÁÉÍÓÚñÑüÜ';
    var withoutDia = 'aeiouAEIOUnNuU';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  /// Escanea dispositivos vinculados (Paired) y los filtra por nombre
  Future<List<BluetoothDevice>> getPairedPrinters() async {
    try {
      List<BluetoothDevice> pairedDevices = 
          await FlutterBluetoothSerial.instance.getBondedDevices();
          
      return pairedDevices.where((device) {
        String name = (device.name ?? '').toUpperCase();
        return name.contains('XP-') || 
               name.contains('365') || 
               name.contains('PRINTER');
      }).toList();
    } catch (e) {
      print('Error escaneando dispositivos: $e');
      return [];
    }
  }

  bool get isConnected => _connection?.isConnected ?? false;
}
