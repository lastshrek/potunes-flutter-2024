class ApiConfig {
  static String get baseUrl {
    return 'https://api.poche.pink';
  }

  // API 路径
  static const String home = '/playlists/home';
  static const String latestCollection = '/v1/playlists/collection/latest';
  static const String latestFinal = '/v1/playlists/final/latest';
  static const String playlist = '/playlists/by';
  static const String lyrics = '/v1/lyrics';
  static const String topCharts = '/tracks/topCharts/week';
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

  // 获取歌词路径
  static String getLyricsPath(String id, String nId) {
    return '$lyrics/$id/$nId';
  }
}
