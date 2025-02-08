import 'package:get/get.dart';
import '../screens/pages/top_charts_page.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: '/top_charts',
      page: () => const TopChartsPage(),
    ),
    // ... 其他路由配置保持不变 ...
  ];
}
