// Servicio para cálculo de impuestos (IVA, IpoConsumo, Bolsas)
import '../models/product.dart';
import '../models/group.dart';
import '../models/sale.dart';
import 'sqlite_database_service.dart';

class TaxCalculationService {
  // ✅ Calcular impuestos para un item de venta
  static Future<SaleItem> calculateItemTaxes({
    required Product product,
    required int quantity,
    double? discount,
    double? discountPercentage,
    Group? group,
  }) async {
    // Obtener grupo si no se proporciona
    if (group == null) {
      final groups = await SQLiteDatabaseService.getAllGroups();
      group = groups.firstWhere(
        (g) => g.name == product.category,
        orElse: () => Group(
          name: product.category,
          description: '',
          color: '#9E9E9E',
          icon: 'category',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          defaultVatRate: 0.19,
          defaultVatType: 'GRAVADO',
        ),
      );
    }
    
    // Calcular subtotal del item
    double itemSubtotal = product.price * quantity;
    
    // Aplicar descuentos
    if (discount != null && discount > 0) {
      itemSubtotal -= discount;
    } else if (discountPercentage != null && discountPercentage > 0) {
      itemSubtotal -= (itemSubtotal * discountPercentage / 100);
    }
    
    // Determinar tipo y tasa de IVA
    String vatType = product.vatType;
    double vatRate = product.vatRate;
    
    // Si el producto no tiene IVA configurado, usar el del grupo
    if (vatType == 'GRAVADO' && vatRate == 0.19 && group.defaultVatRate != 0.19) {
      vatType = group.defaultVatType;
      vatRate = group.defaultVatRate;
    }
    
    // Calcular IVA del item
    double itemVat = 0.0;
    if (vatType == 'GRAVADO' && vatRate > 0) {
      itemVat = itemSubtotal * vatRate;
    }
    
    // Calcular IpoConsumo
    double itemIpoConsumo = 0.0;
    if (product.hasIpoConsumo && product.ipoConsumoRate != null) {
      itemIpoConsumo = itemSubtotal * product.ipoConsumoRate!;
    }
    
    // Calcular impuesto de bolsas (si aplica)
    int? bagQuantity;
    if (product.isPlasticBag && product.plasticBagTax != null) {
      bagQuantity = quantity; // Cantidad de bolsas = cantidad vendida
    }
    
    return SaleItem(
      name: product.name,
      price: product.price,
      quantity: quantity,
      unit: product.unit,
      discount: discount,
      discountPercentage: discountPercentage,
      vatType: vatType,
      vatRate: vatRate,
      itemVat: itemVat,
      hasIpoConsumo: product.hasIpoConsumo,
      ipoConsumoRate: product.ipoConsumoRate,
      ipoConsumoType: product.ipoConsumoType,
      itemIpoConsumo: itemIpoConsumo,
      isPlasticBag: product.isPlasticBag,
      plasticBagTax: product.plasticBagTax,
      bagQuantity: bagQuantity,
      itemSubtotal: itemSubtotal,
    );
  }
  
  // ✅ Calcular desglose completo de una venta
  static Future<Sale> calculateSaleBreakdown({
    required List<SaleItem> items,
    required DateTime date,
    required String user,
    String? paymentMethod,
    double? discount,
    double? discountPercentage,
  }) async {
    double totalSubtotal = 0.0;
    double exemptAmount = 0.0;
    double excludedAmount = 0.0;
    double taxedAmount = 0.0;
    double vatAt0 = 0.0;
    double vatAt5 = 0.0;
    double vatAt19 = 0.0;
    double totalVat = 0.0;
    double ipoConsumoAmount = 0.0;
    double plasticBagTaxAmount = 0.0;
    int plasticBagCount = 0;
    
    for (final item in items) {
      totalSubtotal += item.itemSubtotal;
      
      // Clasificar por tipo de IVA
      if (item.vatType == 'EXENTO') {
        exemptAmount += item.itemSubtotal;
      } else if (item.vatType == 'EXCLUIDO') {
        excludedAmount += item.itemSubtotal;
      } else if (item.vatType == 'GRAVADO') {
        taxedAmount += item.itemSubtotal;
        
        // Clasificar IVA por tasa
        if (item.vatRate == 0.0) {
          vatAt0 += item.itemVat;
        } else if (item.vatRate == 0.05) {
          vatAt5 += item.itemVat;
        } else if (item.vatRate == 0.19) {
          vatAt19 += item.itemVat;
        }
      }
      
      totalVat += item.itemVat;
      ipoConsumoAmount += item.itemIpoConsumo;
      
      if (item.isPlasticBag && item.plasticBagTax != null && item.bagQuantity != null) {
        plasticBagTaxAmount += (item.plasticBagTax! * item.bagQuantity!);
        plasticBagCount += item.bagQuantity!;
      }
    }
    
    // Aplicar descuento total si existe
    if (discount != null && discount > 0) {
      totalSubtotal -= discount;
    } else if (discountPercentage != null && discountPercentage > 0) {
      totalSubtotal -= (totalSubtotal * discountPercentage / 100);
    }
    
    // Calcular total final
    double total = totalSubtotal + totalVat + ipoConsumoAmount + plasticBagTaxAmount;
    
    return Sale(
      date: date,
      total: total,
      user: user,
      paymentMethod: paymentMethod,
      items: items,
      discount: discount,
      discountPercentage: discountPercentage,
      exemptAmount: exemptAmount,
      excludedAmount: excludedAmount,
      taxedAmount: taxedAmount,
      vatAt0: vatAt0,
      vatAt5: vatAt5,
      vatAt19: vatAt19,
      totalVat: totalVat,
      ipoConsumoAmount: ipoConsumoAmount,
      plasticBagTaxAmount: plasticBagTaxAmount,
      plasticBagCount: plasticBagCount,
      subtotal: totalSubtotal,
    );
  }
}

