import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/pages/top_charts_page.dart';
import '../screens/pages/playlist_page.dart';

// 自定义页面切换动画
class NoFadeTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }
}

class AppPages {
  static final pages = [
    GetPage(
      name: '/top_charts',
      page: () => const TopChartsPage(),
    ),
    GetPage(
      name: '/playlist',
      page: () {
        final arguments = Get.arguments as Map<String, dynamic>;
        return PlaylistPage(
          playlist: arguments['playlist'],
          playlistId: arguments['playlistId'],
          isFromCollections: arguments['isFromCollections'] ?? false,
          isFromTopList: arguments['isFromTopList'] ?? false,
          isFromNewAlbum: arguments['isFromNewAlbum'] ?? false,
        );
      },
      customTransition: NoFadeTransition(),
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // ... 其他路由配置保持不变 ...
  ];
}
