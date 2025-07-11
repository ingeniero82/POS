// Modelo de venta sin Isar

class Sale {
  int? id;
  late DateTime date;
  late double total;
  late String user;
  String? paymentMethod;
  late List<SaleItem> items;
}

class SaleItem {
  late String name;
  late double price;
  late int quantity;
  late String unit;
} 