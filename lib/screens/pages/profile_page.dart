import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:potunes_flutter_2025/utils/error_reporter.dart';
import '../../services/user_service.dart';
import 'dart:convert';
import '../../services/network_service.dart';
import '../../utils/password_utils.dart';
import '../../utils/dialog_utils.dart';

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
      AppDialogs.showLoading();

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

        ErrorReporter.showSuccess('Profile updated successfully');
      } else {
        ErrorReporter.showBusinessError(message: 'Failed to update profile');
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
                        base64Decode(_avatarBase64!.contains(',')
                            ? _avatarBase64!.split(',').last
                            : _avatarBase64!),
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

            // 手机号
            const Text(
              'Phone',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: (_phone == null || _phone!.isEmpty) ? _showBindPhoneDialog : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _phone != null && _phone!.isNotEmpty
                            ? _formatPhone(_phone!)
                            : 'Not set',
                        style: TextStyle(
                          color: _phone != null && _phone!.isNotEmpty
                              ? Colors.grey
                              : Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_phone == null || _phone!.isEmpty)
                      const Text(
                        'Bind',
                        style: TextStyle(
                          color: Color(0xFFDA5597),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
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
            const SizedBox(height: 32),

            // 修改密码按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _showChangePasswordDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDA5597)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Change Password',
                  style: TextStyle(color: Color(0xFFDA5597)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBindPhoneDialog() {
    final phoneController = TextEditingController();
    final isLoading = false.obs;
    final error = Rx<String?>(null);

    AppDialogs.showFormDialog(
      title: const Text('Bind Phone', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error.value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(error.value!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Old Phone Number',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon:
                        Icon(Icons.phone_android, color: Color(0xFFDA5597)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will merge the old account\'s data\n(favorites, playlists) into your current account.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            )),
      ),
      actions: [
        AppDialogs.styledCancelButton(),
        Obx(() => AppDialogs.styledFormAction(
              text: 'Bind',
              isLoading: isLoading.value,
              onPressed: () async {
                final phone = phoneController.text.trim();
                if (phone.length != 11) {
                  error.value = '请输入11位手机号';
                  return;
                }
                try {
                  isLoading.value = true;
                  error.value = null;
                  final response = await NetworkService.instance.bindPhone(phone);
                  await UserService.to.saveLoginData(response);
                  Get.back();
                  setState(() {
                    _phone = phone;
                  });
                  ErrorReporter.showSuccess('Phone bound successfully');
                } catch (e) {
                  error.value = e.toString();
                } finally {
                  isLoading.value = false;
                }
              },
            )),
      ],
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final isLoading = false.obs;
    final error = Rx<String?>(null);

    AppDialogs.showFormDialog(
      title: const Text('Change Password',
          style: TextStyle(color: Colors.white)),
      content: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(error.value!,
                      style: const TextStyle(color: Colors.red)),
                ),
              TextField(
                controller: oldPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Old Password',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'New Password',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Confirm New Password',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          )),
      actions: [
        AppDialogs.styledCancelButton(),
        Obx(() => AppDialogs.styledFormAction(
              text: 'Confirm',
              isLoading: isLoading.value,
              onPressed: () async {
                final oldPassword = oldPasswordController.text;
                final newPassword = newPasswordController.text;
                final confirmPassword = confirmPasswordController.text;

                if (oldPassword.isEmpty ||
                    newPassword.isEmpty ||
                    confirmPassword.isEmpty) {
                  error.value = '请填写所有字段';
                  return;
                }

                if (newPassword.length < 6) {
                  error.value = '密码长度至少6位';
                  return;
                }

                if (newPassword != confirmPassword) {
                  error.value = '两次输入的密码不一致';
                  return;
                }

                try {
                  isLoading.value = true;
                  error.value = null;

                  final phone =
                      UserService.to.userData?['phone']?.toString() ??
                          '';
                  final hashedOldPassword = hashPassword(oldPassword);
                  final hashedNewPassword = hashPassword(newPassword);

                  final result =
                      await NetworkService.instance.changePassword(
                    phone,
                    hashedOldPassword,
                    hashedNewPassword,
                  );

                  if (result) {
                    Get.back();
                    ErrorReporter.showSuccess('密码修改成功');
                  }
                } catch (e) {
                  error.value = e.toString();
                } finally {
                  isLoading.value = false;
                }
              },
            )),
      ],
    );
  }
}
