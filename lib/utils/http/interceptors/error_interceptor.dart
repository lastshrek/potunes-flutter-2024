import 'package:dio/dio.dart';
import '../api_exception.dart';
import '../../../config/api_config.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw ApiException(message: ApiConfig.timeoutError);
      case DioExceptionType.badResponse:
        switch (err.response?.statusCode) {
          case ApiConfig.unauthorizedCode:
            throw ApiException(
              message: '未授权',
              statusCode: ApiConfig.unauthorizedCode,
            );
          case ApiConfig.notFoundCode:
            throw ApiException(
              message: '请求不存在',
              statusCode: ApiConfig.notFoundCode,
            );
          default:
            throw ApiException(
              message: err.response?.statusMessage ?? ApiConfig.serverError,
              statusCode: err.response?.statusCode,
            );
        }
      default:
        throw ApiException(message: ApiConfig.networkError);
    }
  }
}
