import 'package:get/get.dart';
import 'package:flutter/material.dart';

class NavigationController extends GetxController {
  static NavigationController get to => Get.find();
  final _currentPage = 0.obs;
  final pageController = PageController();

  int get currentPage => _currentPage.value;

  void changePage(int index) {
    _currentPage.value = index;
    pageController.jumpToPage(index);
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
