import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/network_service.dart';
import '../../config/api_config.dart';
import 'dart:async';

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
      // TODO: 调用发送验证码的 API
      // await NetworkService().sendCaptcha(phone);

      // 模拟API调用成功
      await Future.delayed(const Duration(seconds: 1));

      _showCaptchaInput.value = true;
      _error.value = null;
      _startCountdown(); // 开始倒计时

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('验证码已发送'),
          backgroundColor: Colors.green,
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
      // TODO: 调用登录 API
      // await NetworkService().login(_phoneController.text, _captchaController.text);
      Navigator.pop(context, true); // 返回 true 表示登录成功
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building LoginPage');

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
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          // 主内容区域
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                print('Content area tapped');
                // 阻止事件传递到背景
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    // 关闭按钮
                    Positioned(
                      top: topPadding + 20,
                      left: 4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque, // 确保点击事件被捕获
                        onTapDown: (_) => print('Tap down on close button'),
                        onTapUp: (_) => print('Tap up on close button'),
                        onTap: () {
                          print('Close button tapped!');
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ),
                    // 滚动内容
                    Positioned(
                      top: topPadding + 60,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(
                        child: Container(
                          padding: EdgeInsets.only(
                            left: 24.0,
                            right: 24.0,
                            top: topPadding + 80,
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
