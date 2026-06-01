/// 网易云 CDN 对 Dart 默认 User-Agent 返回 403，需要伪装浏览器 UA
Map<String, String> getImageHeaders(String url) {
  if (url.contains('music.126.net')) {
    return {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
    };
  }
  return {};
}
