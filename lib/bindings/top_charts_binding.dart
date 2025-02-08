import 'package:get/get.dart';
import '../controllers/top_charts_controller.dart';

class TopChartsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TopChartsController());
  }
}
