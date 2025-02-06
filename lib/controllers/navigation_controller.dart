import 'package:get/get.dart';

class NavigationController extends GetxController {
  static NavigationController get to => Get.find<NavigationController>();

  final _currentIndex = 0.obs;
  int get currentIndex => _currentIndex.value;

  void changePage(int index) {
    _currentIndex.value = index;
  }
}
