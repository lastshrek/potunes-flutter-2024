import 'package:get/get.dart';

class AppController extends GetxController {
  static AppController get to => Get.find();

  // 当前选中的底部导航栏索引
  final _currentIndex = 0.obs;

  // getter
  int get currentIndex => _currentIndex.value;

  // setter
  set currentIndex(int value) {
    _currentIndex.value = value;
  }

  final _isNetworkReady = false.obs;
  RxBool get isNetworkReady => _isNetworkReady;

  void updateNetworkStatus(bool status) {
    print('Updating network status: $status');
    _isNetworkReady.value = status;
  }
}
