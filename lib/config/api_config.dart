import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    return 'https://api.poche.pink';
  }

  // API 路径
  static const String home = '/playlists/home';
  static const String latestCollection = '/v1/playlists/collection/latest';
  static const String latestFinal = '/v1/playlists/final/latest';
  static const String search = '/search';
  static const String topCharts = '/top-charts';
  static const String library = '/library';

  // HTTP 状态码
  static const int successCode = 200;
  static const int unauthorizedCode = 401;
  static const int badRequestCode = 422;
  static const int notFoundCode = 400;

  // 超时时间
  static const int connectTimeout = 15000; // 15s
  static const int receiveTimeout = 15000; // 15s

  // 错误信息
  static const String networkError = '网络连接失败';
  static const String timeoutError = '请求超时';
  static const String serverError = '服务器错误';
}
