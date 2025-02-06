import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/audio_service.dart';
import 'package:get/get.dart';

class MiniPlayer extends StatelessWidget {
  final bool isAboveBottomBar;

  const MiniPlayer({
    super.key,
    this.isAboveBottomBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentTrack = AudioService.to.currentTrack;
      // 如果没有正在播放的歌曲，返回空的 SizedBox
      if (currentTrack == null) {
        return const SizedBox.shrink();
      }

      return TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: 0,
          end: isAboveBottomBar ? 80 : 0, // 80 是 SalomonBottomBar 的高度
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (context, bottomMargin, child) {
          return Padding(
            padding: EdgeInsets.only(bottom: bottomMargin),
            child: child,
          );
        },
        child: Hero(
          tag: 'mini_player',
          child: Container(
            height: 64,
            color: Colors.black87,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                onTap: () {
                  // TODO: 打开播放详情页
                },
                child: Row(
                  children: [
                    // 封面
                    Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: currentTrack['cover_url'] ?? '',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white54,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 标题和艺术家
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTrack['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentTrack['artist'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 控制按钮
                    Row(
                      children: [
                        IconButton(
                          icon: const FaIcon(
                            FontAwesomeIcons.backward,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: AudioService.to.previous,
                        ),
                        Obx(() {
                          final isPlaying = AudioService.to.isPlaying;
                          return IconButton(
                            icon: FaIcon(
                              isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: AudioService.to.togglePlay,
                          );
                        }),
                        IconButton(
                          icon: const FaIcon(
                            FontAwesomeIcons.forward,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: AudioService.to.next,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
