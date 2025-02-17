import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio show Response;
import '../../config/api_config.dart';
import 'api_exception.dart';
import 'package:get/get.dart';
import '../../services/user_service.dart';
import '../../utils/error_reporter.dart';
import 'package:flutter/foundation.dart';

class HttpClient {
  static final HttpClient instance = HttpClient._internal();
  final Dio _dio = Dio();

  HttpClient._internal() {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(milliseconds: ApiConfig.connectTimeout);
    _dio.options.receiveTimeout = const Duration(milliseconds: ApiConfig.receiveTimeout);

    // 添加拦截器来打印请求和响应
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ));
    }

    // 添加拦截器处理 token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 从 UserService 获取 token
        final token = Get.find<UserService>().token;
        if (token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<dynamic> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final dio.Response<T> response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data;
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final dio.Response<T> response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data;
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      rethrow;
    }
  }

  void _handleError(dynamic error) {
    if (error is DioException) {
      throw error;
    }
    throw error;
  }

  void _handleDioError(DioException e) {
    throw ApiException.fromDioError(e);
  }
}
