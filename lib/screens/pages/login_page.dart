import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/network_service.dart';
import '../../services/user_service.dart';
import '../../utils/password_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _isLoading = false.obs;
  final _error = Rx<String?>(null);
  final _obscurePassword = true.obs;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final account = _accountController.text.trim();
    final password = _passwordController.text;

    if (account.isEmpty) {
      _error.value = '请输入用户名或手机号';
      return;
    }

    if (password.isEmpty) {
      _error.value = '请输入密码';
      return;
    }

    try {
      _isLoading.value = true;
      _error.value = null;

      final hashedPassword = hashPassword(password);
      final networkService = NetworkService.instance;
      final response = await networkService.login(account, hashedPassword);

      await UserService.to.saveLoginData(response);

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '登录成功',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: 20.0,
            left: 16.0,
            right: 16.0,
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const ForgotPasswordSheet(),
    );
  }

  void _showRegisterSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const RegisterSheet(),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: topPadding + 60,
            bottom: 0,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 24.0,
                            right: 24.0,
                            bottom: 24.0 + bottomInset + bottomPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'PoPo\nCollections\n',
                                      style: TextStyle(
                                        color: const Color(0xFFDA5597),
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: 'Music.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 48),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _accountController,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.text,
                                  textAlign: TextAlign.left,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    hintText: 'Username or Phone Number',
                                    hintStyle:
                                        const TextStyle(color: Colors.grey),
                                    prefixIcon: const Icon(Icons.person_outline,
                                        color: Color(0xFFDA5597)),
                                    prefixIconConstraints:
                                        const BoxConstraints(minWidth: 40),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Obx(() => Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[900],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      controller: _passwordController,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      obscureText: _obscurePassword.value,
                                      textAlign: TextAlign.left,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                        hintText: 'Enter Your Password',
                                        hintStyle:
                                            const TextStyle(color: Colors.grey),
                                        prefixIcon: const Icon(
                                            Icons.lock_outline,
                                            color: Color(0xFFDA5597)),
                                        prefixIconConstraints:
                                            const BoxConstraints(minWidth: 40),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword.value
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () => _obscurePassword
                                              .value = !_obscurePassword.value,
                                        ),
                                      ),
                                    ),
                                  )),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordSheet,
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(color: Color(0xFFDA5597)),
                                  ),
                                ),
                              ),
                              Obx(() {
                                if (_error.value != null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(
                                      _error.value!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading.value ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDA5597),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isLoading.value
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account?",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  TextButton(
                                    onPressed: _showRegisterSheet,
                                    child: const Text(
                                      'Sign Up',
                                      style:
                                          TextStyle(color: Color(0xFFDA5597)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({super.key});

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _isLoading = false.obs;
  final _error = Rx<String?>(null);
  final _success = false.obs;
  final _obscureNewPassword = true.obs;
  final _obscureConfirmPassword = true.obs;

  final RegExp _phoneRegExp = RegExp(r'^1[3-9]\d{9}$');

  @override
  void dispose() {
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final phone = _phoneController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (phone.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _error.value = '请填写所有字段';
      return;
    }

    if (!_phoneRegExp.hasMatch(phone)) {
      _error.value = '请输入正确的手机号';
      return;
    }

    if (newPassword.length < 6) {
      _error.value = '密码长度至少6位';
      return;
    }

    if (newPassword != confirmPassword) {
      _error.value = '两次输入的密码不一致';
      return;
    }

    try {
      _isLoading.value = true;
      _error.value = null;

      final hashedPassword = hashPassword(newPassword);
      final networkService = NetworkService.instance;
      await networkService.resetPassword(phone, hashedPassword);

      _success.value = true;
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      child: Obx(() {
        if (_success.value) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text(
                '密码重置成功',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDA5597),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('返回登录',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reset Password',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your phone number and new password',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: 'Phone Number',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon:
                      Icon(Icons.phone_android, color: Color(0xFFDA5597)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _newPasswordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscureNewPassword.value,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      hintText: 'New Password',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: Color(0xFFDA5597)),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureNewPassword.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey),
                        onPressed: () => _obscureNewPassword.value =
                            !_obscureNewPassword.value,
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            Obx(() => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _confirmPasswordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscureConfirmPassword.value,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      hintText: 'Confirm Password',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: Color(0xFFDA5597)),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureConfirmPassword.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey),
                        onPressed: () => _obscureConfirmPassword.value =
                            !_obscureConfirmPassword.value,
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            if (_error.value != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error.value!,
                    style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading.value ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDA5597),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading.value
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Reset Password',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class RegisterSheet extends StatefulWidget {
  const RegisterSheet({super.key});

  @override
  State<RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<RegisterSheet> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _oldPhoneController = TextEditingController();
  final _bindPhone = false.obs;
  final _isLoading = false.obs;
  final _error = Rx<String?>(null);
  final _success = false.obs;
  final _obscurePassword = true.obs;
  final _obscureConfirmPassword = true.obs;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _oldPhoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final oldPhone = _bindPhone.value ? _oldPhoneController.text.trim() : null;

    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _error.value = '请填写所有字段';
      return;
    }

    if (username.length < 4 || username.length > 20) {
      _error.value = '用户名长度4-20位';
      return;
    }

    if (password.length < 6) {
      _error.value = '密码长度至少6位';
      return;
    }

    if (password != confirmPassword) {
      _error.value = '两次输入的密码不一致';
      return;
    }

    try {
      _isLoading.value = true;
      _error.value = null;

      final hashedPassword = hashPassword(password);
      final networkService = NetworkService.instance;
      final response = await networkService.registerWithBind(username, hashedPassword, oldPhone: oldPhone);

      await UserService.to.saveLoginData(response);

      _success.value = true;
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      child: Obx(() {
        if (_success.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pop(context, true);
          });
          return const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              SizedBox(height: 16),
              Text(
                '注册成功',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Account',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your username and password to register',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: 'Username (4-20 characters)',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon:
                        Icon(Icons.person_outline, color: Color(0xFFDA5597)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Obx(() => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: _obscurePassword.value,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        hintText: 'Password (min 6 chars)',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFFDA5597)),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscurePassword.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey),
                          onPressed: () =>
                              _obscurePassword.value = !_obscurePassword.value,
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              Obx(() => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _confirmPasswordController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: _obscureConfirmPassword.value,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        hintText: 'Confirm Password',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFFDA5597)),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscureConfirmPassword.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey),
                          onPressed: () => _obscureConfirmPassword.value =
                              !_obscureConfirmPassword.value,
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              Obx(() => GestureDetector(
                    onTap: () => _bindPhone.value = !_bindPhone.value,
                    child: Row(
                      children: [
                        Icon(
                          _bindPhone.value
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: const Color(0xFFDA5597),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Bind existing phone account',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )),
              Obx(() {
                if (!_bindPhone.value) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _oldPhoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        hintText: 'Old Phone Number',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.phone_android,
                            color: Color(0xFFDA5597)),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              if (_error.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error.value!,
                      style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading.value ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDA5597),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Sign Up',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
