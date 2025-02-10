import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/user_service.dart';
import 'dart:convert';
import 'dart:io';
import '../../controllers/navigation_controller.dart';
import '../../screens/pages/favourites_page.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    _avatarBase64 = UserService.to.userData?['avatar'];
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return '';
    if (phone.length != 11) return phone;
    // 保留前3位和后4位，中间4位用星号代替
    return '${phone.substring(0, 3)}****${phone.substring(7, 11)}';
  }

  // 选择图片
  Future<void> _pickImage(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();

      // 显示选择对话框
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.white),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      _processImage(image);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Colors.white),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      _processImage(image);
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  // 处理并上传图片
  Future<void> _processImage(XFile image) async {
    try {
      final File imageFile = File(image.path);

      // 进一步降低压缩参数
      final List<int> compressedBytes = await FlutterImageCompress.compressWithFile(
            imageFile.absolute.path,
            minWidth: 256, // 降低最大宽度
            minHeight: 256, // 降低最大高度
            quality: 50, // 降低压缩质量
          ) ??
          [];

      if (compressedBytes.isEmpty) {
        throw '图片压缩失败';
      }

      // 检查压缩后的大小
      final int sizeInKB = compressedBytes.length ~/ 1024;
      print('Compressed image size: $sizeInKB KB');

      // 如果还是太大，进一步压缩
      if (sizeInKB > 100) {
        final List<int> furtherCompressedBytes = await FlutterImageCompress.compressWithFile(
              imageFile.absolute.path,
              minWidth: 128,
              minHeight: 128,
              quality: 30,
            ) ??
            [];

        if (furtherCompressedBytes.isNotEmpty) {
          print('Further compressed image size: ${furtherCompressedBytes.length ~/ 1024} KB');
          compressedBytes.clear();
          compressedBytes.addAll(furtherCompressedBytes);
        }
      }

      // 转换为 base64
      final String base64Image = 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';

      setState(() {
        _avatarBase64 = base64Image;
      });

      await UserService.to.updateAvatar(base64Image);

      // 添加成功提示
      Get.snackbar(
        'Success',
        'Avatar updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      print('Error processing image: $e');
      Get.snackbar(
        'Error',
        'Failed to update avatar',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = UserService.to.userData;
    final phone = userData?['phone']?.toString() ?? '';

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
                    // 给头像添加点击事件
                    GestureDetector(
                      onTap: () => _pickImage(context),
                      child: _avatarBase64 != null
                          ? CircleAvatar(
                              radius: 50,
                              backgroundImage: MemoryImage(
                                base64Decode(_avatarBase64!.contains(',') ? _avatarBase64!.split(',').last : _avatarBase64!),
                              ),
                            )
                          : const CircleAvatar(
                              radius: 50,
                              backgroundColor: Color(0xFF1E1E1E),
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              ),
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
                          onTap: () => _pickImage(context),
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
            child: TextButton(
              onPressed: () async {
                // 显示确认对话框
                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text(
                        'Confirm Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: const Text(
                        'Are you sure you want to logout?',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );

                // 如果用户确认登出
                if (confirm == true) {
                  try {
                    await UserService.to.logout();
                    NavigationController.to.changePage(0);
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
                    Get.snackbar(
                      'Error',
                      'Failed to logout',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                      margin: const EdgeInsets.all(16),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
