import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CachedImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? iconSize;

  const CachedImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: (width * 2).toInt(),
        memCacheHeight: (height * 2).toInt(),
        placeholder: (context, url) => Container(
          color: Colors.grey[800],
          child: Center(
            child: Icon(
              Icons.music_note,
              color: Colors.white54,
              size: iconSize?.toDouble(),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[800],
          child: Center(
            child: Icon(
              Icons.error_outline,
              color: Colors.white54,
              size: iconSize?.toDouble(),
            ),
          ),
        ),
      ),
    );
  }
}
