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
        responseBody: false,
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

      // 处理非 200 状态码
      String errorMessage;
      switch (response.statusCode) {
        case 401:
          errorMessage = '未授权，请重新登录';
          break;
        case 403:
          errorMessage = '拒绝访问';
          break;
        case 404:
          errorMessage = '请求错误，未找到该资源';
          break;
        case 405:
          errorMessage = '请求方法未允许';
          break;
        case 408:
          errorMessage = '请求超时';
          break;
        case 500:
          errorMessage = '服务器内部错误';
          break;
        case 501:
          errorMessage = '服务未实现';
          break;
        case 502:
          errorMessage = '网络错误';
          break;
        case 503:
          errorMessage = '服务不可用';
          break;
        case 504:
          errorMessage = '网络超时';
          break;
        case 505:
          errorMessage = 'HTTP版本不受支持';
          break;
        default:
          errorMessage = '请求失败，错误码：${response.statusCode}';
      }

      throw ApiException(
        message: errorMessage,
        statusCode: response.statusCode,
        data: response.data,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException: ${e.type}');
        print('Error message: ${e.message}');
        print('Error response: ${e.response}');
      }

      String errorMessage;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMessage = '连接超时';
          break;
        case DioExceptionType.sendTimeout:
          errorMessage = '请求超时';
          break;
        case DioExceptionType.receiveTimeout:
          errorMessage = '响应超时';
          break;
        case DioExceptionType.badResponse:
          errorMessage = '服务器异常';
          break;
        case DioExceptionType.cancel:
          errorMessage = '请求取消';
          break;
        case DioExceptionType.connectionError:
          errorMessage = '连接错误，请检查网络';
          break;
        default:
          errorMessage = '网络错误，请稍后重试';
      }

      // 显示错误提示
      Get.snackbar(
        '请求失败',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red[700],
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () {
            Get.back(); // 关闭 snackbar
          },
          child: const Text(
            '知道了',
            style: TextStyle(color: Colors.white),
          ),
        ),
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
        '发生未知错误，请稍后重试',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red[700],
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () {
            Get.back(); // 关闭 snackbar
          },
          child: const Text(
            '知道了',
            style: TextStyle(color: Colors.white),
          ),
        ),
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
