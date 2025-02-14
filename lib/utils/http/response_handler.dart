import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;
import 'package:potunes_flutter_2025/utils/error_reporter.dart';
import '../../config/api_config.dart';
import 'api_exception.dart';

class ResponseHandler {
  static dynamic handleResponse(dio.Response response) {
    final statusCode = response.statusCode ?? 500;
    final data = response.data;

    if (statusCode == ApiConfig.successCode) {
      return data;
    }

    throw ApiException(
      statusCode: statusCode,
      message: response.statusMessage ?? ApiConfig.serverError,
      data: data,
    );
  }

  static T handle<T>({
    required dynamic response,
    required int? statusCode,
    String? errorMessage,
  }) {
    final code = statusCode ?? 500;

    if (code == ApiConfig.successCode) {
      // 检查是否是包装的响应格式
      if (response is Map && response['statusCode'] != null && response['data'] != null) {
        final innerData = response['data'];

        // 如果内部数据就是期望的类型
        if (innerData is T) {
          return innerData;
        }

        // 尝试转换内部数据
        try {
          return innerData as T;
        } catch (e) {
          ErrorReporter.showError(e);
          throw ApiException(
            statusCode: code,
            message: 'Inner data type mismatch',
            data: innerData,
          );
        }
      }

      // 如果响应本身就是期望的类型
      if (response is T) {
        return response;
      }

      // 尝试直接转换
      try {
        return response as T;
      } catch (e) {
        ErrorReporter.showError(e);
        throw ApiException(
          statusCode: code,
          message: 'Response type mismatch',
          data: response,
        );
      }
    }

    // 显示错误提示
    Get.snackbar(
      '错误',
      errorMessage ?? '请求失败',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );

    // 处理错误响应
    throw ApiException(
      statusCode: code,
      message: errorMessage ?? '请求失败',
      data: response,
    );
  }
}
