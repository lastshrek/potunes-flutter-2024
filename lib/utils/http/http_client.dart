import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import 'api_exception.dart';
import 'package:get/get.dart';
import '../../services/user_service.dart';
import '../../utils/error_reporter.dart';

class HttpClient {
  static final HttpClient instance = HttpClient._internal();
  late final Dio _dio;

  HttpClient._internal() {
    final options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
    );

    _dio = Dio(options);

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

    // _dio.interceptors.add(LogInterceptor(
    //   request: true,
    //   requestHeader: true,
    //   requestBody: true,
    //   responseHeader: true,
    //   responseBody: true,
    //   error: true,
    // ));
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
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
      ErrorReporter.showError(e);
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
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data != null) {
          return response.data as T;
        }
        throw ApiException(
          statusCode: response.statusCode ?? 500,
          message: '响应数据为空',
        );
      }

      throw ApiException(
        statusCode: response.statusCode ?? 500,
        message: '请求失败',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 201 && e.response?.data != null) {
        return e.response!.data as T;
      }
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw ApiException(
        statusCode: 500,
        message: e.toString(),
      );
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

  void _handleDioError(DioException e) {
    throw ApiException.fromDioError(e);
  }
}
