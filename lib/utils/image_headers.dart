/// 为网易云音乐 CDN 图片添加 Referer 头
Map<String, String> getImageHeaders(String url) {
  if (url.contains('music.126.net')) {
    return {'Referer': 'https://music.163.com'};
  }
  return {};
}
