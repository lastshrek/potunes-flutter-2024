import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

class ErrorReporter {
  // 添加一个标志来跟踪是否正在显示 snackbar
  static bool _isShowingSnackbar = false;

  static void showError(dynamic error, {String? title, Duration? duration}) {
    // 获取调用栈信息
    final stackTrace = StackTrace.current;
    final caller = _getCallerInfo(stackTrace);

    // 如果已经有 snackbar 在显示，先关闭它
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    // 显示错误
    // ErrorReporter.showError('Failed to load data');

    // 显示网络错误
    // ErrorReporter.showNetworkError(message: 'No internet connection');

    // 显示成功提示
    // ErrorReporter.showSuccess('Track added to playlist');
    String errorMessage = _formatErrorMessage(error);
    // 添加调用者信息
    String fullMessage = '$errorMessage\nCalled from: $caller';

    // 添加控制台打印
    debugPrint('🔴 ERROR: $fullMessage');
    debugPrint('Stack trace:\n$stackTrace');

    _showSnackbar(
      title: title ?? 'Error',
      message: fullMessage,
      duration: duration ?? const Duration(seconds: 2),
      icon: Icon(
        Icons.error_outline,
        color: Colors.red[400],
        size: 24,
      ),
    );
  }

  static String _formatErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }

    if (error is Error) {
      return error.toString().split('\n').first;
    }

    if (error is String) {
      return error;
    }

    return 'An unknown error occurred';
  }

  // 添加获取调用者信息的方法
  static String _getCallerInfo(StackTrace stackTrace) {
    try {
      // 将堆栈跟踪转换为字符串并分割为行
      final lines = stackTrace.toString().split('\n');

      // 跳过前两行（第一行是当前方法，第二行是showError方法）
      for (var i = 2; i < lines.length; i++) {
        final line = lines[i].trim();
        // 排除一些不需要的框架调用
        if (!line.contains('error_reporter.dart') && !line.contains('package:get/') && !line.contains('package:flutter/')) {
          // 提取文件名和行号
          final match = RegExp(r'(?:package:)?([^(]+)\(([^:]+):(\d+)').firstMatch(line);
          if (match != null) {
            final file = match.group(1)?.split('/').last;
            final lineNo = match.group(3);
            return '$file:$lineNo';
          }
          // 如果没有匹配到标准格式，返回简化的调用信息
          return line.split('    ').last;
        }
      }
      return 'unknown location';
    } catch (e) {
      return 'error getting caller info';
    }
  }

  // 添加一个统一的 snackbar 显示方法
  static void _showSnackbar({
    required String title,
    required String message,
    required Duration duration,
    required Widget icon,
  }) {
    // 如果已经在显示，等待一下再显示新的
    if (_isShowingSnackbar) {
      Future.delayed(const Duration(milliseconds: 300), () {
        Get.closeAllSnackbars();
        _showSnackbarInternal(title: title, message: message, duration: duration, icon: icon);
      });
    } else {
      _showSnackbarInternal(title: title, message: message, duration: duration, icon: icon);
    }
  }

  static void _showSnackbarInternal({
    required String title,
    required String message,
    required Duration duration,
    required Widget icon,
  }) {
    _isShowingSnackbar = true;

    Get.showSnackbar(
      GetSnackBar(
        title: title,
        message: message,
        duration: duration,
        backgroundColor: Colors.white,
        borderRadius: 8,
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        snackPosition: SnackPosition.BOTTOM,
        isDismissible: true,
        dismissDirection: DismissDirection.horizontal,
        titleText: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        messageText: Text(
          message,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        icon: icon,
        shouldIconPulse: false,
        snackStyle: SnackStyle.FLOATING,
        boxShadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        onTap: (snack) {
          Get.closeAllSnackbars();
        },
        overlayBlur: 0,
        // 添加回调以更新状态
        snackbarStatus: (status) {
          if (status == SnackbarStatus.CLOSED) {
            _isShowingSnackbar = false;
          }
        },
      ),
    );
  }

  // 用于网络错误的特殊处理
  static void showNetworkError({String? message}) {
    final caller = _getCallerInfo(StackTrace.current);
    final fullMessage = '${message ?? 'Network connection failed. Please check your network settings.'}\nCalled from: $caller';

    // 添加控制台打印
    debugPrint('🌐 NETWORK ERROR: $fullMessage');
    debugPrint('Stack trace:\n${StackTrace.current}');

    _showSnackbar(
      title: 'Network Error',
      message: fullMessage,
      duration: const Duration(seconds: 3),
      icon: Icon(
        Icons.wifi_off,
        color: Colors.orange[400],
        size: 24,
      ),
    );
  }

  // 用于权限错误的特殊处理
  static void showPermissionError({String? message}) {
    final caller = _getCallerInfo(StackTrace.current);
    final fullMessage = '${message ?? 'Insufficient permissions to perform this operation.'}\nCalled from: $caller';

    // 添加控制台打印
    debugPrint('🔒 PERMISSION ERROR: $fullMessage');
    debugPrint('Stack trace:\n${StackTrace.current}');

    showError(
      fullMessage,
      title: 'Permission Error',
      duration: const Duration(seconds: 3),
    );
  }

  // 用于业务逻辑错误的特殊处理
  static void showBusinessError({String? message}) {
    final caller = _getCallerInfo(StackTrace.current);
    final fullMessage = '${message ?? 'Operation failed. Please try again later.'}\nCalled from: $caller';

    // 添加控制台打印
    debugPrint('💼 BUSINESS ERROR: $fullMessage');
    debugPrint('Stack trace:\n${StackTrace.current}');

    showError(
      fullMessage,
      title: 'Notice',
      duration: const Duration(seconds: 2),
    );
  }

  // 用于成功提示
  static void showSuccess(String message, {String? title, Duration? duration}) {
    final caller = _getCallerInfo(StackTrace.current);
    final fullMessage = '$message\nCalled from: $caller';

    // 添加控制台打印
    debugPrint('✅ SUCCESS: $fullMessage');
    debugPrint('Stack trace:\n${StackTrace.current}');

    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    _showSnackbar(
      title: title ?? 'Success',
      message: fullMessage,
      duration: duration ?? const Duration(seconds: 2),
      icon: Icon(
        Icons.check_circle_outline,
        color: Colors.green[400],
        size: 24,
      ),
    );
  }

  // 用于加载提示
  static void showLoading(String message, {String? title}) {
    // 添加控制台打印
    debugPrint('⏳ LOADING: $message');
    if (title != null) {
      debugPrint('Title: $title');
    }
    debugPrint('Stack trace:\n${StackTrace.current}');

    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.showSnackbar(
      GetSnackBar(
        title: title,
        message: message,
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.white,
        borderRadius: 8,
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        snackPosition: SnackPosition.BOTTOM,
        titleText: title != null
            ? Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        messageText: Text(
          message,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        icon: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDA5597)),
          ),
        ),
        shouldIconPulse: false,
        snackStyle: SnackStyle.FLOATING,
        boxShadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}
