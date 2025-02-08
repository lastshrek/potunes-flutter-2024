import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/user_service.dart';
import 'dart:convert';
import '../../controllers/navigation_controller.dart';
import '../../screens/pages/favourites_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  String _formatPhone(String phone) {
    if (phone.isEmpty) return '';
    if (phone.length != 11) return phone;
    // 保留前3位和后4位，中间4位用星号代替
    return '${phone.substring(0, 3)}****${phone.substring(7, 11)}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final userData = UserService.to.userData;
      final phone = userData?['phone']?.toString() ?? '';

      // 添加调试信息
      print('=== User Data Debug ===');
      print('UserData: $userData');
      print('Phone: $phone');
      print('Nickname: ${userData?['nickname']}');
      print('Formatted Phone: ${_formatPhone(phone)}');

      return CustomScrollView(
        slivers: [
          // 用户信息区域
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 头像
                  Stack(
                    children: [
                      // 头像
                      if (userData?['avatar'] != null)
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: MemoryImage(
                            base64Decode(userData!['avatar'].split(',').last),
                          ),
                        )
                      else
                        const CircleAvatar(
                          radius: 50,
                          backgroundColor: Color(0xFF1E1E1E),
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      // 编辑图标
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              // TODO: 处理头像编辑
                            },
                            child: const Icon(
                              Icons.edit,
                              size: 20,
                              color: Color(0xFFDA5597),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 用户名/手机号
                  Text(
                    // 如果 nickname 为空字符串或 null，则显示手机号
                    (userData?['nickname']?.toString().isNotEmpty == true ? userData!['nickname'] : _formatPhone(phone)),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 个人简介
                  Text(
                    userData?['intro']?.toString().isNotEmpty == true ? userData!['intro'] : 'This user is too lazy to leave a signature',
                    style: TextStyle(
                      fontSize: 14,
                      color: userData?['intro']?.toString().isNotEmpty == true ? Colors.grey : Colors.grey[700],
                      fontStyle: userData?['intro']?.toString().isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 功能列表
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // 收藏夹
                  ListTile(
                    leading: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Favourites',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Get.to(() => const FavouritesPage());
                    },
                  ),
                  // 编辑资料
                  ListTile(
                    leading: const Icon(
                      Icons.edit,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      // TODO: 导航到编辑资料页面
                    },
                  ),
                ],
              ),
            ),
          ),

          // 底部空间，防止被 MiniPlayer 遮挡
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),

          // 退出登录按钮
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              alignment: Alignment.bottomCenter,
              child: ElevatedButton(
                onPressed: () async {
                  await UserService.to.logout();
                  // 更新导航控制器的当前页面为首页
                  Get.find<NavigationController>().changePage(0);
                  // 返回首页
                  Get.until((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
