import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'api_exception.dart';

class ResponseHandler {
  static T handle<T>({
    required dynamic response,
    required int? statusCode,
    String? errorMessage,
  }) {
    if (statusCode == 200) {
      // 如果响应本身就是期望的类型
      if (response is T) {
        return response;
      }

      // 如果响应是 Map 且包含 data 字段，并且不是期望 List 类型
      if (response is Map && response.containsKey('data') && T != List<dynamic>) {
        return response['data'] as T;
      }

      // 其他情况尝试直接转换
      return response as T;
    } else {
      // 显示错误提示
      Get.snackbar(
        '错误',
        errorMessage ?? '请求失败',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      throw ApiException(
        message: errorMessage ?? '请求失败',
        statusCode: statusCode,
        data: response,
      );
    }
  }
}
