import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/ticket_model.dart';
import '../models/abono_model.dart';
import '../models/gasto_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfReportService {
  static final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  static Future<void> generateCorteGeneralPdf(BuildContext context, List<Ticket> tickets, List<Abono> abonos, List<Gasto> gastos, String dateRangeLabel) async {
    final pdf = pw.Document();
    
    // Cargar icono
    final ByteData bytes = await rootBundle.load('assets/images/iconoInicio.png');
    final Uint8List byteList = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(byteList);

    double totalGeneral = 0;
    int totalTickets = tickets.length;
    double cobrado = 0;
    double pendiente = 0;
    double totalDomicilio = 0;
    double totalLocal = 0;
    double totalEfectivo = 0;
    double totalTransferencia = 0;

    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado') {
        totalGeneral += t.totalVenta;
        pendiente += t.saldoRestante;
        cobrado += (t.totalVenta - t.saldoRestante);
        if (t.tipoEntrega == 'Domicilio') {
          totalDomicilio += t.totalVenta;
        } else {
          totalLocal += t.totalVenta;
        }
        if (t.metodoPago == 'Transferencia') {
          totalTransferencia += t.totalVenta;
        } else {
          totalEfectivo += t.totalVenta;
        }
      }
    }

    double totalAbonosExtra = 0;
    List<Abono> abonosExtra = [];
    for (var a in abonos) {
      if (a.ticketId != 'ENTREGA_REPARTIDOR' && a.ticketId != 'ENTREGA_GENERAL') {
        bool isTicketInList = tickets.any((t) => t.id == a.ticketId);
        if (!isTicketInList) {
          totalAbonosExtra += a.monto;
          abonosExtra.add(a);
        }
      }
    }
    
    double totalGastos = 0;
    for (var g in gastos) {
      totalGastos += g.monto;
    }

    totalEfectivo += totalAbonosExtra; // El efectivo total en caja aumenta con los abonos cobrados
    totalEfectivo -= totalGastos; // Se descuentan los gastos del efectivo en caja

    Map<String, Ticket> fetchedTickets = {};
    for (var a in abonosExtra) {
      if (a.ticketId != null && a.ticketId != 'ENTREGA_REPARTIDOR' && a.ticketId != 'ENTREGA_GENERAL') {
        if (!fetchedTickets.containsKey(a.ticketId)) {
          try {
            final doc = await FirebaseFirestore.instance.collection('tickets').doc(a.ticketId).get();
            if (doc.exists && doc.data() != null) {
              fetchedTickets[a.ticketId!] = Ticket.fromMap(doc.id, doc.data()!);
            }
          } catch (e) {
            // Ignorar error individual
          }
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader('Corte de Caja General', dateRangeLabel, image),
          pw.SizedBox(height: 20),
          _buildSummaryCard([
            'Ventas Totales: ${_currencyFormat.format(totalGeneral)}',
            'Cobrado: ${_currencyFormat.format(cobrado)}',
            'Pendiente por Cobrar: ${_currencyFormat.format(pendiente)}',
            'Ventas en Sucursal: ${_currencyFormat.format(totalLocal)}',
            'Ventas a Domicilio: ${_currencyFormat.format(totalDomicilio)}',
            'En Transferencia: ${_currencyFormat.format(totalTransferencia)}',
            'Abonos Anteriores: ${_currencyFormat.format(totalAbonosExtra)}',
            'Gastos (Salidas): -${_currencyFormat.format(totalGastos)}',
            'Efectivo Final en Caja: ${_currencyFormat.format(totalEfectivo)}',
            'Tickets Generados: $totalTickets',
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Detalle de Ventas', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildTicketsTable(tickets),
          if (abonosExtra.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Abonos Recibidos (Anteriores)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
            pw.SizedBox(height: 10),
            _buildAbonosTable(abonosExtra, fetchedTickets: fetchedTickets),
          ],
          if (gastos.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Gastos Registrados (Salidas de Dinero)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
            pw.SizedBox(height: 10),
            _buildGastosTable(gastos),
          ]
        ],
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Vista Previa del Reporte')),
          body: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: PdfPreview(
              build: (format) async => pdf.save(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: 'corteG-${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> generateCorteRepartidorPdf(BuildContext context, String repartidorNombre, List<Ticket> tickets, List<Abono> abonos, String dateRangeLabel) async {
    final pdf = pw.Document();
    
    // Cargar icono
    final ByteData bytes = await rootBundle.load('assets/images/iconoInicio.png');
    final Uint8List byteList = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(byteList);

    double totalAsignado = 0;
    double totalEntregado = 0;
    double totalPendiente = 0;
    double totalEfectivo = 0;
    double totalTransferencia = 0;
    int countCompletados = 0;
    int countPendientes = 0;
    int countCancelados = 0;

    for (var t in tickets) {
      if (t.estadoEntrega == 'Cancelado') {
        countCancelados++;
      } else {
        totalAsignado += t.totalVenta;
        if (t.pagoRepartidorConfirmado) {
          countCompletados++;
          totalEntregado += t.totalVenta;
          if (t.metodoPago == 'Transferencia') {
            totalTransferencia += t.totalVenta;
          } else {
            totalEfectivo += t.totalVenta;
          }
        } else {
          countPendientes++;
          totalPendiente += t.totalVenta;
        }
      }
    }

    double abonosCobrados = 0;
    List<Abono> abonosExtra = [];
    for (var a in abonos) {
      if (a.ticketId != 'ENTREGA_REPARTIDOR' && a.ticketId != 'ENTREGA_GENERAL') {
        bool isTicketInList = tickets.any((t) => t.id == a.ticketId);
        if (!isTicketInList && (a.repartidorId == repartidorNombre || a.createBy == repartidorNombre)) {
          abonosCobrados += a.monto;
          abonosExtra.add(a);
        }
      }
    }
    
    // Ya no sumamos ni restamos entregasCaja de totalPendiente o totalEntregado, 
    // porque el ciclo de los tickets ya procesa totalVenta correctamente.

    Map<String, Ticket> fetchedTickets = {};
    for (var a in abonosExtra) {
      if (a.ticketId != null && a.ticketId != 'ENTREGA_REPARTIDOR' && a.ticketId != 'ENTREGA_GENERAL') {
        if (!fetchedTickets.containsKey(a.ticketId)) {
          try {
            final doc = await FirebaseFirestore.instance.collection('tickets').doc(a.ticketId).get();
            if (doc.exists && doc.data() != null) {
              fetchedTickets[a.ticketId!] = Ticket.fromMap(doc.id, doc.data()!);
            }
          } catch (e) {
            // Ignorar error individual
          }
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader('Corte de Caja - Repartidor', dateRangeLabel, image),
          pw.SizedBox(height: 10),
          pw.Text('Repartidor: $repartidorNombre', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 20),
          _buildSummaryCard([
            'Total: ${_currencyFormat.format(totalAsignado)}',
            'Entregó a Caja: ${_currencyFormat.format(totalEntregado)}',
            'Debe a Caja: ${_currencyFormat.format(totalPendiente)}',
            'Recibido en Efectivo: ${_currencyFormat.format(totalEfectivo)}',
            'Recibido en Transferencia: ${_currencyFormat.format(totalTransferencia)}',
            'Pedidos Entregados: $countCompletados',
            'Pedidos Cancelados: $countCancelados',
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Detalle de Pedidos', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildRepartidorTicketsTable(tickets),
          if (abonosExtra.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Abonos Cobrados (Anteriores)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
            pw.SizedBox(height: 10),
            _buildAbonosTable(abonosExtra, fetchedTickets: fetchedTickets),
          ]
        ],
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Vista Previa del Reporte')),
          body: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: PdfPreview(
              build: (format) async => pdf.save(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: 'corteR-$repartidorNombre-${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildHeader(String title, String subtitle, pw.MemoryImage image) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 9,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Carnicería Doriss', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                  pw.SizedBox(height: 4),
                  pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                  pw.SizedBox(height: 4),
                  pw.Text('Rango: $subtitle', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('Generado el: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildSummaryCard(List<String> lines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Wrap(
        spacing: 24,
        runSpacing: 8,
        children: lines.map((l) => pw.Text(l, style: pw.TextStyle(fontSize: 13, fontWeight: l.contains('Total') ? pw.FontWeight.bold : pw.FontWeight.normal))).toList(),
      ),
    );
  }

  static pw.Widget _buildTicketsTable(List<Ticket> tickets) {
    double sum = 0;
    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado') sum += t.totalVenta;
    }
    
    final data = List<List<dynamic>>.generate(tickets.length, (index) {
      final t = tickets[index];
      String estado = t.estadoEntrega == 'Cancelado' ? 'Cancelado' : ((t.estadoEntrega == 'Entregado' || t.pagoRepartidorConfirmado) ? 'Entregado' : 'Pendiente');
      String repartidor = t.repartidorNombre?.isNotEmpty == true ? t.repartidorNombre! : '-';
      if (repartidor.contains('Sucursal')) repartidor = 'Sucursal';
      
      final fechaStr = t.createAt != null ? _dateFormat.format(t.createAt!.toDate()) : '-';
      
      String fechaPagoStr = '-';
      if (t.pagoRepartidorConfirmado && t.updateAt != null) {
        fechaPagoStr = DateFormat('dd/MM HH:mm').format(t.updateAt!.toDate());
      }
      String cobradorStr = t.cobradoPor != null ? t.cobradoPor! : '-';
      String creoStr = t.createBy != null ? t.createBy! : '-';

      return [
        t.folio.isNotEmpty ? t.folio : 'N/A',
        fechaStr,
        t.clienteNombre,
        t.tipoEntrega,
        t.metodoPago,
        estado,
        repartidor,
        fechaPagoStr,
        _currencyFormat.format(t.totalVenta),
      ];
    });

    data.add(['', '', '', '', '', '', '', 'TOTAL:', _currencyFormat.format(sum)]);

    return pw.TableHelper.fromTextArray(
      headers: ['Folio', 'Fecha/Hora', 'Cliente', 'Tipo', 'Pago', 'Estado', 'Repartió', 'Fecha Cobro', 'Total'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
    );
  }

  static pw.Widget _buildRepartidorTicketsTable(List<Ticket> tickets) {
    double sum = 0;
    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado') sum += t.totalVenta;
    }

    final data = tickets.map((t) {
      String estado = t.estadoEntrega == 'Cancelado' ? 'Cancelado' : ((t.estadoEntrega == 'Entregado' || t.pagoRepartidorConfirmado) ? 'Entregado' : 'Pendiente');
      String pagoStr = t.pagoRepartidorConfirmado ? t.metodoPago : 'Pendiente';
      if (t.estadoEntrega == 'Cancelado') pagoStr = '-';
      final fechaStr = t.createAt != null ? _dateFormat.format(t.createAt!.toDate()) : '-';
      
      String fechaPagoStr = '-';
      if (t.pagoRepartidorConfirmado && t.updateAt != null) {
        fechaPagoStr = DateFormat('dd/MM HH:mm').format(t.updateAt!.toDate());
      }
      String cobradorStr = t.cobradoPor != null ? t.cobradoPor! : '-';
      String creoStr = t.createBy != null ? t.createBy! : '-';

      return [
        t.folio.isNotEmpty ? t.folio : 'N/A',
        fechaStr,
        t.clienteNombre,
        estado,
        pagoStr,
        _currencyFormat.format(t.totalVenta),
      ];
    }).toList();

    data.add(['', '', '', '', 'TOTAL:', _currencyFormat.format(sum)]);

    return pw.TableHelper.fromTextArray(
      headers: ['Folio', 'Fecha/Hora', 'Cliente', 'Estado', 'Pago', 'Total'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
    );
  }

  static pw.Widget _buildAbonosTable(List<Abono> abonos, {Map<String, Ticket> fetchedTickets = const {}}) {
    final data = List<List<dynamic>>.generate(abonos.length, (index) {
      final a = abonos[index];
      final fechaStr = a.createAt != null ? _dateFormat.format(a.createAt!.toDate()) : '-';
      String origen = a.createBy;
      if (a.repartidorId != null && a.repartidorId!.isNotEmpty) {
         origen = a.repartidorId!;
      }
      
      String cliente = a.clienteId;
      String folio = a.ticketId ?? 'General';
      String saldo = '-';

      if (a.ticketId != null && fetchedTickets.containsKey(a.ticketId)) {
        final t = fetchedTickets[a.ticketId]!;
        cliente = t.clienteNombre;
        folio = t.folio.isNotEmpty ? t.folio : a.ticketId!;
        saldo = _currencyFormat.format(t.saldoRestante);
      }

      return [
        fechaStr,
        cliente,
        folio,
        origen,
        saldo,
        _currencyFormat.format(a.monto),
      ];
    });

    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Cliente', 'Folio / ID', 'Cobrado Por', 'Saldo Pend.', 'Abonó'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  static pw.Widget _buildGastosTable(List<Gasto> gastos) {
    final data = List<List<dynamic>>.generate(gastos.length, (index) {
      final g = gastos[index];
      final fechaStr = g.fecha != null ? _dateFormat.format(g.fecha!.toDate()) : '-';

      return [
        fechaStr,
        g.concepto,
        g.createBy,
        '- ${_currencyFormat.format(g.monto)}',
      ];
    });

    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Concepto', 'Registrado Por', 'Monto Retirado'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  static Future<void> generateProductosVendidosPdf(BuildContext context, List<Ticket> tickets, String dateRangeLabel) async {
    final pdf = pw.Document();

    final ByteData bytes = await rootBundle.load('assets/images/iconoInicio.png');
    final Uint8List byteList = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(byteList);

    Map<String, double> contCarnes = {};
    Map<String, double> contCatalogo = {};

    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado') {
        for (var item in t.productos) {
          if (item.seccion == 'carniceria') {
            contCarnes[item.nombre] = (contCarnes[item.nombre] ?? 0.0) + item.cantidad;
          } else {
            contCatalogo[item.nombre] = (contCatalogo[item.nombre] ?? 0.0) + item.cantidad;
          }
        }
      }
    }

    var listCarnes = contCarnes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    var listCatalogo = contCatalogo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final data = <List<String>>[];
    for (var entry in listCarnes) {
      data.add([entry.key, 'Carnicería', '${entry.value.toStringAsFixed(1)} kg']);
    }
    for (var entry in listCatalogo) {
      data.add([entry.key, 'Catálogo', '${entry.value.toInt()} pzas']);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader('Reporte de Productos Vendidos', dateRangeLabel, image),
            pw.SizedBox(height: 20),
            if (data.isEmpty)
              pw.Text('No se encontraron productos vendidos en este periodo.', style: pw.TextStyle(fontSize: 14))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Producto', 'Sección', 'Cantidad Vendida'],
                data: data,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 12),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 11),
                cellAlignment: pw.Alignment.centerLeft,
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                },
              ),
          ];
        },
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Vista Previa del Reporte')),
          body: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: PdfPreview(
              build: (format) async => pdf.save(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: 'productosVendidos-${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> generateReporteDeudoresPdf(BuildContext context, List<Ticket> tickets, List<Abono> abonos) async {
    final pdf = pw.Document();
    
    // Cargar icono
    final ByteData bytes = await rootBundle.load('assets/images/iconoInicio.png');
    final Uint8List byteList = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(byteList);

    Map<String, List<Ticket>> ticketsByClient = {};
    for (var t in tickets) {
      if (!ticketsByClient.containsKey(t.clienteId)) ticketsByClient[t.clienteId] = [];
      ticketsByClient[t.clienteId]!.add(t);
    }

    List<_DeudorData> deudores = [];

    for (var entry in ticketsByClient.entries) {
      String clienteId = entry.key;
      String clienteNombre = entry.value.first.clienteNombre;
      double deuda = 0;
      List<String> itemsDesc = [];
      Set<String> categorias = {};
      DateTime? oldestTicketDate;

      for (var t in entry.value) {
        deuda += t.saldoRestante;
        if (t.fecha != null) {
          final tDate = t.fecha!.toDate();
          if (oldestTicketDate == null || tDate.isBefore(oldestTicketDate)) {
            oldestTicketDate = tDate;
          }
        }
        for (var item in t.productos) {
          itemsDesc.add(item.descripcionAmigable);
          if (item.seccion.isNotEmpty) categorias.add(item.seccion);
        }
      }

      DateTime? lastPaymentDate;
      for (var a in abonos) {
        if (a.clienteId == clienteId) {
          if (a.fecha != null) {
            final aDate = a.fecha!.toDate();
            if (lastPaymentDate == null || aDate.isAfter(lastPaymentDate)) {
              lastPaymentDate = aDate;
            }
          }
        }
      }

      DateTime referenceDate = lastPaymentDate ?? oldestTicketDate ?? DateTime.now();
      
      // Tomar hasta 5 productos para no saturar la tabla
      String productosResumen = itemsDesc.take(5).join(', ');
      if (itemsDesc.length > 5) productosResumen += '...';

      deudores.add(_DeudorData(
        clienteNombre: clienteNombre,
        deudaTotal: deuda,
        fechaReferencia: referenceDate,
        categoria: categorias.isEmpty ? 'General' : categorias.join(', '),
        productos: productosResumen,
      ));
    }

    // Ordenar: el que lleva más tiempo sin pagar (fecha más antigua) va primero.
    deudores.sort((a, b) => a.fechaReferencia.compareTo(b.fechaReferencia));

    double totalDeudaGlobal = 0;
    for (var d in deudores) {
      totalDeudaGlobal += d.deudaTotal;
    }

    // Dividir en chunks para paginación si hay muchos deudores
    final int itemsPerPage = 25;
    for (int i = 0; i < deudores.length; i += itemsPerPage) {
      final chunk = deudores.skip(i).take(itemsPerPage).toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context contextPdf) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (i == 0) _buildHeader('Reporte de Deudores', 'Ordenado por tiempo sin abono', image),
                if (i > 0) pw.Text('Reporte de Deudores (Continuación)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                if (i == 0)
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('Deuda Global Pendiente: ${_currencyFormat.format(totalDeudaGlobal)}', 
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                  ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headers: ['Cliente', 'Categoría', 'Último Abono / Compra', 'Productos', 'Deuda'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: chunk.map((d) {
                    return [
                      d.clienteNombre,
                      d.categoria,
                      _dateFormat.format(d.fechaReferencia),
                      d.productos,
                      _currencyFormat.format(d.deudaTotal),
                    ];
                  }).toList(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(3),
                    4: const pw.FlexColumnWidth(1.5),
                  },
                ),
              ],
            );
          },
        ),
      );
    }

    if (deudores.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context contextPdf) {
            return pw.Column(
              children: [
                _buildHeader('Reporte de Deudores', '', image),
                pw.SizedBox(height: 20),
                pw.Center(child: pw.Text('No hay clientes con deuda pendiente.')),
              ],
            );
          },
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Vista Previa del Reporte')),
          body: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: PdfPreview(
              build: (format) async => pdf.save(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: 'ReporteDeudores-${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
            ),
          ),
        ),
      ),
    );
  }
}

class _DeudorData {
  final String clienteNombre;
  final double deudaTotal;
  final DateTime fechaReferencia; 
  final String categoria;
  final String productos;

  _DeudorData({
    required this.clienteNombre,
    required this.deudaTotal,
    required this.fechaReferencia,
    required this.categoria,
    required this.productos,
  });
}
