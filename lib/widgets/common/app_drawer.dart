import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/navigation_controller.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Obx(() {
          final currentIndex = NavigationController.to.currentIndex;

          return Column(
            children: [
              // 抽屉头部
              Container(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey),
              // 根据当前页面显示不同的抽屉项目
              if (currentIndex != 0) // 如果不在首页，显示首页选项
                ListTile(
                  leading: const Icon(Icons.home, color: Colors.white),
                  title: const Text(
                    'Home',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context); // 关闭抽屉
                    NavigationController.to.changePage(0); // 切换到首页
                  },
                ),
              if (currentIndex != 1) // 如果不在排行榜页面，显示排行榜选项
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.white),
                  title: const Text(
                    'Top Charts',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    NavigationController.to.changePage(1);
                  },
                ),
              if (currentIndex != 2) // 如果不在库页面，显示库选项
                ListTile(
                  leading: const Icon(Icons.library_music, color: Colors.white),
                  title: const Text(
                    'Library',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    NavigationController.to.changePage(2);
                  },
                ),
              // 其他通用选项
              const Divider(color: Colors.grey),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text(
                  'Settings',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 导航到设置页面
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text(
                  'About',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 显示关于对话框
                },
              ),
            ],
          );
        }),
      ),
    );
  }
}
