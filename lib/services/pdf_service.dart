import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../models/abono_model.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb

class PdfService {
  static final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final dateFormatShort = DateFormat('dd/MM/yyyy');

  /// Genera un Ticket de venta (Formato Térmico 58mm)
  static Future<void> imprimirTicket(Ticket ticket, {double? abonoReciente}) async {
    final pdf = pw.Document();

    // Formato de impresora térmica estándar (aprox 58mm)
    final pageFormat = PdfPageFormat.roll57;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('CARNICERÍA STEWARD', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Ticket #${ticket.folio}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Fecha: ${dateFormat.format(ticket.fecha?.toDate() ?? DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
              pw.Text('Cliente: ${ticket.clienteNombre}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              // Productos
              ...ticket.productos.map((prod) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            prod.descripcionAmigable, 
                            style: const pw.TextStyle(fontSize: 8)
                          ),
                          if (prod.observaciones.isNotEmpty)
                            pw.Text(
                              prod.observaciones,
                              style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)
                            ),
                        ],
                      ),
                    ),
                    pw.Text(
                      currencyFormat.format(prod.subtotal), 
                      style: const pw.TextStyle(fontSize: 8)
                    ),
                  ],
                ),
              )),
              
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              // Totales
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(currencyFormat.format(ticket.totalVenta), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]
              ),

              if (abonoReciente != null && abonoReciente > 0) ...[
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SU ABONO', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(currencyFormat.format(abonoReciente), style: const pw.TextStyle(fontSize: 9)),
                  ]
                ),
              ],

              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SALDO RESTANTE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(currencyFormat.format(ticket.saldoRestante), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ]
              ),

              pw.SizedBox(height: 15),
              pw.Text('¡Gracias por su compra!', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    // Si estamos en Web, usamos Printing.sharePdf (que se encarga de descargar/mostrar el PDF)
    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Ticket_${ticket.clienteNombre}.pdf',
      );
    } else {
      // En móviles guardamos el archivo en caché temporal y usamos share_plus
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Ticket_${ticket.clienteNombre}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Compartir el archivo generado
      await Share.shareXFiles([XFile(file.path)], text: 'Aquí tienes tu comprobante de compra.');
    }
  }

  /// Genera un Estado de Cuenta (Formato A4)
  static Future<void> imprimirEstadoCuenta(BuildContext buildContext, Cliente cliente, List<Ticket> tickets, List<Abono> abonos) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Cabecera
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ESTADO DE CUENTA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 5),
                    pw.Text('Carnicería Steward', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text('Fecha de Emisión: ${dateFormatShort.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  color: PdfColors.grey200,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.Text(cliente.nombreCompleto, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Contacto: ${cliente.telefono.isEmpty ? "N/A" : cliente.telefono}', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Resumen Financiero
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SALDO TOTAL PENDIENTE', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.SizedBox(height: 5),
                      pw.Text(currencyFormat.format(cliente.deudaTotal), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                    ]
                  ),
                ]
              )
            ),
            pw.SizedBox(height: 30),

            // Historial Detallado de Movimientos
            pw.Text('DETALLE DE DEUDAS Y PAGOS PENDIENTES', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            ...() {
              // Filtrar solo las deudas (tickets con saldo restante mayor a 0, no cancelados)
              final deudas = tickets.where((t) => (t.totalVenta - t.totalAbonado) > 0 && t.estado != 'Pagado' && t.estadoEntrega != 'Cancelado').toList();
              
              if (deudas.isEmpty) {
                return [
                  pw.SizedBox(height: 20),
                  pw.Center(child: pw.Text('El cliente no presenta deudas pendientes.', style: const pw.TextStyle(fontSize: 12))),
                ];
              }

              // Build table data
              final tableData = List<List<dynamic>>.generate(deudas.length, (index) {
                final d = deudas[index];
                final fecha = d.fecha != null ? dateFormatShort.format(d.fecha!.toDate()) : '-';
                final productos = d.productos.map((p) => p.descripcionAmigable).join(', ');
                
                return [
                  d.folio.isNotEmpty ? d.folio : 'S/F',
                  fecha,
                  productos,
                  currencyFormat.format(d.totalVenta),
                  currencyFormat.format(d.totalAbonado),
                  currencyFormat.format(d.totalVenta - d.totalAbonado),
                ];
              });
              
              // Sumar total calculado
              final totalDeudaCalc = deudas.fold(0.0, (sum, item) => sum + (item.totalVenta - item.totalAbonado));
              tableData.add(['', '', '', '', 'TOTAL:', currencyFormat.format(totalDeudaCalc)]);

              return [
                pw.TableHelper.fromTextArray(
                  headers: ['Folio', 'Fecha', 'Concepto (Productos)', 'Total Venta', 'Abonado', 'Saldo Pendiente'],
                  data: tableData,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 12),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.centerRight,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(3.0),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(1.5),
                  },
                  cellStyle: const pw.TextStyle(fontSize: 11),
                  headerPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                )
              ];
            }(),
            
            pw.SizedBox(height: 20),
            pw.Text('HISTORIAL DE ABONOS RECIENTES', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            ...() {
              if (abonos.isEmpty) {
                return [
                  pw.SizedBox(height: 10),
                  pw.Center(child: pw.Text('El cliente no tiene abonos registrados.', style: const pw.TextStyle(fontSize: 12))),
                ];
              }
              
              final abonoData = List<List<dynamic>>.generate(abonos.length, (index) {
                final a = abonos[index];
                final fecha = a.createAt != null ? dateFormatShort.format(a.createAt!.toDate()) : '-';
                String referencia = a.ticketId ?? 'Abono General';
                if (a.ticketId != null && a.ticketId!.isNotEmpty) {
                  try {
                    final tRef = tickets.firstWhere((t) => t.id == a.ticketId);
                    if (tRef.folio != null && tRef.folio!.isNotEmpty) {
                      referencia = 'Folio: ${tRef.folio}';
                    }
                  } catch (e) {
                    // ignore
                  }
                }
                
                return [
                  fecha,
                  currencyFormat.format(a.monto),
                  referencia,
                  a.createBy,
                ];
              });
              
              return [
                pw.TableHelper.fromTextArray(
                  headers: ['Fecha', 'Monto Abonado', 'Referencia', 'Cobrado Por'],
                  data: abonoData,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FlexColumnWidth(2),
                  },
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                )
              ];
            }(),

            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Text(
                'Este documento es informativo y muestra el saldo pendiente a la fecha.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              )
            ),
          ];
        },
      ),
    );

    Navigator.push(
      buildContext,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Estado de Cuenta')),
          body: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: PdfPreview(
              build: (format) async {
                try {
                  return await pdf.save();
                } catch (e, stack) {
                  debugPrint('ERROR EN PDF ESTADO DE CUENTA: $e\n$stack');
                  rethrow;
                }
              },
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: 'EstadoCuenta_${cliente.nombreCompleto.replaceAll(' ', '_')}.pdf',
            ),
          ),
        ),
      ),
    );
  }

  /// Genera y comparte el PDF del Corte de Caja
  static Future<void> generarCorteCajaPdf(
      DateTime start, 
      DateTime end, 
      List<Ticket> tickets, 
      List<Abono> abonos, 
      double ventasTotales, 
      double ingresosReales, 
      double deudaGenerada) async {
    
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CORTE DE CAJA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 5),
                    pw.Text('Carnicería Steward', style: const pw.TextStyle(fontSize: 14)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Periodo', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text('${dateFormatShort.format(start)} - ${dateFormatShort.format(end)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
              ]
            ),
            pw.SizedBox(height: 30),

            // Resumen General
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildPdfSummaryItem('Ventas (Mercancía)', ventasTotales, PdfColors.blue800),
                  _buildPdfSummaryItem('Ingresos (Efectivo)', ingresosReales, PdfColors.green700),
                  _buildPdfSummaryItem('Deuda Nueva', deudaGenerada, PdfColors.red700),
                ]
              )
            ),
            pw.SizedBox(height: 30),

            pw.SizedBox(height: 30),

            // Detalle unificado de Tickets
            pw.Text('DETALLE DE TICKETS EMITIDOS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            if (tickets.isEmpty)
              pw.Text('No se emitieron tickets en este periodo.', style: const pw.TextStyle(color: PdfColors.grey))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Ticket', 'Cliente', 'Total Venta', 'Abono Inicial', 'Deuda'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                data: tickets.map((t) => [
                  dateFormat.format(t.fecha?.toDate() ?? DateTime.now()),
                  t.folio,
                  t.clienteNombre,
                  currencyFormat.format(t.totalVenta),
                  currencyFormat.format(t.totalAbonado),
                  currencyFormat.format(t.saldoRestante)
                ]).toList(),
              ),
          ];
        }
      )
    );

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'CorteCaja_${dateFormatShort.format(start).replaceAll('/', '-')}.pdf',
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/CorteCaja_${dateFormatShort.format(start).replaceAll('/', '-')}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Corte de Caja de ${dateFormatShort.format(start)} a ${dateFormatShort.format(end)}');
    }
  }

  /// Genera y comparte el PDF del Corte de Repartidor
  static Future<void> generarCorteRepartidorPdf(
      String repartidorNombre,
      DateTime start, 
      DateTime end, 
      List<Ticket> tickets, 
      List<Abono> abonos) async {
    
    final pdf = pw.Document();

    double valorMercancia = 0;
    for (var t in tickets) {
      valorMercancia += t.totalVenta;
    }

    double efectivoCobrado = 0;
    for (var a in abonos) {
      efectivoCobrado += a.monto;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CORTE DE REPARTIDOR', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 5),
                    pw.Text('Repartidor: $repartidorNombre', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Periodo', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text('${dateFormatShort.format(start)} - ${dateFormatShort.format(end)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
              ]
            ),
            pw.SizedBox(height: 30),

            // Resumen General
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfSummaryItem('Pedidos Entregados', tickets.length.toDouble(), PdfColors.blueGrey800, isCurrency: false),
                  _buildPdfSummaryItem('Valor de Mercancía', valorMercancia, PdfColors.blue800, isCurrency: true),
                  _buildPdfSummaryItem('Efectivo Recaudado', efectivoCobrado, PdfColors.green700, isCurrency: true),
                ]
              )
            ),
            pw.SizedBox(height: 30),

            // Detalle de Pedidos
            pw.Text('DETALLE DE PEDIDOS ENTREGADOS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            if (tickets.isEmpty)
              pw.Text('No hubo entregas en este periodo.', style: const pw.TextStyle(color: PdfColors.grey))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Fecha Entrega', 'Ticket', 'Cliente', 'Valor Venta'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                data: tickets.map((t) => [
                  dateFormat.format(t.updateAt?.toDate() ?? DateTime.now()),
                  t.folio,
                  t.clienteNombre,
                  currencyFormat.format(t.totalVenta),
                ]).toList(),
              ),
          ];
        }
      )
    );

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Corte_${repartidorNombre.replaceAll(' ', '_')}_${dateFormatShort.format(start).replaceAll('/', '-')}.pdf',
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Corte_${repartidorNombre.replaceAll(' ', '_')}_${dateFormatShort.format(start).replaceAll('/', '-')}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Corte de Repartidor de ${dateFormatShort.format(start)} a ${dateFormatShort.format(end)}');
    }
  }

  static pw.Widget _buildPdfSummaryItem(String title, double amount, PdfColor color, {bool isCurrency = true}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 5),
        pw.Text(isCurrency ? currencyFormat.format(amount) : amount.toInt().toString(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
      ]
    );
  }
}
