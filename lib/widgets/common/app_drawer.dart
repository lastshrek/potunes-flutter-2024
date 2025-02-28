import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:potunes_flutter_2025/screens/pages/login_page.dart';
import '../../controllers/navigation_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/user_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(height: 0),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 应用信息头部
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/app_icon.png',
                              width: 32,
                              height: 32,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '破破',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '帅气的人都在使用的播放器',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                'Version ${snapshot.data!.version}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  // 导航选项
                  Obx(() {
                    final currentIndex = NavigationController.to.currentIndex;
                    return Column(
                      children: [
                        if (currentIndex != 0)
                          ListTile(
                            leading: const Icon(Icons.home, color: Colors.white),
                            title: const Text(
                              'Home',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              NavigationController.to.changePage(0);
                            },
                          ),
                        if (currentIndex != 1)
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
                        if (currentIndex != 2)
                          ListTile(
                            leading: const Icon(Icons.library_music, color: Colors.white),
                            title: const Text(
                              'Library',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              if (UserService.to.isLoggedIn) {
                                NavigationController.to.changePage(2);
                              } else {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (context) => const LoginPage(),
                                );
                              }
                            },
                          ),
                      ],
                    );
                  }),
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
                  // 版本更新记录
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      maintainState: true,
                      leading: const Icon(Icons.history, color: Colors.white),
                      title: const Text(
                        '更新记录',
                        style: TextStyle(color: Colors.white),
                      ),
                      collapsedIconColor: Colors.white,
                      iconColor: Colors.white,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '1.2.0版本主要更新：',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildUpdateItem('全新UI升级'),
                              _buildUpdateItem('新增FM模式'),
                              _buildUpdateItem('iOS新增灵动岛'),
                              _buildUpdateItem('新增个人资料管理'),
                              _buildUpdateItem('当前播放歌曲列表内展示'),
                              _buildUpdateItem('收藏页细化'),
                              _buildUpdateItem('性能优化'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}
