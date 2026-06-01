import 'package:flutter/material.dart';

class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  static ImageCacheManager get instance => _instance;

  ImageCacheManager._internal() {
    // 设置图片缓存大小
    PaintingBinding.instance.imageCache.maximumSize = 200;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200 MB
  }

  Widget buildImage({
    required String url,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: (width * 1.5).toInt(),
      cacheHeight: (height * 1.5).toInt(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: frame != null
              ? child
              : placeholder ??
                  Container(
                    width: width,
                    height: height,
                    color: const Color(0xff161616),
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: const Color(0xff161616),
              child: const Icon(Icons.music_note, color: Colors.white54),
            );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: const Color(0xff161616),
              child: const Icon(Icons.music_note, color: Colors.white54),
            );
      },
    );
  }

  void clearCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
