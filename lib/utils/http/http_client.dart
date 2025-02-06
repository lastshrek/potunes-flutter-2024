import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../../config/api_config.dart';
import 'interceptors/error_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'api_exception.dart';
import 'response_handler.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class HttpClient {
  static HttpClient? _instance;
  late Dio _dio;

  HttpClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    // 添加拦截器
    _dio.interceptors.add(ErrorInterceptor());

    // 添加日志拦截器（仅在调试模式下）
    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: true,
        error: true,
        compact: true,
        maxWidth: 90,
      ));
    }
  }

  static HttpClient get instance => _instance ??= HttpClient._internal();

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      if (kDebugMode) {
        print('Making request to: ${_dio.options.baseUrl}$path');
      }

      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options ??
            Options(
              headers: {
                'Accept': 'application/json',
              },
              validateStatus: (status) => status! < 500,
            ),
        cancelToken: cancelToken,
      );

      // 直接处理响应数据
      if (response.statusCode == 200) {
        final responseData = response.data;

        if (kDebugMode) {
          print('Response type: ${responseData.runtimeType}');
          print('Expected type: $T');
          print('Response data: $responseData');
        }

        // 检查响应状态码
        if (responseData is Map<String, dynamic>) {
          final statusCode = responseData['statusCode'];
          if (statusCode != 200) {
            throw ApiException(
              message: responseData['message'] ?? '请求失败',
              statusCode: statusCode,
              data: responseData,
            );
          }

          // 如果响应包含 data 字段
          if (responseData.containsKey('data')) {
            final data = responseData['data'];
            if (kDebugMode) {
              print('Data type: ${data.runtimeType}');
              print('Data content: $data');
            }

            // 如果期望返回类型是 List
            if (T.toString() == 'List<dynamic>') {
              if (data is List) {
                return data as T;
              }
              // 如果 data 本身就是我们需要的数据
              return [data] as T;
            }
            return data as T;
          }
        }

        return responseData as T;
      }

      throw ApiException(
        message: response.statusMessage ?? '请求失败',
        statusCode: response.statusCode,
        data: response.data,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException: ${e.type}');
        print('Error message: ${e.message}');
        print('Error response: ${e.response}');
      }

      // 显示错误提示
      Get.snackbar(
        '错误',
        e.message ?? '网络请求失败',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );

      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Unexpected error: $e');
        print('Stack trace: $stackTrace');
      }

      // 显示错误提示
      Get.snackbar(
        '错误',
        '发生未知错误',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );

      rethrow;
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options ??
            Options(
              headers: {
                'Accept': 'application/json',
              },
              validateStatus: (status) => status! < 500,
            ),
        cancelToken: cancelToken,
      );

      return ResponseHandler.handle<T>(
        response: response.data,
        statusCode: response.statusCode,
        errorMessage: response.statusMessage,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException: ${e.type}');
        print('Error message: ${e.message}');
        print('Error response: ${e.response}');
      }

      Get.snackbar(
        '错误',
        e.message ?? '网络请求失败',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );

      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error: $e');
      }

      Get.snackbar(
        '错误',
        '发生未知错误',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );

      rethrow;
    }
  }
}
