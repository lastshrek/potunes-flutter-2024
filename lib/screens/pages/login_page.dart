import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/network_service.dart';
import '../../config/api_config.dart';
import 'dart:async';
import '../../services/user_service.dart';
import '../../controllers/app_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _captchaController = TextEditingController();
  final _isLoading = false.obs;
  final _error = Rx<String?>(null);
  final _showCaptchaInput = false.obs;
  final _countdown = 180.obs; // 3分钟倒计时
  Timer? _timer;

  // 验证中国手机号的正则表达式
  final RegExp _phoneRegExp = RegExp(r'^1[3-9]\d{9}$');

  bool _isValidPhoneNumber(String phone) {
    return _phoneRegExp.hasMatch(phone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _captchaController.dispose();
    _timer?.cancel(); // 取消定时器
    super.dispose();
  }

  void _startCountdown() {
    _countdown.value = 180; // 重置倒计时
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown.value > 0) {
        _countdown.value--;
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendCaptcha() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _error.value = '请输入手机号';
      return;
    }

    if (!_isValidPhoneNumber(phone)) {
      _error.value = '请输入正确的手机号';
      return;
    }

    try {
      _isLoading.value = true;
      final networkService = NetworkService.instance;
      await networkService.sendCaptcha(phone);

      _showCaptchaInput.value = true;
      _error.value = null;
      _startCountdown();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '验证码已发送',
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

  Future<void> _login() async {
    if (_phoneController.text.isEmpty || _captchaController.text.isEmpty) {
      _error.value = 'Please enter your phone number and captcha';
      return;
    }

    try {
      _isLoading.value = true;
      final networkService = NetworkService.instance;
      final response = await networkService.verifyCaptcha(
        _phoneController.text.trim(),
        _captchaController.text.trim(),
      );

      print('Login response: $response');

      // 保存登录数据
      await UserService.to.saveLoginData(response);

      // 登录成功
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

  void _navigateToHome() async {
    try {
      // 先执行登出
      await UserService.to.logout();

      // 更新底部导航栏索引
      final appController = Get.find<AppController>();
      appController.currentIndex = 0;

      // 使用 Get.offAllNamed 确保清除导航栈并跳转到首页
      Get.offAllNamed('/', arguments: {'index': 0});

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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 背景点击区域
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // 主内容区域
          Positioned(
            left: 0,
            right: 0,
            top: topPadding + 60,
            bottom: 0,
            child: GestureDetector(
              onTap: () {}, // 阻止点击事件穿透
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    // 顶部栏
                    SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          // 关闭按钮
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    // 内容区域
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
                              const Text(
                                'PoPo\nCollections\nMusic.',
                                style: TextStyle(
                                  color: Color(0xFF00FFA3),
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 48),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _phoneController,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.phone,
                                  textAlign: TextAlign.left,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    hintText: 'Enter Your CellPhone Number',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    prefixIcon: Icon(Icons.phone_android, color: Color(0xFF00FFA3)),
                                    prefixIconConstraints: BoxConstraints(minWidth: 40),
                                    isDense: false,
                                    isCollapsed: false,
                                  ),
                                ),
                              ),
                              Obx(() => _showCaptchaInput.value
                                  ? Column(
                                      children: [
                                        const SizedBox(height: 16),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[900],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: TextField(
                                            controller: _captchaController,
                                            style: const TextStyle(color: Colors.white),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.left,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              hintText: 'Enter Captcha Received',
                                              hintStyle: TextStyle(color: Colors.grey),
                                              prefixIcon: Icon(Icons.message, color: Color(0xFF00FFA3)),
                                              prefixIconConstraints: BoxConstraints(minWidth: 40),
                                              isDense: false,
                                              isCollapsed: false,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink()),
                              const SizedBox(height: 24),
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
                                child: Obx(() {
                                  final bool isCountingDown = _showCaptchaInput.value && _countdown.value > 0;
                                  final String buttonText = _showCaptchaInput.value ? (isCountingDown ? 'Login' : 'Resend Captcha') : 'Send Captcha';

                                  return ElevatedButton(
                                    onPressed: _isLoading.value
                                        ? null
                                        : () {
                                            if (_showCaptchaInput.value) {
                                              if (_countdown.value > 0) {
                                                _login(); // 倒计时中点击执行登录
                                              } else {
                                                _sendCaptcha(); // 倒计时结束后点击重新发送验证码
                                              }
                                            } else {
                                              _sendCaptcha(); // 首次发送验证码
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00FFA3),
                                      foregroundColor: Colors.black,
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
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                buttonText,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (isCountingDown) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  '(${_countdown.value}s)',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                  );
                                }),
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
