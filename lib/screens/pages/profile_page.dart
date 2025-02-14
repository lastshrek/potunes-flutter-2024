import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/user_service.dart';
import 'dart:convert';
import '../../services/network_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nicknameController = TextEditingController();
  final _introController = TextEditingController();
  String? _selectedGender;
  String? _avatarBase64;
  String? _phone;

  static const List<String> _genderOptions = ['male', 'female', 'other'];

  @override
  void initState() {
    super.initState();
    // 检查登录状态
    if (!UserService.to.isLoggedIn) {
      // 如果未登录，显示提示并返回
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          'Error',
          'Please login first',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
        Get.back();
      });
      return;
    }

    // 如果已登录，加载用户数据
    final userData = UserService.to.userData;
    if (userData != null) {
      _nicknameController.text = userData['nickname']?.toString() ?? '';
      _introController.text = userData['intro']?.toString() ?? '';
      final gender = userData['gender']?.toString() ?? '';
      _selectedGender = _genderOptions.contains(gender) ? gender : null;
      _avatarBase64 = userData['avatar'];
      _phone = userData['phone']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return '';
    if (phone.length != 11) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(7, 11)}';
  }

  Future<void> _handleSave() async {
    try {
      // 显示加载中提示
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      final result = await NetworkService.instance.updateProfile(
        nickname: _nicknameController.text.trim(),
        intro: _introController.text.trim(),
        gender: _selectedGender,
      );

      // 关闭加载对话框
      Get.back();

      if (result) {
        // 更新本地用户数据
        final userData = UserService.to.userData;
        if (userData != null) {
          userData['nickname'] = _nicknameController.text.trim();
          userData['intro'] = _introController.text.trim();
          userData['gender'] = _selectedGender;
          UserService.to.updateUserData(userData);
        }

        // 先返回上一页
        Get.back(result: {
          'nickname': _nicknameController.text.trim(),
          'intro': _introController.text.trim(),
          'gender': _selectedGender,
        });

        // 然后显示成功提示
        Get.snackbar(
          'Success',
          'Profile updated successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to update profile',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      // 确保加载对话框被关闭
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'An error occurred while updating profile',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果未登录，显示加载界面
    if (!UserService.to.isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFDA5597)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像（不可修改）
            Center(
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
            const SizedBox(height: 24),

            // 手机号（不可修改）
            const Text(
              'Phone',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatPhone(_phone ?? ''),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 昵称（可修改）
            const Text(
              'Nickname',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Enter your nickname',
                hintStyle: TextStyle(color: Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 24),

            // 性别选择
            const Text(
              'Gender',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedGender,
                isExpanded: true,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                hint: Text(
                  'Select gender',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                underline: const SizedBox(),
                items: _genderOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value.substring(0, 1).toUpperCase() + value.substring(1),
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // 个人简介
            const Text(
              'Bio',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _introController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Tell us about yourself',
                hintStyle: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
