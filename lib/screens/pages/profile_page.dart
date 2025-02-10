import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/user_service.dart';
import 'login_page.dart';
import '../../controllers/navigation_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // 用户信息
            Expanded(
              child: Obx(() {
                final isLoggedIn = UserService.to.isLoggedIn;

                if (!isLoggedIn) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.to(() => const LoginPage());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFA3),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 用户头像和名称
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFF00FFA3),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Test User',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 退出登录按钮
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          print('=== Logout Button Pressed ===');

                          // 先执行登出
                          print('Calling UserService.logout()');
                          await UserService.to.logout();
                          print('UserService.logout() completed');

                          // 检查登录状态
                          print('Current login status: ${UserService.to.isLoggedIn}');

                          // 获取 NavigationController 并模拟点击 home
                          final navigationController = Get.find<NavigationController>();
                          navigationController.changePage(0);

                          // 关闭当前页面，返回到主页
                          Get.back();

                          // 显示退出成功提示
                          Get.snackbar(
                            'Success',
                            'Logged out successfully',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            margin: const EdgeInsets.all(16),
                          );
                        } catch (e) {
                          print('Error during logout: $e');
                          print('Stack trace: ${StackTrace.current}');
                          Get.snackbar(
                            'Error',
                            'Failed to logout',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                            margin: const EdgeInsets.all(16),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
