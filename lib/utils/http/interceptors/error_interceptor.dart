import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../api_exception.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw ApiException(
          statusCode: 408,
          message: ApiConfig.timeoutError,
        );
      case DioExceptionType.badResponse:
        throw ApiException(
          statusCode: err.response?.statusCode ?? 500,
          message: err.response?.statusMessage ?? ApiConfig.serverError,
          data: err.response?.data,
        );
      case DioExceptionType.connectionError:
        throw ApiException(
          statusCode: 503,
          message: ApiConfig.networkError,
        );
      default:
        throw ApiException(
          statusCode: 500,
          message: ApiConfig.serverError,
        );
    }
  }
}
