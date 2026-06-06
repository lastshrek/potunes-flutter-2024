import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'package:potunes_flutter_2025/utils/error_reporter.dart';
import '../../services/user_service.dart';
import '../../services/network_service.dart';
import '../../utils/dialog_utils.dart';
import '../../services/audio_service.dart';
import '../../controllers/navigation_controller.dart';
import '../../utils/password_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nicknameController = TextEditingController();
  final _introController = TextEditingController();
  String? _selectedGender;
  static const List<String> _genderOptions = ['male', 'female', 'other'];
  String _originalNickname = '';
  String _originalIntro = '';
  String? _originalGender;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _nicknameController.addListener(_onFieldChanged);
    _introController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  void _loadUserData() {
    final userData = UserService.to.userData;
    if (userData != null) {
      _originalNickname = userData['nickname']?.toString() ?? '';
      _originalIntro = userData['intro']?.toString() ?? '';
      _originalGender = userData['gender']?.toString() ?? '';
      _nicknameController.text = _originalNickname;
      _introController.text = _originalIntro;
      _selectedGender = _genderOptions.contains(_originalGender) ? _originalGender : null;
    }
  }

  bool _hasChanges() {
    return _nicknameController.text.trim() != _originalNickname ||
        _introController.text.trim() != _originalIntro ||
        _selectedGender != _originalGender;
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_onFieldChanged);
    _introController.removeListener(_onFieldChanged);
    _nicknameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    try {
      AppDialogs.showLoading();

      final result = await NetworkService.instance.updateProfile(
        nickname: _nicknameController.text.trim(),
        intro: _introController.text.trim(),
        gender: _selectedGender,
      );

      Get.back();

      if (result) {
        final userData = UserService.to.userData;
        if (userData != null) {
          userData['nickname'] = _nicknameController.text.trim();
          userData['intro'] = _introController.text.trim();
          userData['gender'] = _selectedGender;
          UserService.to.updateUserData(userData);
        }
        ErrorReporter.showSuccess('Profile updated successfully');
      } else {
        ErrorReporter.showBusinessError(message: 'Failed to update profile');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      ErrorReporter.showError(e);
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await AppDialogs.showConfirm(
      context: context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
    );

    if (confirm == true) {
      try {
        await UserService.to.logout();
        NavigationController.to.changePage(0);
        Get.back();
        ErrorReporter.showSuccess('Logged out successfully');
      } catch (e) {
        ErrorReporter.showError(e);
      }
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final isLoading = false.obs;
    final error = Rx<String?>(null);

    AppDialogs.showFormDialog(
      title: const Text('Change Password', style: TextStyle(color: Colors.white)),
      content: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(error.value!, style: const TextStyle(color: Colors.red)),
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

                if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                  error.value = 'Please fill all fields';
                  return;
                }
                if (newPassword.length < 6) {
                  error.value = 'Password must be at least 6 characters';
                  return;
                }
                if (newPassword != confirmPassword) {
                  error.value = 'Passwords do not match';
                  return;
                }

                try {
                  isLoading.value = true;
                  error.value = null;
                  final phone = UserService.to.userData?['phone']?.toString() ?? '';
                  final hashedOldPassword = hashPassword(oldPassword);
                  final hashedNewPassword = hashPassword(newPassword);
                  final result = await NetworkService.instance.changePassword(
                    phone,
                    hashedOldPassword,
                    hashedNewPassword,
                  );
                  if (result) {
                    Get.back();
                    ErrorReporter.showSuccess('Password changed successfully');
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
                    child: Text(error.value!, style: const TextStyle(color: Colors.red)),
                  ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Old Phone Number',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.phone_android, color: Color(0xFFDA5597)),
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
                  error.value = 'Please enter an 11-digit phone number';
                  return;
                }
                try {
                  isLoading.value = true;
                  error.value = null;
                  final response = await NetworkService.instance.bindPhone(phone);
                  await UserService.to.saveLoginData(response);
                  Get.back();
                  _loadUserData();
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

  @override
  Widget build(BuildContext context) {
    final userData = UserService.to.userData;
    final phone = userData?['phone']?.toString() ?? '';
    final avatarBase64 = userData?['avatar']?.toString();

    String formatPhone(String phone) {
      if (phone.isEmpty) return '';
      if (phone.length != 11) return phone;
      return '${phone.substring(0, 3)}****${phone.substring(7, 11)}';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: avatarBase64 != null
                        ? MemoryImage(
                            base64Decode(avatarBase64.contains(',')
                                ? avatarBase64.split(',').last
                                : avatarBase64),
                          )
                        : null,
                    backgroundColor: const Color(0xFF1E1E1E),
                    child: avatarBase64 == null
                        ? const Icon(Icons.person, size: 36, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData?['nickname']?.toString().isNotEmpty == true
                              ? userData!['nickname']
                              : formatPhone(phone),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userData?['intro']?.toString().isNotEmpty == true
                              ? userData!['intro']
                              : 'No bio yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[300],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            formatPhone(phone),
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Edit Profile Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Profile',
                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  // Nickname
                  const Text('Nickname',
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _nicknameController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        hintText: 'Enter nickname',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Gender
                  const Text('Gender',
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
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
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      hint: const Text('Select gender', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                      onChanged: (value) => setState(() => _selectedGender = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Bio
                  const Text('Bio',
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _introController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        hintText: 'Write a short bio...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _hasChanges() ? _handleSave : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDA5597),
                        disabledBackgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(color: Colors.grey, height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 8),

            // Account Section
            _buildSectionTiles(context),

            const SizedBox(height: 32),
            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTiles(BuildContext context) {
    final phone = UserService.to.userData?['phone']?.toString() ?? '';
    return Column(
      children: [
        _buildListTile(
          icon: Icons.lock_outline,
          title: 'Change Password',
          onTap: _showChangePasswordDialog,
        ),
        if (phone.isEmpty)
          _buildListTile(
            icon: Icons.phone_android,
            title: 'Bind Phone',
            onTap: _showBindPhoneDialog,
          ),
        if (!Platform.isIOS)
          _buildListTile(
            icon: Icons.battery_charging_full,
            title: 'Optimize Background Playback',
            subtitle: 'Allow app to keep playing in the background',
            onTap: _handleBatteryOptimization,
          ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _handleBatteryOptimization() async {
    final audioService = Get.find<AudioService>();
    final result = await audioService.requestBatteryOptimization();
    if (!mounted) return;
    if (result) {
      ErrorReporter.showSuccess('Background playback optimization enabled');
    } else {
      ErrorReporter.showBusinessError(message: 'Please manually disable battery optimization in system settings');
    }
  }
}
