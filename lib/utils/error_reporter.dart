import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ErrorReporter {
  static void showError(dynamic error, {String? title, Duration? duration}) {
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

    Get.showSnackbar(
      GetSnackBar(
        title: title ?? 'Error',
        message: errorMessage,
        duration: duration ?? const Duration(seconds: 2),
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
        forwardAnimationCurve: Curves.easeOutCubic,
        reverseAnimationCurve: Curves.easeInCubic,
        titleText: Text(
          title ?? 'Error',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        messageText: Text(
          errorMessage,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        icon: Icon(
          Icons.error_outline,
          color: Colors.red[400],
          size: 24,
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

  // 用于网络错误的特殊处理
  static void showNetworkError({String? message}) {
    showError(
      message ?? 'Network connection failed. Please check your network settings.',
      title: 'Network Error',
      duration: const Duration(seconds: 3),
    );
  }

  // 用于权限错误的特殊处理
  static void showPermissionError({String? message}) {
    showError(
      message ?? 'Insufficient permissions to perform this operation.',
      title: 'Permission Error',
      duration: const Duration(seconds: 3),
    );
  }

  // 用于业务逻辑错误的特殊处理
  static void showBusinessError({String? message}) {
    showError(
      message ?? 'Operation failed. Please try again later.',
      title: 'Notice',
      duration: const Duration(seconds: 2),
    );
  }

  // 用于成功提示
  static void showSuccess(String message, {String? title, Duration? duration}) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.showSnackbar(
      GetSnackBar(
        title: title ?? 'Success',
        message: message,
        duration: duration ?? const Duration(seconds: 2),
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
          title ?? 'Success',
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
        icon: Icon(
          Icons.check_circle_outline,
          color: Colors.green[400],
          size: 24,
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

  // 用于加载提示
  static void showLoading(String message, {String? title}) {
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
