import 'package:get/get.dart';

enum DashboardMenu {
  dashboard,
  puntoDeVenta,
  inventario,
  clientes,
  reportes,
  configuracion,
  usuarios,
}

class DashboardController extends GetxController {
  var selectedMenu = DashboardMenu.dashboard.obs;

  void selectMenu(DashboardMenu menu) {
    selectedMenu.value = menu;
  }
} 