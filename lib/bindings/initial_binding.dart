import 'package:get/get.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/top_charts_controller.dart';

class InitialBinding implements Bindings {
  @override
  void dependencies() {
    Get.put(NavigationController());
    Get.put(TopChartsController());
  }
}
