import 'package:dio/dio.dart';
import '../../config/api_config.dart';
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
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('REQUEST[${options.method}] => PATH: ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('RESPONSE[${response.statusCode}] => DATA: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print('ERROR[${e.response?.statusCode}] => ${e.message}');
          return handler.next(e);
        },
      ),
    );
  }

  static HttpClient get instance => _instance ??= HttpClient._internal();

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      print('Starting request to: ${_dio.options.baseUrl}$path');

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

      if (response.data is T) {
        return response.data;
      }

      throw ApiException(
        statusCode: response.statusCode ?? 500,
        message: 'Response type mismatch',
        data: response.data,
      );
    } catch (e) {
      print('Error in request: $e');
      _handleError(e);
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
        statusCode: response.statusCode ?? 500,
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

  void _handleError(dynamic error) {
    if (error is DioException) {
      throw ApiException.fromDioError(error);
    } else if (error is ApiException) {
      throw error;
    } else {
      throw ApiException(
        statusCode: 500,
        message: error.toString(),
      );
    }
  }
}
