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
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class PdfReportService {
  static final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    return null;
  }

  static Future<void> generateCorteGeneralPdf(BuildContext context, List<Ticket> tickets, List<Abono> abonos, List<Gasto> gastos, String dateRangeLabel) async {
    abonos = abonos.where((a) => a.ticketId != 'ENTREGA_GENERAL').toList();
    final pdf = pw.Document();
    
    final Map<String, String> clienteNames = {};
    for (var t in tickets) {
      if (t.clienteId.isNotEmpty && t.clienteNombre.isNotEmpty) {
        clienteNames[t.clienteId] = t.clienteNombre;
      }
    }

    final missingClientIds = abonos
        .map((a) => a.clienteId)
        .where((id) => id.isNotEmpty && !clienteNames.containsKey(id))
        .toSet();

    if (missingClientIds.isNotEmpty) {
      for (var id in missingClientIds) {
        try {
          DocumentSnapshot<Map<String, dynamic>> doc;
          try {
            doc = await FirebaseFirestore.instance
                .collection('clientes')
                .doc(id)
                .get(const GetOptions(source: Source.serverAndCache));
          } catch (e) {
            doc = await FirebaseFirestore.instance
                .collection('clientes')
                .doc(id)
                .get(const GetOptions(source: Source.cache));
          }
          if (doc.exists) {
            final data = doc.data();
            if (data != null) {
              final String name = data['nombre'] ?? '';
              final String app = data['appaterno'] ?? '';
              final String apm = data['apmaterno'] ?? '';
              final fullName = '$name $app $apm'.trim();
              if (fullName.isNotEmpty) {
                clienteNames[id] = fullName;
              } else {
                clienteNames[id] = 'Cliente sin nombre';
              }
            }
          }
        } catch (e) {
          // Ignore
        }
      }
    }

    final Map<String, Ticket> resolvedTickets = {for (var t in tickets) t.id: t};

    final missingTicketIds = abonos
        .map((a) => a.ticketId)
        .where((id) => id != null && id.isNotEmpty && id != 'ENTREGA_REPARTIDOR' && id != 'ENTREGA_GENERAL' && !resolvedTickets.containsKey(id))
        .cast<String>()
        .toSet();

    if (missingTicketIds.isNotEmpty) {
      for (var id in missingTicketIds) {
        try {
          DocumentSnapshot<Map<String, dynamic>> doc;
          try {
            doc = await FirebaseFirestore.instance
                .collection('tickets')
                .doc(id)
                .get(const GetOptions(source: Source.serverAndCache));
          } catch (e) {
            doc = await FirebaseFirestore.instance
                .collection('tickets')
                .doc(id)
                .get(const GetOptions(source: Source.cache));
          }
          if (doc.exists && doc.data() != null) {
            resolvedTickets[id] = Ticket.fromMap(doc.id, doc.data()!);
          }
        } catch (e) {
          // Ignore
        }
      }
    }

    // Cargar icono
    final ByteData bytes = await rootBundle.load('assets/images/iconoInicio.png');
    final Uint8List byteList = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(byteList);

    double totalVendido = 0;
    double totalClientesDeben = 0;
    double totalRepartidoresDeben = 0;
    double totalGastos = 0;
    double totalRecibido = 0;
    double totalOtrasEntradas = 0;

    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado' && t.estadoEntrega != 'Programado') {
        totalVendido += t.totalVenta;
        
        if (t.estado == 'Con Deuda' || t.formaVenta == 'Crédito') {
          totalClientesDeben += t.saldoRestante;
          if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
            totalRepartidoresDeben += t.totalAbonado;
          }
        } else { // Contado y Pagado/Pendiente
          if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
            totalRepartidoresDeben += t.saldoRestante;
          }
        }
      }
    }

    double totalRecibidoClientes = 0;
    double totalRecibidoRepartidores = 0;
    for (var a in abonos) {
      final isRepartidor = a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL';
      if (isRepartidor) {
        totalRecibidoRepartidores += a.monto;
      } else {
        bool wasThroughDriver = false;
        bool isTransfer = false;
        if (a.ticketId != null && resolvedTickets.containsKey(a.ticketId)) {
          final ticket = resolvedTickets[a.ticketId]!;
          if (ticket.tipoEntrega == 'Domicilio') {
            wasThroughDriver = true;
          }
          if (ticket.metodoPago == 'Transferencia') {
            isTransfer = true;
          }
        }
        if (!wasThroughDriver && !isTransfer) {
          totalRecibidoClientes += a.monto;
        }
      }
    }
    double totalRecibidoTotal = totalRecibidoClientes + totalRecibidoRepartidores;
    double totalPendiente = totalClientesDeben + totalRepartidoresDeben;

    for (var g in gastos) {
      if (g.esDeCaja) {
        bool isReturned = true;
        if (g.tipoGasto == 'Cambio' && g.repartidorId != null && g.repartidorId!.isNotEmpty) {
          final hasPending = tickets.any((t) =>
              t.repartidorId == g.repartidorId &&
              t.tipoEntrega == 'Domicilio' &&
              !t.pagoRepartidorConfirmado &&
              t.estadoEntrega != 'Cancelado' &&
              t.estadoEntrega != 'Programado');
          if (hasPending) {
            isReturned = false;
          }
        }
        if (g.tipoGasto != 'Cambio' || !isReturned) {
          totalGastos += g.monto;
        }
      } else {
        totalOtrasEntradas += g.monto;
      }
    }

    double totalTransferencias = 0;
    double totalEfectivoRecibido = 0;
    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado' && t.estadoEntrega != 'Programado') {
        double receivedAmount = 0;
        if (t.estado == 'Con Deuda' || t.formaVenta == 'Crédito') {
          if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
            receivedAmount = 0;
          } else {
            receivedAmount = t.totalAbonado;
          }
        } else { // Contado y Pagado/Pendiente
          if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
            receivedAmount = t.totalAbonado;
          } else {
            receivedAmount = t.totalVenta;
          }
        }

        if (t.metodoPago == 'Transferencia') {
          totalTransferencias += receivedAmount;
        } else {
          totalEfectivoRecibido += receivedAmount;
        }
      }
    }

    final Map<String, double> initialAbonoAmounts = {};
    final Set<String> initialAbonoIds = {};

    for (var a in abonos) {
      if (a.ticketId != null && resolvedTickets.containsKey(a.ticketId)) {
        final ticket = resolvedTickets[a.ticketId]!;
        if (ticket.createAt != null && a.createAt != null) {
          final diff = a.createAt!.toDate().difference(ticket.createAt!.toDate()).abs();
          if (diff.inSeconds <= 10) {
            initialAbonoAmounts[ticket.id] = a.monto;
            initialAbonoIds.add(a.id);
          }
        }
      }
    }

    List<Map<String, dynamic>> movimientos = [];
    for (var t in tickets) {
      if (t.estadoEntrega == 'Programado') continue;
      final double initAbono = initialAbonoAmounts[t.id] ?? 0.0;
      movimientos.add({
        'fecha': t.fecha?.toDate() ?? DateTime.now(),
        'tipo': 'Venta',
        'subtipo': t.tipoEntrega,
        'metodo': t.metodoPago,
        'monto': t.totalVenta,
        'estado': t.estadoEntrega,
        'nombre': t.clienteNombre,
        'folio': t.folio,
        'initialAbono': initAbono,
        'obj': t
      });
    }
    for (var a in abonos) {
      final isRepartidor = a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL';
      
      if (initialAbonoIds.contains(a.id)) continue;

      // Skip client abonos collected in cash by a driver, because they are already accounted for in the ENTREGA_REPARTIDOR bulk abono
      if (a.repartidorId != null && a.repartidorId!.isNotEmpty && !isRepartidor) {
        final ticket = resolvedTickets[a.ticketId];
        if (ticket == null || ticket.metodoPago == 'Efectivo') {
          continue;
        }
      }

      // Skip the abono document if it corresponds to a Contado sale (since it's already shown in the Venta row)
      bool isContadoAbono = false;
      if (a.ticketId != null && resolvedTickets.containsKey(a.ticketId)) {
        final ticket = resolvedTickets[a.ticketId]!;
        if (ticket.formaVenta == 'Contado' && (ticket.tipoEntrega != 'Domicilio' || ticket.metodoPago != 'Efectivo')) {
          isContadoAbono = true;
        }
      }
      if (isContadoAbono) continue;

      final String abonoName;
      if (isRepartidor) {
        abonoName = a.ticketId == 'ENTREGA_REPARTIDOR'
            ? 'Entrega de Repartidor - ${a.repartidorId ?? a.createBy}'
            : 'Entrega General - ${a.repartidorId ?? a.createBy}';
      } else {
        final String resolvedName = clienteNames[a.clienteId] ?? a.clienteId;
        abonoName = resolvedName.isNotEmpty ? 'Abono a Deuda - $resolvedName' : 'Abono a Deuda';
      }
      
      String metodo = '';
      String folio = 'N/A';
      if (a.ticketId != null && resolvedTickets.containsKey(a.ticketId)) {
        final ticket = resolvedTickets[a.ticketId]!;
        metodo = ticket.metodoPago;
        folio = ticket.folio;
      } else if (isRepartidor) {
        metodo = 'Efectivo';
      }
      
      movimientos.add({
        'fecha': a.fecha?.toDate() ?? DateTime.now(),
        'tipo': 'Abono',
        'subtipo': isRepartidor ? 'Repartidor' : 'Cliente',
        'metodo': metodo,
        'monto': a.monto,
        'estado': 'Entregado',
        'nombre': abonoName,
        'folio': folio,
        'obj': a
      });
    }
    for (var g in gastos) {
      if (g.esDeCaja) {
        movimientos.add({'fecha': g.fecha?.toDate() ?? DateTime.now(), 'tipo': 'Gasto', 'subtipo': '', 'metodo': '', 'monto': g.monto, 'estado': '', 'nombre': g.concepto, 'folio': 'N/A', 'obj': g});
      } else {
        movimientos.add({'fecha': g.fecha?.toDate() ?? DateTime.now(), 'tipo': 'Otras Entradas', 'subtipo': 'Cambio', 'metodo': 'Externo', 'monto': g.monto, 'estado': '', 'nombre': 'Fondo de Cambio (Externo) - ${g.repartidorNombre ?? ''}', 'folio': 'N/A', 'obj': g});
      }
    }
    movimientos.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));

    final List<pw.Widget> contentWidgets = [];

    if (movimientos.isNotEmpty) {
      contentWidgets.add(
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 20),
              pw.Text('Últimos Movimientos', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _buildMovimientosGeneralTable(movimientos, resolvedTickets: resolvedTickets),
            ],
          ),
        ),
      );
    }

    bool hasClientesDeudores = false;
    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado' && t.formaVenta == 'Crédito' && t.saldoRestante > 0) {
        hasClientesDeudores = true;
        break;
      }
    }
    if (hasClientesDeudores) {
      contentWidgets.add(
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 20),
              pw.Text('Clientes Deudores', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 8),
              _buildClientesDeudoresTable(tickets),
            ],
          ),
        ),
      );
    }

    bool hasLiquidacionesRepartidores = false;
    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado' && t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
        double monto = 0;
        if (t.formaVenta == 'Crédito') {
          monto = t.totalAbonado;
        } else {
          monto = t.saldoRestante;
        }
        if (monto > 0) {
          hasLiquidacionesRepartidores = true;
          break;
        }
      }
    }
    if (hasLiquidacionesRepartidores) {
      contentWidgets.add(
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 20),
              pw.Text('Liquidaciones Pendientes (Dinero pendiente por entregar (repartidores))', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 8),
              _buildLiquidacionesRepartidoresTable(tickets),
            ],
          ),
        ),
      );
    }

    List<Abono> filteredAbonos = [];
    for (var a in abonos) {
      if (a.repartidorId == null || a.repartidorId!.isEmpty) {
        filteredAbonos.add(a);
      } else {
        if (a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL') {
          filteredAbonos.add(a);
        } else {
          final t = resolvedTickets[a.ticketId];
          if (t != null && t.metodoPago != 'Efectivo') {
            filteredAbonos.add(a);
          }
        }
      }
    }
    if (filteredAbonos.isNotEmpty) {
      contentWidgets.add(
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 20),
              pw.Text('Detalle de Dinero Recibido en Caja', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 8),
              _buildDineroRecibidoTable(abonos, resolvedTickets, clienteNames),
            ],
          ),
        ),
      );
    }
    contentWidgets.add(
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 20),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text('Resumen de Conciliación Financiera', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Text('Resumen de Efectivo Físico y Salidas de Caja', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _buildConciliacionTable(
                    totalEfectivoRecibido - totalGastos,
                    totalTransferencias,
                    totalClientesDeben,
                    totalRepartidoresDeben,
                    totalOtrasEntradas,
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: _buildUnifiedEfectivoCajaTable(
                    totalEfectivoRecibido,
                    gastos,
                    tickets,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Nota: Total Neto Conciliado = Efectivo neto en caja + Transferencias recibidas + Adeudo de clientes + Pendiente por entregar repartidores + Otras entradas.',
              style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader('Corte de Caja General', dateRangeLabel, image),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pág. ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => contentWidgets,
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Vista Previa del Reporte')),
          body: PdfPreview(
            build: (format) async => pdf.save(),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName: 'corteG-${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
          ),
        ),
      ),
    );
  }

  static Future<void> generateCorteRepartidorPdf(
      BuildContext context,
      String repartidorNombre,
      List<Ticket> tickets, // These are ticketsRep
      List<Ticket> allTickets,
      List<Abono> abonos,
      List<Gasto> gastos,
      String dateRangeLabel) async {
    abonos = abonos.where((a) => a.ticketId != 'ENTREGA_GENERAL').toList();
    final pdf = pw.Document();
    
    // Cargar icono
    final ByteData bytes = await rootBundle.load('assets/images/iconoInicio.png');
    final Uint8List byteList = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(byteList);

    // Calcular fondo de cambio dado al repartidor hoy
    double totalCambioDado = 0;
    for (var g in gastos) {
      if (g.tipoGasto == 'Cambio' && g.repartidorNombre?.trim().toLowerCase() == repartidorNombre.trim().toLowerCase()) {
        totalCambioDado += g.monto;
      }
    }

    // Calcular las ventas en efectivo cobradas por el repartidor hoy
    double totalVentasEfectivo = 0;
    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado' && t.estadoEntrega != 'Programado' && t.metodoPago == 'Efectivo') {
        if (t.formaVenta == 'Contado') {
          totalVentasEfectivo += t.totalVenta;
        } else {
          totalVentasEfectivo += t.totalAbonado;
        }
      }
    }

    double abonosCobrados = 0;
    List<Abono> abonosDelRepartidor = [];
    for (var a in abonos) {
      if (a.ticketId != 'ENTREGA_REPARTIDOR' && a.ticketId != 'ENTREGA_GENERAL') {
        if (a.repartidorId == repartidorNombre || a.createBy == repartidorNombre) {
          bool isTicketInList = tickets.any((t) => t.id == a.ticketId);
          if (!isTicketInList) {
            abonosDelRepartidor.add(a);
            abonosCobrados += a.monto;
            totalVentasEfectivo += a.monto;
          }
        }
      }
    }

    // Calcular entregas reales de efectivo del repartidor
    double totalEntregado = 0;
    for (var a in abonos) {
      if ((a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL') && a.repartidorId == repartidorNombre) {
        totalEntregado += a.monto;
      }
    }

    double totalAEntregar = totalVentasEfectivo + totalCambioDado;
    double totalPendiente = totalAEntregar - totalEntregado;
    totalPendiente = totalPendiente < 0 ? 0.0 : totalPendiente;

    List<Gasto> cambiosDelRepartidor = [];
    for (var g in gastos) {
      if (g.tipoGasto == 'Cambio' && g.repartidorNombre?.trim().toLowerCase() == repartidorNombre.trim().toLowerCase()) {
        cambiosDelRepartidor.add(g);
      }
    }
    
    Map<String, Ticket> fetchedTickets = {};
    for (var a in abonosDelRepartidor) {
      if (a.ticketId != null && a.ticketId != 'ENTREGA_REPARTIDOR' && a.ticketId != 'ENTREGA_GENERAL') {
        if (!fetchedTickets.containsKey(a.ticketId)) {
          try {
            DocumentSnapshot<Map<String, dynamic>> doc;
            try {
              doc = await FirebaseFirestore.instance
                  .collection('tickets')
                  .doc(a.ticketId)
                  .get(const GetOptions(source: Source.serverAndCache));
            } catch (e) {
              doc = await FirebaseFirestore.instance
                  .collection('tickets')
                  .doc(a.ticketId)
                  .get(const GetOptions(source: Source.cache));
            }
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
        header: (context) => _buildHeader('Corte de Caja - Repartidor', dateRangeLabel, image),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pág. ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 10),
          pw.Text('Repartidor: $repartidorNombre', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 20),
          pw.Text('Detalle de Pedidos', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildRepartidorTicketsTable(tickets),
          if (abonosDelRepartidor.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Abonos Cobrados', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
            pw.SizedBox(height: 10),
            _buildAbonosTable(abonosDelRepartidor, fetchedTickets: fetchedTickets),
          ],
          if (cambiosDelRepartidor.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Fondos de Cambio Recibidos', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
            pw.SizedBox(height: 10),
            _buildCambiosRepartidorTable(cambiosDelRepartidor),
          ],
          pw.SizedBox(height: 20),
          pw.Text('Resumen de Conciliación - Repartidor', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildRepartidorResumenCajaTable(
            totalVentasEfectivo: totalVentasEfectivo,
            totalCambioDado: totalCambioDado,
            totalAEntregar: totalAEntregar,
            totalEntregado: totalEntregado,
            totalPendiente: totalPendiente,
          ),
        ],
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Vista Previa del Reporte')),
          body: PdfPreview(
            build: (format) async => pdf.save(),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName: 'corteR-$repartidorNombre-${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
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
          children: [
            pw.Text(
              'Carnicería Doriss  |  $title',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red800,
              ),
            ),
            pw.Text(
              'Generado el: ${_dateFormat.format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }


  static pw.Widget _buildTicketsTable(List<Ticket> tickets) {
    double sum = 0;
    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado') sum += t.totalVenta;
    }
    
    final List<List<dynamic>> data = List<List<dynamic>>.generate(tickets.length, (index) {
      final t = tickets[index];
      String estado = t.estadoEntrega == 'Cancelado' ? 'Cancelado' : ((t.estadoEntrega == 'Entregado' || t.pagoRepartidorConfirmado) ? 'Entregado' : 'Pendiente');
      String repartidor = t.repartidorNombre?.isNotEmpty == true ? t.repartidorNombre! : '-';
      if (repartidor.contains('Sucursal')) repartidor = 'Sucursal';
      
      final fechaStr = t.createAt != null ? _dateFormat.format(t.createAt!.toDate()) : '-';
      
      String fechaPagoStr = '-';
      if (t.pagoRepartidorConfirmado && t.updateAt != null) {
        fechaPagoStr = DateFormat('dd/MM HH:mm').format(t.updateAt!.toDate());
      }

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

    data.add([
      '',
      '', '', '', '', '', '',
      pw.Text('TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      pw.Text(_currencyFormat.format(sum), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: ['Folio', 'Fecha', 'Cliente', 'Tipo', 'Pago', 'Estado', 'Repartió', 'Fecha Cobro', 'Total'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerLeft,
        6: pw.Alignment.centerLeft,
        7: pw.Alignment.centerLeft,
        8: pw.Alignment.centerRight,
      },
      headerAlignments: {
        8: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildRepartidorTicketsTable(List<Ticket> tickets) {
    double sumVenta = 0;
    double sumAbonado = 0;
    double sumRestante = 0;
    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado') {
        sumVenta += t.totalVenta;
        sumAbonado += t.totalAbonado;
        sumRestante += t.saldoRestante;
      }
    }

    final List<List<dynamic>> data = tickets.map<List<dynamic>>((t) {
      String estado = t.estadoEntrega == 'Cancelado' ? 'Cancelado' : ((t.estadoEntrega == 'Entregado' || t.pagoRepartidorConfirmado) ? 'Entregado' : 'Pendiente');
      String pagoStr = t.pagoRepartidorConfirmado ? t.metodoPago : 'Pendiente';
      if (t.estadoEntrega == 'Cancelado') pagoStr = '-';
      final fechaStr = t.createAt != null ? _dateFormat.format(t.createAt!.toDate()) : '-';

      return [
        t.folio.isNotEmpty ? t.folio : 'N/A',
        fechaStr,
        t.clienteNombre,
        estado,
        pagoStr,
        _currencyFormat.format(t.totalVenta),
        _currencyFormat.format(t.totalAbonado),
        _currencyFormat.format(t.saldoRestante),
      ];
    }).toList();

    data.add([
      '',
      '', '', '',
      pw.Text('TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      pw.Text(_currencyFormat.format(sumVenta), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      pw.Text(_currencyFormat.format(sumAbonado), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      pw.Text(_currencyFormat.format(sumRestante), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: ['Folio', 'Fecha', 'Cliente', 'Estado', 'Pago', 'Total Venta', 'Abonado', 'Restante'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
      },
      headerAlignments: {
        8: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildRepartidorResumenCajaTable({
    required double totalVentasEfectivo,
    required double totalCambioDado,
    required double totalAEntregar,
    required double totalEntregado,
    required double totalPendiente,
  }) {
    final data = [
      [
        'Ventas / Cobros en Efectivo',
        _currencyFormat.format(totalVentasEfectivo),
      ],
      [
        'Fondo de Cambio Recibido',
        _currencyFormat.format(totalCambioDado),
      ],
      [
        pw.Text('TOTAL A ENTREGAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.Text(_currencyFormat.format(totalAEntregar), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      ],
      [
        'Total Entregado (Caja)',
        _currencyFormat.format(totalEntregado),
      ],
      [
        pw.Text('SALDO PENDIENTE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red800)),
        pw.Text(_currencyFormat.format(totalPendiente), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red800)),
      ],
    ];

    return pw.TableHelper.fromTextArray(
      headers: ['Concepto', 'Monto'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
      columnWidths: {
        0: const pw.FlexColumnWidth(5),
        1: const pw.FlexColumnWidth(3),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
      headerAlignments: {
        1: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildCambiosRepartidorTable(List<Gasto> cambios) {
    double sumCambio = 0;
    for (var c in cambios) {
      sumCambio += c.monto;
    }

    final List<List<dynamic>> data = cambios.map<List<dynamic>>((c) {
      final fechaStr = c.fecha != null ? _dateFormat.format(c.fecha!.toDate()) : '-';
      return [
        fechaStr,
        c.concepto,
        c.esDeCaja ? 'Caja Física' : 'Fondos Externos',
        _currencyFormat.format(c.monto),
      ];
    }).toList();

    data.add([
      pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      '',
      '',
      pw.Text(_currencyFormat.format(sumCambio), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Concepto', 'Origen', 'Monto'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 9),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      headerAlignments: {
        3: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildAbonosTable(List<Abono> abonos, {Map<String, Ticket> fetchedTickets = const {}}) {
    double sumAbono = 0;
    for (var a in abonos) {
      sumAbono += a.monto;
    }

    final List<List<dynamic>> data = abonos.map<List<dynamic>>((a) {
      final fechaStr = a.createAt != null ? _dateFormat.format(a.createAt!.toDate()) : '-';
      String origen = a.createBy;
      if (a.repartidorId != null && a.repartidorId!.isNotEmpty) {
         origen = a.repartidorId!;
      }
      
      String cliente = a.clienteId;
      String folio = a.ticketId ?? 'Sin Folio';
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
    }).toList();

    data.add([
      pw.Text('TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      '',
      '',
      '',
      '',
      pw.Text(_currencyFormat.format(sumAbono), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Cliente', 'Folio / ID', 'Cobrado Por', 'Saldo Pend.', 'Abonó'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 9),
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
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
      },
      headerAlignments: {
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildMovimientosGeneralTable(List<Map<String, dynamic>> movimientos, {Map<String, Ticket> resolvedTickets = const {}}) {
    if (movimientos.isEmpty) return pw.Text('No hay movimientos en este periodo.');
    
    final List<List<dynamic>> data = movimientos.map<List<dynamic>>((mov) {
      final fechaStr = _dateFormat.format(mov['fecha'] as DateTime);
      final tipo = mov['tipo'] as String;
      final nombre = mov['nombre'] as String;
      final estado = mov['estado'] as String;
      final monto = mov['monto'] as double;
      final obj = mov['obj'];

      String folioId = mov['folio'] as String? ?? 'N/A';
      String cliente = '-';
      String concepto = '-';
      String metodo = '-';
      String repartidor = '-';
      String estadoStr = 'Entregado';

      // Columnas financieras
      String colVenta = '-';
      String colAbonoCliente = '-';
      String colAbonoRepartidor = '-';
      String colOtras = '-';
      String colGasto = '-';
      String colCancelado = '-';
      String colPendCliente = '-';
      String colPendRepartidor = '-';

      double pendCliente = 0;
      double pendRepartidor = 0;
      double abonoCliente = 0;
      double abonoRepartidor = 0;

      if (estado != 'Cancelado') {
        if (tipo == 'Venta') {
          final t = obj as Ticket;
          final double initAbono = (t.tipoEntrega == 'Domicilio' && t.metodoPago == 'Efectivo')
              ? 0.0
              : (mov['initialAbono'] as double? ?? 0.0);
          if (t.estado == 'Con Deuda' || t.formaVenta == 'Crédito') {
            pendCliente = t.saldoRestante;
            if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
              pendRepartidor = t.totalAbonado;
            }
          } else { // Contado
            if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
              pendRepartidor = t.saldoRestante;
            }
          }

          if (initAbono > 0) {
            abonoCliente = initAbono;
          } else if (t.formaVenta == 'Contado' && (t.tipoEntrega != 'Domicilio' || t.metodoPago != 'Efectivo')) {
            abonoCliente = t.totalVenta;
          }
        } else if (tipo == 'Abono') {
          final a = obj as Abono;
          final isRepartidor = a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL';
          if (isRepartidor) {
            abonoRepartidor = monto;
          } else {
            abonoCliente = monto;
          }
        }
      }

      if (pendCliente > 0) {
        colPendCliente = _currencyFormat.format(pendCliente);
      }
      if (pendRepartidor > 0) {
        colPendRepartidor = _currencyFormat.format(pendRepartidor);
      }
      if (abonoCliente > 0) {
        colAbonoCliente = _currencyFormat.format(abonoCliente);
      }
      if (abonoRepartidor > 0) {
        colAbonoRepartidor = _currencyFormat.format(abonoRepartidor);
      }

      if (estado == 'Cancelado') {
        colCancelado = _currencyFormat.format(monto);
      } else {
        if (tipo == 'Venta') {
          colVenta = _currencyFormat.format(monto);
        } else if (tipo == 'Otras Entradas') {
          colOtras = _currencyFormat.format(monto);
        } else if (tipo == 'Gasto') {
          colGasto = _currencyFormat.format(monto);
        }
      }

      if (tipo == 'Venta') {
        final t = obj as Ticket;
        cliente = t.clienteNombre.isNotEmpty ? t.clienteNombre : 'Sin Nombre';
        concepto = 'Venta';
        metodo = t.metodoPago;
        repartidor = t.repartidorNombre?.isNotEmpty == true ? t.repartidorNombre! : '-';
        if (repartidor.contains('Sucursal')) repartidor = 'Sucursal';
        if (t.estadoEntrega == 'Cancelado') {
          estadoStr = 'Cancelado';
        } else if (pendCliente > 0 || pendRepartidor > 0) {
          estadoStr = 'Pendiente';
        } else {
          estadoStr = 'Entregado';
        }
      } else if (tipo == 'Abono') {
        final a = obj as Abono;
        if (nombre.startsWith('Abono a Deuda - ')) {
          cliente = nombre.replaceFirst('Abono a Deuda - ', '');
        } else if (nombre.startsWith('Entrega de Repartidor - ')) {
          cliente = nombre.replaceFirst('Entrega de Repartidor - ', '');
        } else if (nombre.startsWith('Entrega General - ')) {
          cliente = nombre.replaceFirst('Entrega General - ', '');
        } else {
          cliente = nombre.isNotEmpty ? nombre : 'Cliente';
        }
        
        if (a.ticketId == 'ENTREGA_REPARTIDOR') {
          concepto = 'Abono Repartidor';
        } else if (a.ticketId == 'ENTREGA_GENERAL') {
          concepto = 'Abono General';
        } else {
          concepto = 'Abono';
        }
        
        metodo = mov['metodo'] as String? ?? 'Efectivo';
        repartidor = a.repartidorId?.isNotEmpty == true ? a.repartidorId! : '-';
        if (a.ticketId != null && resolvedTickets.containsKey(a.ticketId)) {
          final t = resolvedTickets[a.ticketId]!;
          if (t.repartidorNombre?.isNotEmpty == true) {
            repartidor = t.repartidorNombre!;
          }
        }
        if (repartidor.contains('Sucursal')) repartidor = 'Sucursal';
        estadoStr = 'Entregado';
      } else if (tipo == 'Gasto') {
        final g = obj as Gasto;
        concepto = g.concepto;
        metodo = 'Efectivo';
        repartidor = g.createBy.isNotEmpty == true ? g.createBy : '-';
        estadoStr = 'Entregado';
      } else if (tipo == 'Otras Entradas') {
        final g = obj as Gasto;
        concepto = 'Cambio';
        metodo = 'Externo';
        repartidor = g.repartidorNombre?.isNotEmpty == true ? g.repartidorNombre! : '-';
        estadoStr = 'Entregado';
      }

      String metodoAbbr = metodo;
      if (metodo == 'Transferencia') metodoAbbr = 'Transf.';
      if (metodo == 'Efectivo') metodoAbbr = 'Efect.';
      if (metodo == 'Externo') metodoAbbr = 'Ext.';

      String estadoAbbr = estadoStr;
      if (estadoStr == 'Pendiente') estadoAbbr = 'Pend.';
      if (estadoStr == 'Entregado') estadoAbbr = 'Entreg.';
      if (estadoStr == 'Cancelado') estadoAbbr = 'Canc.';

      return [
        fechaStr,
        folioId,
        cliente,
        concepto,
        metodoAbbr,
        repartidor,
        estadoAbbr,
        colVenta,
        colAbonoCliente,
        colAbonoRepartidor,
        colOtras,
        colGasto,
        colCancelado,
        colPendCliente,
        colPendRepartidor,
      ];
    }).toList();

    double sumVentas = 0;
    double sumAbonosCliente = 0;
    double sumAbonosRepartidor = 0;
    double sumOtras = 0;
    double sumGastos = 0;
    double sumCancelados = 0;
    double sumPendientesCliente = 0;
    double sumPendientesRepartidor = 0;

    for (var mov in movimientos) {
      final monto = mov['monto'] as double;
      final tipo = mov['tipo'] as String;
      final estado = mov['estado'] as String;
      final obj = mov['obj'];

      if (estado == 'Cancelado') {
        sumCancelados += monto;
      } else {
        if (tipo == 'Venta') {
          sumVentas += monto;
          final t = obj as Ticket;
          final double initAbono = (t.tipoEntrega == 'Domicilio' && t.metodoPago == 'Efectivo')
              ? 0.0
              : (mov['initialAbono'] as double? ?? 0.0);
          if (initAbono > 0) {
            sumAbonosCliente += initAbono;
          } else if (t.formaVenta == 'Contado' && (t.tipoEntrega != 'Domicilio' || t.metodoPago != 'Efectivo')) {
            sumAbonosCliente += t.totalVenta;
          }
          
          if (t.estado == 'Con Deuda' || t.formaVenta == 'Crédito') {
            sumPendientesCliente += t.saldoRestante;
            if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
              sumPendientesRepartidor += t.totalAbonado;
            }
          } else { // Contado
            if (t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
              sumPendientesRepartidor += t.saldoRestante;
            }
          }
        } else if (tipo == 'Abono') {
          final a = obj as Abono;
          final isRepartidor = a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL';
          if (isRepartidor) {
            sumAbonosRepartidor += monto;
          } else {
            sumAbonosCliente += monto;
          }
        } else if (tipo == 'Otras Entradas') {
          sumOtras += monto;
        } else if (tipo == 'Gasto') {
          sumGastos += monto;
        }
      }
    }

    final double totalNeto = (sumAbonosCliente + sumAbonosRepartidor + sumOtras) - sumGastos;

    data.add([
      pw.Text('TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
      '',
      '',
      '',
      '',
      '',
      '',
      pw.Text(_currencyFormat.format(sumVentas), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
      pw.Text(_currencyFormat.format(sumAbonosCliente), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
      pw.Text(_currencyFormat.format(sumAbonosRepartidor), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
      pw.Text(_currencyFormat.format(sumOtras), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
      pw.Text(_currencyFormat.format(sumGastos), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
      pw.Text(_currencyFormat.format(sumCancelados), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.red700)),
      pw.Text(_currencyFormat.format(sumPendientesCliente), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.orange700)),
      pw.Text(_currencyFormat.format(sumPendientesRepartidor), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.orange700)),
    ]);

    final table = pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Folio', 'Cliente', 'Concepto', 'Método', 'Repartió', 'Estado', 'Venta', 'Abono Cliente', 'Abono Repart.', 'Otras Entr.', 'Gasto', 'Cancelado', 'Pend. Cliente', 'Pend. Repart.'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 7),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellStyle: const pw.TextStyle(fontSize: 7),
      data: data,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2), // Fecha
        1: const pw.FlexColumnWidth(0.8), // Folio
        2: const pw.FlexColumnWidth(1.8), // Cliente
        3: const pw.FlexColumnWidth(0.8), // Concepto
        4: const pw.FlexColumnWidth(0.6), // Método
        5: const pw.FlexColumnWidth(0.8), // Repartió
        6: const pw.FlexColumnWidth(0.6), // Estado
        7: const pw.FlexColumnWidth(0.9), // Venta
        8: const pw.FlexColumnWidth(0.9), // Abono Cliente
        9: const pw.FlexColumnWidth(0.9), // Abono Repartidor
        10: const pw.FlexColumnWidth(0.9), // Otras Entr.
        11: const pw.FlexColumnWidth(0.9), // Gasto
        12: const pw.FlexColumnWidth(0.9), // Cancelado
        13: const pw.FlexColumnWidth(0.9), // Pend. Cliente
        14: const pw.FlexColumnWidth(0.9), // Pend. Repart.
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerLeft,
        6: pw.Alignment.centerLeft,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
        9: pw.Alignment.centerRight,
        10: pw.Alignment.centerRight,
        11: pw.Alignment.centerRight,
        12: pw.Alignment.centerRight,
        13: pw.Alignment.centerRight,
        14: pw.Alignment.centerRight,
      },
      headerAlignments: {
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
        9: pw.Alignment.centerRight,
        10: pw.Alignment.centerRight,
        11: pw.Alignment.centerRight,
        12: pw.Alignment.centerRight,
        13: pw.Alignment.centerRight,
        14: pw.Alignment.centerRight,
      },
    );

    return table;
  }

  static pw.Widget _buildClientesDeudoresTable(List<Ticket> tickets) {
    // Filtrar los tickets de clientes que deban a crédito
    final List<Ticket> deudoresTickets = tickets
        .where((t) => t.estadoEntrega != 'Cancelado' && t.estadoEntrega != 'Programado' && t.formaVenta == 'Crédito' && t.saldoRestante > 0)
        .toList();

    if (deudoresTickets.isEmpty) {
      return pw.Text('No hay clientes con saldo pendiente en este periodo.', style: const pw.TextStyle(fontSize: 9));
    }

    // Ordenar por cliente y luego por fecha
    deudoresTickets.sort((a, b) {
      int comp = a.clienteNombre.compareTo(b.clienteNombre);
      if (comp != 0) return comp;
      return (a.fecha ?? Timestamp.now()).compareTo(b.fecha ?? Timestamp.now());
    });

    double totalDeuda = 0;
    final List<List<dynamic>> data = [];

    for (var t in deudoresTickets) {
      final cliente = t.clienteNombre.trim().isNotEmpty ? t.clienteNombre.trim() : 'Sin Nombre';
      final folio = t.folio.isNotEmpty ? t.folio : 'N/A';
      final tDate = _parseDateTime(t.fecha);
      final fechaStr = tDate != null ? _dateFormat.format(tDate) : '-';
      final adeudoStr = _currencyFormat.format(t.saldoRestante);

      totalDeuda += t.saldoRestante;

      if (t.productos.isEmpty) {
        data.add([
          fechaStr,
          folio,
          cliente,
          'N/A',
          'N/A',
          adeudoStr,
        ]);
      } else {
        for (int i = 0; i < t.productos.length; i++) {
          final item = t.productos[i];
          final codigo = item.codigo.isNotEmpty ? item.codigo : 'N/A';
          final nombre = item.nombre;

          data.add([
            i == 0 ? fechaStr : '',
            i == 0 ? folio : '',
            i == 0 ? cliente : '',
            codigo,
            nombre,
            i == 0 ? adeudoStr : '',
          ]);
        }
      }
    }

    data.add([
      pw.Text('TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      '',
      '',
      '',
      '',
      pw.Text(_currencyFormat.format(totalDeuda), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Folio', 'Cliente', 'Clave de producto', 'Productos', 'Adeudo'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.8),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(3.5),
        5: const pw.FlexColumnWidth(1.5),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerRight,
      },
      headerAlignments: {
        5: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildLiquidacionesRepartidoresTable(List<Ticket> tickets) {
    final Map<String, List<_RepartidorTicketDetail>> groups = {};
    double totalPendiente = 0;
    int totalTicketsCount = 0;

    for (var t in tickets) {
      if (t.estadoEntrega != 'Cancelado' && t.estadoEntrega != 'Programado' && t.tipoEntrega == 'Domicilio' && !t.pagoRepartidorConfirmado) {
        String repartidor = t.repartidorNombre?.isNotEmpty == true ? t.repartidorNombre!.trim() : 'Sin Asignar';
        if (repartidor.contains('Sucursal')) repartidor = 'Sucursal';
        
        double monto = 0;
        if (t.formaVenta == 'Crédito') {
          monto = t.totalAbonado;
        } else {
          monto = t.saldoRestante;
        }

        if (monto > 0) {
          totalPendiente += monto;
          totalTicketsCount++;
          final folio = t.folio.isNotEmpty ? t.folio : 'N/A';

          groups.putIfAbsent(repartidor, () => []).add(
            _RepartidorTicketDetail(folio: folio, monto: monto),
          );
        }
      }
    }

    if (groups.isEmpty) {
      return pw.Text('No hay liquidaciones pendientes de repartidores en este periodo.', style: const pw.TextStyle(fontSize: 9));
    }

    final List<List<dynamic>> data = [];
    for (var entry in groups.entries) {
      final repartidor = entry.key;
      final ticketsList = entry.value;
      for (int i = 0; i < ticketsList.length; i++) {
        final ticket = ticketsList[i];
        data.add([
          i == 0 ? repartidor : '',
          ticket.folio,
          _currencyFormat.format(ticket.monto),
        ]);
      }
    }

    // Add TOTALES row at the end of data:
    data.add([
      pw.Text('TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      pw.Text('$totalTicketsCount ${totalTicketsCount == 1 ? 'Ticket' : 'Tickets'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      pw.Text(_currencyFormat.format(totalPendiente), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: ['Repartidor', 'Folio', 'Importe por Liquidar'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
      columnWidths: {
        0: const pw.FlexColumnWidth(3.5),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(3.5),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
      },
      headerAlignments: {
        2: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildDineroRecibidoTable(List<Abono> abonos, Map<String, Ticket> resolvedTickets, Map<String, String> clienteNames) {
    List<Abono> filteredAbonos = [];
    double totalMonto = 0;

    for (var a in abonos) {
      if (a.repartidorId == null || a.repartidorId!.isEmpty) {
        filteredAbonos.add(a);
        totalMonto += a.monto;
      } else {
        if (a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL') {
          filteredAbonos.add(a);
          totalMonto += a.monto;
        } else {
          // Si el pago no fue en efectivo (ej. Transferencia o Tarjeta),
          // no forma parte del corte físico del repartidor, por lo que se detalla de forma individual.
          final t = resolvedTickets[a.ticketId];
          if (t != null && t.metodoPago != 'Efectivo') {
            filteredAbonos.add(a);
            totalMonto += a.monto;
          }
        }
      }
    }

    if (filteredAbonos.isEmpty) {
      return pw.Text('No se registró dinero recibido en caja en este periodo.', style: const pw.TextStyle(fontSize: 9));
    }

    filteredAbonos.sort((a, b) {
      final dateA = a.fecha?.toDate() ?? DateTime.now();
      final dateB = b.fecha?.toDate() ?? DateTime.now();
      return dateA.compareTo(dateB);
    });

    final List<List<dynamic>> data = filteredAbonos.map<List<dynamic>>((a) {
      final fechaStr = a.fecha != null ? _dateFormat.format(a.fecha!.toDate()) : '-';
      
      String origen = a.repartidorId?.isNotEmpty == true ? a.repartidorId! : (clienteNames[a.clienteId] ?? a.clienteId);
      String folio = a.ticketId ?? 'Sin Folio';
      String concepto = 'Pago / Abono';

      if (a.ticketId == 'ENTREGA_REPARTIDOR' || a.ticketId == 'ENTREGA_GENERAL') {
        concepto = 'Abono Repartidor';
        origen = a.repartidorId?.isNotEmpty == true ? a.repartidorId! : (a.createBy.isNotEmpty == true ? a.createBy : 'Repartidor');
        folio = 'N/A';
      } else {
        final t = resolvedTickets[a.ticketId];
        if (t != null) {
          origen = t.clienteNombre;
          folio = t.folio.isNotEmpty ? t.folio : 'N/A';
          final metodoStr = t.metodoPago != 'Efectivo' ? ' (${t.metodoPago})' : '';
          concepto = (t.formaVenta == 'Contado' ? 'Pago de Contado' : 'Abono a Crédito') + metodoStr;
        } else {
          final String resolvedName = clienteNames[a.clienteId] ?? a.clienteId;
          origen = resolvedName;
        }
      }

      return [
        fechaStr,
        folio,
        origen,
        concepto,
        _currencyFormat.format(a.monto),
      ];
    }).toList();

    data.add([
      pw.Text('TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      '',
      '',
      '',
      pw.Text(_currencyFormat.format(totalMonto), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Folio', 'Origen (Cliente / Repartidor)', 'Concepto', 'Monto Recibido'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(2.5),
        4: const pw.FlexColumnWidth(2),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
      },
      headerAlignments: {
        4: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildConciliacionTable(
    double totalEfectivoNeto,
    double totalTransferencias,
    double totalClientesDeben,
    double totalRepartidoresDeben,
    double totalOtrasEntradas,
  ) {
    final double totalNetoConciliado = totalEfectivoNeto + totalTransferencias + totalClientesDeben + totalRepartidoresDeben + totalOtrasEntradas;
    final data = [
      [
        'Efectivo neto en caja',
        _currencyFormat.format(totalEfectivoNeto),
      ],
      [
        'Transferencias recibidas',
        _currencyFormat.format(totalTransferencias),
      ],
      [
        'Adeudo de clientes',
        _currencyFormat.format(totalClientesDeben),
      ],
      [
        'Pendiente por entregar repartidores',
        _currencyFormat.format(totalRepartidoresDeben),
      ],
      [
        'Otras entradas',
        _currencyFormat.format(totalOtrasEntradas),
      ],
      [
        pw.Text('TOTAL NETO CONCILIADO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.Text(_currencyFormat.format(totalNetoConciliado), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      ],
    ];

    return pw.TableHelper.fromTextArray(
      headers: ['Concepto', 'Monto'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: data,
      columnWidths: {
        0: const pw.FlexColumnWidth(5),
        1: const pw.FlexColumnWidth(3),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
      headerAlignments: {
        1: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildUnifiedEfectivoCajaTable(double totalEfectivo, List<Gasto> gastos, List<Ticket> tickets) {
    double sumGastos = 0;
    final List<List<dynamic>> rows = [];

    // Add starting cash
    rows.add([
      'Total Efectivo Recibido (Entradas Brutas)',
      _currencyFormat.format(totalEfectivo),
    ]);

    // Add each expense
    for (var g in gastos) {
      if (g.esDeCaja) {
        bool isReturned = true;
        if (g.tipoGasto == 'Cambio' && g.repartidorId != null && g.repartidorId!.isNotEmpty) {
          final hasPending = tickets.any((t) =>
              t.repartidorId == g.repartidorId &&
              t.tipoEntrega == 'Domicilio' &&
              !t.pagoRepartidorConfirmado &&
              t.estadoEntrega != 'Cancelado' &&
              t.estadoEntrega != 'Programado');
          if (hasPending) {
            isReturned = false;
          }
        }

        String concepto = g.concepto;
        if (g.tipoGasto == 'Cambio' && g.repartidorNombre != null && g.repartidorNombre!.isNotEmpty) {
          concepto = isReturned ? 'Fondo de Cambio (Devuelto) - ${g.repartidorNombre}' : 'Fondo de Cambio (En Ruta) - ${g.repartidorNombre}';
        }

        if (g.tipoGasto != 'Cambio' || !isReturned) {
          sumGastos += g.monto;
          rows.add([
            '  Salida: $concepto',
            '- ${_currencyFormat.format(g.monto)}',
          ]);
        } else {
          rows.add([
            '  $concepto',
            _currencyFormat.format(0.0),
          ]);
        }
      }
    }

    // Add net cash
    rows.add([
      pw.Text('EFECTIVO FÍSICO NETO EN CAJA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.green800)),
      pw.Text(_currencyFormat.format(totalEfectivo - sumGastos), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.green800)),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: ['Concepto de Caja', 'Monto'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: rows,
      columnWidths: {
        0: const pw.FlexColumnWidth(5),
        1: const pw.FlexColumnWidth(3),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },
      headerAlignments: {
        1: pw.Alignment.centerRight,
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
      if (t.esProgramado) continue;
      if (t.estadoEntrega != 'Cancelado' && t.estadoEntrega != 'Programado') {
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

    final data = <List<dynamic>>[];
    for (var entry in listCarnes) {
      data.add([entry.key, 'Carnicería', '${entry.value.toStringAsFixed(1)} kg']);
    }
    for (var entry in listCatalogo) {
      data.add([entry.key, 'Catálogo', '${entry.value.toInt()} pzas']);
    }

    final int prodCount = data.length;

    data.add([
      pw.Text('TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      '',
      pw.Text('$prodCount ${prodCount == 1 ? 'Producto' : 'Productos'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
    ]);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader('Reporte de Productos Vendidos', dateRangeLabel, image),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pág. ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 20),
            if (prodCount == 0)
              pw.Text('No se encontraron productos vendidos en este periodo.', style: pw.TextStyle(fontSize: 14))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Producto', 'Sección', 'Cantidad Vendida'],
                data: data,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 12),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 11),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                },
                headerAlignments: {
                  2: pw.Alignment.centerRight,
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
          body: PdfPreview(
            build: (format) async => pdf.save(),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName: 'productosVendidos-${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
          ),
        ),
      ),
    );
  }

  static Future<void> generateReporteDeudoresPdf(BuildContext context, List<Ticket> tickets, List<Abono> abonos) async {
    try {
      final pdf = pw.Document();
      
      // Cargar icono
      final ByteData bytes = await rootBundle.load('assets/images/iconoInicio.png');
      final Uint8List byteList = bytes.buffer.asUint8List();
      final image = pw.MemoryImage(byteList);

      Map<String, List<Ticket>> ticketsByClient = {};
      for (var t in tickets) {
        if (t.estadoEntrega == 'Programado') continue;
        if (!ticketsByClient.containsKey(t.clienteId)) ticketsByClient[t.clienteId] = [];
        ticketsByClient[t.clienteId]!.add(t);
      }

      List<_DeudorClientGroup> clientGroups = [];

      for (var entry in ticketsByClient.entries) {
        final String clienteId = entry.key;
        final String clienteNombre = entry.value.first.clienteNombre;
        final List<Ticket> clientTickets = entry.value;

        // Ordenar tickets por fecha
        clientTickets.sort((a, b) => (a.fecha ?? Timestamp.now()).compareTo(b.fecha ?? Timestamp.now()));

        DateTime? oldestTicketDate;
        for (var t in clientTickets) {
          final tDate = _parseDateTime(t.fecha);
          if (tDate != null) {
            if (oldestTicketDate == null || tDate.isBefore(oldestTicketDate)) {
              oldestTicketDate = tDate;
            }
          }
        }

        DateTime? lastPaymentDate;
        for (var a in abonos) {
          if (a.clienteId == clienteId) {
            final aDate = _parseDateTime(a.fecha);
            if (aDate != null) {
              if (lastPaymentDate == null || aDate.isAfter(lastPaymentDate)) {
                lastPaymentDate = aDate;
              }
            }
          }
        }

        final referenceDate = lastPaymentDate ?? oldestTicketDate ?? DateTime.now();

        clientGroups.add(_DeudorClientGroup(
          clienteId: clienteId,
          clienteNombre: clienteNombre,
          tickets: clientTickets,
          referenceDate: referenceDate,
        ));
      }

      // Ordenar clientes por la fecha de referencia (el más antiguo primero)
      clientGroups.sort((a, b) => a.referenceDate.compareTo(b.referenceDate));

      final DateFormat shortDateFormat = DateFormat('dd/MM HH:mm');

      pw.Widget buildHeaderCell(String text, {bool alignRight = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
            textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        );
      }

      pw.Widget buildCell(String text, {bool alignRight = false, bool isBold = false, bool isRed = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isRed ? PdfColors.red800 : PdfColors.black,
            ),
            textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        );
      }

      final List<pw.TableRow> tableRows = [];

      // Fila de cabecera
      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          children: [
            buildHeaderCell('Cliente'),
            buildHeaderCell('Folio'),
            buildHeaderCell('Fecha'),
            buildHeaderCell('Clave'),
            buildHeaderCell('Producto'),
            buildHeaderCell('Cant.', alignRight: true),
            buildHeaderCell('Precio', alignRight: true),
            buildHeaderCell('Total', alignRight: true),
            buildHeaderCell('Abonado', alignRight: true),
            buildHeaderCell('Restante', alignRight: true),
          ],
        ),
      );

      double totalVentaGlobal = 0;
      double totalAbonadoGlobal = 0;
      double totalRestanteGlobal = 0;

      for (int cIdx = 0; cIdx < clientGroups.length; cIdx++) {
        final cg = clientGroups[cIdx];
        
        for (int tIdx = 0; tIdx < cg.tickets.length; tIdx++) {
          final t = cg.tickets[tIdx];
          final isLastTicketOfClient = (tIdx == cg.tickets.length - 1);

          totalVentaGlobal += t.totalVenta;
          totalAbonadoGlobal += t.totalAbonado;
          totalRestanteGlobal += t.saldoRestante;

          final folio = t.folio.isNotEmpty ? t.folio : 'N/A';
          final tDate = _parseDateTime(t.fecha);
          final fechaStr = tDate != null ? shortDateFormat.format(tDate) : '-';

          if (t.productos.isEmpty) {
            final isLastRowOfClient = isLastTicketOfClient;
            final showClient = (tIdx == 0);
            
            final borderDecoration = pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: isLastRowOfClient ? PdfColors.blueGrey800 : PdfColors.grey300,
                  width: isLastRowOfClient ? 1.5 : 0.5,
                ),
              ),
            );

            tableRows.add(
              pw.TableRow(
                decoration: borderDecoration,
                children: [
                  buildCell(showClient ? cg.clienteNombre : '', isBold: showClient),
                  buildCell(folio),
                  buildCell(fechaStr),
                  buildCell('N/A'),
                  buildCell('Sin productos'),
                  buildCell('-', alignRight: true),
                  buildCell('-', alignRight: true),
                  buildCell(_currencyFormat.format(t.totalVenta), alignRight: true),
                  buildCell(_currencyFormat.format(t.totalAbonado), alignRight: true),
                  buildCell(_currencyFormat.format(t.saldoRestante), alignRight: true, isBold: true, isRed: true),
                ],
              ),
            );
          } else {
            for (int pIdx = 0; pIdx < t.productos.length; pIdx++) {
              final item = t.productos[pIdx];
              final isFirstRowOfTicket = (pIdx == 0);
              final isLastRowOfTicket = (pIdx == t.productos.length - 1);
              final isLastRowOfClient = isLastTicketOfClient && isLastRowOfTicket;

              final codigo = item.codigo.isNotEmpty ? item.codigo : 'N/A';
              final productoNombre = item.nombre;
              final cantStr = item.cantidad % 1 == 0 ? item.cantidad.toInt().toString() : item.cantidad.toStringAsFixed(1);
              final precioStr = _currencyFormat.format(item.precioUnitario);
              final totalStr = _currencyFormat.format(item.subtotal);

              final showClient = (tIdx == 0 && isFirstRowOfTicket);

              final borderDecoration = pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: isLastRowOfClient ? PdfColors.blueGrey800 : PdfColors.grey300,
                    width: isLastRowOfClient ? 1.5 : 0.5,
                  ),
                ),
              );

              tableRows.add(
                pw.TableRow(
                  decoration: borderDecoration,
                  children: [
                    buildCell(showClient ? cg.clienteNombre : '', isBold: showClient),
                    buildCell(isFirstRowOfTicket ? folio : ''),
                    buildCell(isFirstRowOfTicket ? fechaStr : ''),
                    buildCell(codigo),
                    buildCell(productoNombre),
                    buildCell(cantStr, alignRight: true),
                    buildCell(precioStr, alignRight: true),
                    buildCell(totalStr, alignRight: true),
                    buildCell(isFirstRowOfTicket ? _currencyFormat.format(t.totalAbonado) : '', alignRight: true),
                    buildCell(isFirstRowOfTicket ? _currencyFormat.format(t.saldoRestante) : '', alignRight: true, isBold: isFirstRowOfTicket, isRed: isFirstRowOfTicket),
                  ],
                ),
              );
            }
          }
        }
      }

      // Añadir fila de totales
      if (clientGroups.isNotEmpty) {
        tableRows.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
            ),
            children: [
              buildCell('TOTALES', isBold: true),
              buildCell(''),
              buildCell(''),
              buildCell(''),
              buildCell(''),
              buildCell(''),
              buildCell(''),
              buildCell(_currencyFormat.format(totalVentaGlobal), alignRight: true, isBold: true),
              buildCell(_currencyFormat.format(totalAbonadoGlobal), alignRight: true, isBold: true),
              buildCell(_currencyFormat.format(totalRestanteGlobal), alignRight: true, isBold: true, isRed: true),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader('Reporte de Deudores', 'Detallado por Cliente y Ticket', image),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Pág. ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (pw.Context context) {
            if (clientGroups.isEmpty) {
              return [
                pw.SizedBox(height: 20),
                pw.Center(child: pw.Text('No hay clientes con deuda pendiente.')),
              ];
            }
            return [
              pw.SizedBox(height: 10),
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.8),
                  1: pw.FlexColumnWidth(0.9),
                  2: pw.FlexColumnWidth(1.1),
                  3: pw.FlexColumnWidth(1.1),
                  4: pw.FlexColumnWidth(2.5),
                  5: pw.FlexColumnWidth(0.7),
                  6: pw.FlexColumnWidth(1.1),
                  7: pw.FlexColumnWidth(1.1),
                  8: pw.FlexColumnWidth(1.1),
                  9: pw.FlexColumnWidth(1.1),
                },
                children: tableRows,
              ),
            ];
          },
        ),
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Vista Previa del Reporte')),
              body: PdfPreview(
                build: (format) async => pdf.save(),
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                pdfFileName: 'ReporteDeudores-${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
              ),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error en generateReporteDeudoresPdf: $e');
      print(stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar Reporte de Deudores: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  static Future<void> generateReportePedidosProgramadosPdf(
      BuildContext context, DateTime startDate, DateTime endDate, String dateRangeLabel) async {
    BuildContext? loadingCtx;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        loadingCtx = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final empresaId = userProvider.empresaId;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('tickets')
          .where('empresaId', isEqualTo: empresaId)
          .get();

      final startStamp = Timestamp.fromDate(startDate);
      final endStamp = Timestamp.fromDate(endDate);

      final tickets = querySnapshot.docs
          .map((doc) => Ticket.fromMap(doc.id, doc.data()))
          .where((t) {
            if (!t.esProgramado) return false;
            if (t.createAt == null) return false;
            return t.createAt!.compareTo(startStamp) >= 0 && t.createAt!.compareTo(endStamp) <= 0;
          })
          .toList();

      if (loadingCtx != null && loadingCtx!.mounted) {
        Navigator.pop(loadingCtx!);
      }

      if (tickets.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron pedidos programados agendados en este periodo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Sort by createAt
      tickets.sort((a, b) => (a.createAt ?? Timestamp.now()).compareTo(b.createAt ?? Timestamp.now()));

      final pdf = pw.Document();
      final ByteData bytes = await rootBundle.load('assets/images/iconoInicio.png');
      final Uint8List byteList = bytes.buffer.asUint8List();
      final image = pw.MemoryImage(byteList);

      final List<List<dynamic>> tableData = [];
      double totalAgendado = 0;

      for (var t in tickets) {
        final createDate = t.createAt?.toDate() ?? DateTime.now();
        final deliveryDate = t.fechaEntregaProgramada?.toDate() ?? DateTime.now();

        final String createStr = _dateFormat.format(createDate) + ' ' + DateFormat('hh:mm a').format(createDate);
        final String deliveryStr = _dateFormat.format(deliveryDate) + ' ' + DateFormat('hh:mm a').format(deliveryDate);

        final String itemsDesc = t.productos.map((item) => '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad.toStringAsFixed(2)} ${item.unidadVenta} x ${item.nombre}').join('\n');

        tableData.add([
          createStr,
          deliveryStr,
          t.folio,
          t.clienteNombre,
          itemsDesc,
          _currencyFormat.format(t.totalVenta),
          t.estadoEntrega,
        ]);

        totalAgendado += t.totalVenta;
      }

      tableData.add([
        pw.Text('TOTALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        '',
        '',
        '',
        pw.Text('${tickets.length} Pedido(s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.Text(_currencyFormat.format(totalAgendado), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        '',
      ]);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader('Reporte de Pedidos Programados Agendados', dateRangeLabel, image),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Pág. ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['F. Creación', 'F. Entrega', 'Folio', 'Cliente', 'Productos', 'Total Venta', 'Estado Actual'],
                data: tableData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 7),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5), // F. Creacion
                  1: const pw.FlexColumnWidth(1.5), // F. Entrega
                  2: const pw.FlexColumnWidth(0.8), // Folio
                  3: const pw.FlexColumnWidth(1.8), // Cliente
                  4: const pw.FlexColumnWidth(2.5), // Productos
                  5: const pw.FlexColumnWidth(1.0), // Total Venta
                  6: const pw.FlexColumnWidth(1.0), // Estado
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerLeft,
                },
                headerAlignments: {
                  5: pw.Alignment.centerRight,
                },
              ),
            ];
          },
        ),
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Vista Previa del Reporte')),
              body: PdfPreview(
                build: (format) async => pdf.save(),
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                pdfFileName: 'reportePedidosProgramados-${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
              ),
            ),
          ),
        );
      }

    } catch (e) {
      if (loadingCtx != null && loadingCtx!.mounted) {
        Navigator.pop(loadingCtx!);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar Reporte de Pedidos Programados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


class _DeudorClientGroup {
  final String clienteId;
  final String clienteNombre;
  final List<Ticket> tickets;
  final DateTime referenceDate;

  _DeudorClientGroup({
    required this.clienteId,
    required this.clienteNombre,
    required this.tickets,
    required this.referenceDate,
  });
}



class _RepartidorTicketDetail {
  final String folio;
  final double monto;
  _RepartidorTicketDetail({
    required this.folio,
    required this.monto,
  });
}
