import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/ticket_model.dart';

import 'package:flutter/services.dart';

class PdfReportService {
  static final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  static Future<void> generateCorteGeneralPdf(List<Ticket> tickets, String dateRangeLabel) async {
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
            'En Efectivo: ${_currencyFormat.format(totalEfectivo)}',
            'En Transferencia: ${_currencyFormat.format(totalTransferencia)}',
            'Tickets Generados: $totalTickets',
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Detalle de Ventas', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildTicketsTable(tickets),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Corte_General.pdf');
  }

  static Future<void> generateCorteRepartidorPdf(String repartidorNombre, List<Ticket> tickets, String dateRangeLabel) async {
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
            'Venta Total Asignada: ${_currencyFormat.format(totalAsignado)}',
            'Total Recibido (Confirmado): ${_currencyFormat.format(totalEntregado)}',
            'Faltante por Entregar: ${_currencyFormat.format(totalPendiente)}',
            'Recibido en Efectivo: ${_currencyFormat.format(totalEfectivo)}',
            'Recibido en Transferencia: ${_currencyFormat.format(totalTransferencia)}',
            'Pedidos Confirmados: $countCompletados',
            'Pedidos Pendientes: $countPendientes',
            'Pedidos Cancelados: $countCancelados',
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Detalle de Pedidos', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildRepartidorTicketsTable(tickets),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Corte_${repartidorNombre.replaceAll(" ", "_")}.pdf');
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
        creoStr,
        repartidor,
        cobradorStr,
        fechaPagoStr,
        _currencyFormat.format(t.totalVenta),
      ];
    });

    data.add(['', '', '', '', '', '', '', '', '', 'TOTAL:', _currencyFormat.format(sum)]);

    return pw.TableHelper.fromTextArray(
      headers: ['Folio', 'Fecha/Hora', 'Cliente', 'Tipo', 'Pago', 'Estado', 'Creó', 'Repartió', 'Cobró', 'Fecha Cobro', 'Total'],
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
        creoStr,
        cobradorStr,
        fechaPagoStr,
        _currencyFormat.format(t.totalVenta),
      ];
    }).toList();

    data.add(['', '', '', '', '', '', '', 'TOTAL:', _currencyFormat.format(sum)]);

    return pw.TableHelper.fromTextArray(
      headers: ['Folio', 'Fecha/Hora', 'Cliente', 'Estado', 'Pago', 'Creó', 'Cobró', 'Fecha Cobro', 'Total'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
    );
  }
}
