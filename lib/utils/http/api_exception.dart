import 'package:dio/dio.dart';
import '../../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.data,
  });

  factory ApiException.fromDioError(DioException error) {
    late final String message;
    late final int statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = ApiConfig.timeoutError;
        statusCode = 408;
      case DioExceptionType.connectionError:
        message = ApiConfig.networkError;
        statusCode = 503;
      case DioExceptionType.badResponse:
        statusCode = error.response?.statusCode ?? 500;
        final data = error.response?.data;
        if (data is Map) {
          message = data['message']?.toString() ?? data['error']?.toString() ?? ApiConfig.serverError;
        } else {
          message = error.response?.statusMessage ?? ApiConfig.serverError;
        }
      default:
        message = ApiConfig.serverError;
        statusCode = 500;
    }

    return ApiException(
      statusCode: statusCode,
      message: message,
      data: error.response?.data,
    );
  }

  @override
  String toString() => message;
}
