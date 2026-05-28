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
              pw.Text('Ticket #${ticket.id.substring(0, 8).toUpperCase()}', style: const pw.TextStyle(fontSize: 8)),
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
                      child: pw.Text(
                        '${prod.cantidad}x ${prod.nombre}', 
                        style: const pw.TextStyle(fontSize: 8)
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

    // En lugar de usar layoutPdf, guardamos el archivo en caché temporal
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Ticket_${ticket.clienteNombre}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Compartir el archivo generado
    await Share.shareXFiles([XFile(file.path)], text: 'Aquí tienes tu comprobante de compra.');
  }

  /// Genera un Estado de Cuenta (Formato A4)
  static Future<void> imprimirEstadoCuenta(Cliente cliente, List<Ticket> tickets, List<Abono> abonos) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
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
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('SALDO TOTAL A PAGAR', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.SizedBox(height: 5),
                      pw.Text(currencyFormat.format(cliente.deudaTotal), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                    ]
                  ),
                ]
              )
            ),
            pw.SizedBox(height: 30),

            // Historial Detallado de Movimientos
            pw.Text('HISTORIAL DE COMPRAS DETALLADO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            
            // Renderizamos los movimientos iterativamente combinando tickets y abonos
            ...() {
              // Combinar en una lista de movimientos y ordenarlos ascendentemente (del más viejo al más reciente)
              final movimientos = <dynamic>[...tickets, ...abonos];
              movimientos.sort((a, b) {
                final dateA = (a.fecha?.toDate() ?? DateTime.now()) as DateTime;
                final dateB = (b.fecha?.toDate() ?? DateTime.now()) as DateTime;
                return dateB.compareTo(dateA); // Descendente: más recientes primero
              });

              return movimientos.map((mov) {
                if (mov is Ticket) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 15),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueGrey50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.blueGrey200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('VENTA (Ticket: ${mov.id.substring(0, 8).toUpperCase()}) | Fecha: ${dateFormat.format(mov.fecha?.toDate() ?? DateTime.now())}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue800)),
                            pw.Text(mov.estado, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: mov.estado == 'Pagado' ? PdfColors.green700 : PdfColors.orange700)),
                          ]
                        ),
                        pw.SizedBox(height: 8),
                        ...mov.productos.map((p) => pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('- ${p.cantidad}x ${p.nombre}', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(currencyFormat.format(p.subtotal), style: const pw.TextStyle(fontSize: 10)),
                          ]
                        )),
                        pw.Divider(color: PdfColors.blueGrey200),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Venta: ${currencyFormat.format(mov.totalVenta)} | Abonado: ${currencyFormat.format(mov.totalAbonado)}', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text('SALDO TICKET: ${currencyFormat.format(mov.saldoRestante)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                          ]
                        ),
                      ]
                    )
                  );
                } else if (mov is Abono) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 15),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('ABONO | Fecha: ${dateFormat.format(mov.fecha?.toDate() ?? DateTime.now())}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green800)),
                            pw.Text(mov.ticketId == null ? 'Abono General' : 'Abono a Ticket', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
                          ]
                        ),
                        pw.SizedBox(height: 5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Monto Abonado:', style: const pw.TextStyle(fontSize: 11)),
                            pw.Text(currencyFormat.format(mov.monto), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                          ]
                        ),
                      ]
                    )
                  );
                }
                return pw.SizedBox();
              }).toList();
            }(),
            
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Text(
                'Este documento es informativo y no representa un comprobante fiscal.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              )
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'EstadoCuenta_${cliente.nombreCompleto}.pdf',
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

            // Ingresos (Abonos)
            pw.Text('DETALLE DE INGRESOS (Efectivo Recibido)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            if (abonos.isEmpty)
              pw.Text('No hubo ingresos en este periodo.', style: const pw.TextStyle(color: PdfColors.grey))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Tipo', 'Cliente', 'Monto'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                data: abonos.map((a) => [
                  dateFormat.format(a.fecha?.toDate() ?? DateTime.now()),
                  a.ticketId == null ? 'Abono General' : 'Abono a Ticket',
                  'ID: ${a.clienteId.substring(0,5)}...', // Idealmente tendríamos el nombre, pero no está en AbonoModel
                  currencyFormat.format(a.monto)
                ]).toList(),
              ),

            pw.SizedBox(height: 30),

            // Ventas (Tickets)
            pw.Text('DETALLE DE VENTAS (Mercancía Despachada)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            if (tickets.isEmpty)
              pw.Text('No hubo ventas en este periodo.', style: const pw.TextStyle(color: PdfColors.grey))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Ticket', 'Total Venta', 'Abono Inicial', 'Deuda'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                data: tickets.map((t) => [
                  dateFormat.format(t.fecha?.toDate() ?? DateTime.now()),
                  t.id.substring(0, 8).toUpperCase(),
                  currencyFormat.format(t.totalVenta),
                  currencyFormat.format(t.totalAbonado),
                  currencyFormat.format(t.saldoRestante)
                ]).toList(),
              ),
          ];
        }
      )
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/CorteCaja_${dateFormatShort.format(start).replaceAll('/', '-')}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Corte de Caja de ${dateFormatShort.format(start)} a ${dateFormatShort.format(end)}');
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
                  t.id.substring(0, 8).toUpperCase(),
                  t.clienteNombre,
                  currencyFormat.format(t.totalVenta),
                ]).toList(),
              ),
          ];
        }
      )
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Corte_${repartidorNombre.replaceAll(' ', '_')}_${dateFormatShort.format(start).replaceAll('/', '-')}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Corte de Repartidor de ${dateFormatShort.format(start)} a ${dateFormatShort.format(end)}');
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
