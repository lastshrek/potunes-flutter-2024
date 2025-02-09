import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../controllers/top_charts_controller.dart';
import '../controllers/navigation_controller.dart';
import '../services/audio_service.dart';
import '../services/user_service.dart';

class InitialBinding implements Bindings {
  @override
  void dependencies() {
    // 服务
    Get.put(UserService(), permanent: true);
    Get.put(AudioService(), permanent: true);

    // 控制器
    Get.put(NavigationController(), permanent: true);
    Get.put(HomeController());
    Get.put(TopChartsController());
  }
}
