class ApiConfig {
  static String get baseUrl {
    return 'https://api.poche.pink';
  }

  // 歌单相关
  static const String home = '/playlists/home';
  static const String latestCollection = '/v1/playlists/collection/latest';
  static const String latestFinal = '/v1/playlists/final/latest';
  static const String playlist = '/playlists/by';
  static const String lyrics = '/v1/lyrics';
  static const String topCharts = '/tracks/topCharts/week';
  static const String allCollections = '/v1/playlists/collection/all';
  static const String allFinals = '/v1/playlists/finals';
  static const String allAlbums = '/v1/playlists/albums';
  static const String topListDetail = '/netease/toplist';
  static const String neteaseNewAlbum = '/netease/top_album';
  static const String neteaseNewAlbumDetail = '/netease/album';
  // 歌曲相关
  static const String updatePlayCount = '/v1/tracks/play_count';
  // 用户相关
  static const String captcha = '/users/captcha';
  static const String verifyCaptcha = '/users/verify';
  static const String fav = '/v1/users/favs';
  static const String like = '/v1/tracks/like';
  // 版本相关
  static const String version = '/v1/versions';
  // HTTP 状态码
  static const int successCode = 200;
  static const int unauthorizedCode = 401;
  static const int badRequestCode = 422;
  static const int notFoundCode = 400;

  // 用户相关
  static const String updateAvatar = '/v1/users/avatar';
  static const String updateProfile = '/v1/users/profile';

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

  // 添加网易云排行榜的API端点
  static const String neteaseToplist = '/netease/toplist';
  static const String neteasePlaylist = '/netease/playlist';

  // 添加调试服务器配置
  static const String debugHost = '127.0.0.1'; // 本地调试地址
  static const int debugPort = 8888; // 调试端口
}
