// Servicio para generar resumen consolidado de IVA por tasas
import '../models/sale.dart';
import 'sqlite_database_service.dart';

class VatConsolidatedReportService {
  // ✅ Generar resumen consolidado de IVA por tasas
  static Future<Map<String, dynamic>> generateVatSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sales = await SQLiteDatabaseService.getSales(
      date: startDate,
      endDate: endDate,
    );
    
    // Filtrar solo ventas (no devoluciones)
    final validSales = sales.where((s) => !s.isReturn).toList();
    
    // Acumular totales por tasa de IVA
    double totalExempt = 0.0;
    double totalExcluded = 0.0;
    double totalTaxed = 0.0;
    double totalVatAt0 = 0.0;
    double totalVatAt5 = 0.0;
    double totalVatAt19 = 0.0;
    double totalVat = 0.0;
    double totalIpoConsumo = 0.0;
    double totalPlasticBagTax = 0.0;
    int totalPlasticBagCount = 0;
    double totalSubtotal = 0.0;
    double totalSales = 0.0;
    
    for (final sale in validSales) {
      totalExempt += sale.exemptAmount;
      totalExcluded += sale.excludedAmount;
      totalTaxed += sale.taxedAmount;
      totalVatAt0 += sale.vatAt0;
      totalVatAt5 += sale.vatAt5;
      totalVatAt19 += sale.vatAt19;
      totalVat += sale.totalVat;
      totalIpoConsumo += sale.ipoConsumoAmount;
      totalPlasticBagTax += sale.plasticBagTaxAmount;
      totalPlasticBagCount += sale.plasticBagCount;
      totalSubtotal += sale.subtotal;
      totalSales += sale.total;
    }
    
    return {
      'period': {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
      'salesBreakdown': {
        'exemptAmount': totalExempt,
        'excludedAmount': totalExcluded,
        'taxedAmount': totalTaxed,
      },
      'vatBreakdown': {
        'vatAt0': totalVatAt0,
        'vatAt5': totalVatAt5,
        'vatAt19': totalVatAt19,
        'totalVat': totalVat,
      },
      'otherTaxes': {
        'ipoConsumo': totalIpoConsumo,
        'plasticBagTax': totalPlasticBagTax,
        'plasticBagCount': totalPlasticBagCount,
      },
      'totals': {
        'subtotal': totalSubtotal,
        'totalSales': totalSales,
        'totalTaxes': totalVat + totalIpoConsumo + totalPlasticBagTax,
      },
      'transactionCount': validSales.length,
    };
  }
  
  // ✅ Generar resumen para declaraciones de impuestos
  static Future<Map<String, dynamic>> generateTaxDeclarationSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final summary = await generateVatSummary(
      startDate: startDate,
      endDate: endDate,
    );
    
    return {
      'period': summary['period'],
      'ivaSummary': {
        'baseGravada': summary['salesBreakdown']['taxedAmount'],
        'ivaGenerado': {
          'tasa0': {
            'base': summary['salesBreakdown']['taxedAmount'] * (summary['vatBreakdown']['vatAt0'] / summary['vatBreakdown']['totalVat']),
            'impuesto': summary['vatBreakdown']['vatAt0'],
          },
          'tasa5': {
            'base': summary['salesBreakdown']['taxedAmount'] * (summary['vatBreakdown']['vatAt5'] / summary['vatBreakdown']['totalVat']),
            'impuesto': summary['vatBreakdown']['vatAt5'],
          },
          'tasa19': {
            'base': summary['salesBreakdown']['taxedAmount'] * (summary['vatBreakdown']['vatAt19'] / summary['vatBreakdown']['totalVat']),
            'impuesto': summary['vatBreakdown']['vatAt19'],
          },
        },
        'totalIvaGenerado': summary['vatBreakdown']['totalVat'],
      },
      'baseExenta': summary['salesBreakdown']['exemptAmount'],
      'baseExcluida': summary['salesBreakdown']['excludedAmount'],
      'impuestoConsumo': summary['otherTaxes']['ipoConsumo'],
      'impuestoBolsas': summary['otherTaxes']['plasticBagTax'],
      'cantidadBolsas': summary['otherTaxes']['plasticBagCount'],
      'totalVentas': summary['totals']['totalSales'],
    };
  }
}

