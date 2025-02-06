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
    return GetX<AudioService>(
      builder: (controller) {
        final currentTrack = controller.currentTrack;
        if (currentTrack == null) {
          return const SizedBox.shrink();
        }

        // 添加时间格式化函数
        String formatDuration(Duration duration) {
          String twoDigits(int n) => n.toString().padLeft(2, '0');
          String minutes = twoDigits(duration.inMinutes.remainder(60));
          String seconds = twoDigits(duration.inSeconds.remainder(60));
          return '$minutes:$seconds';
        }

        // 打印详细的播放信息（每秒打印一次）
        final position = controller.position;
        final duration = controller.duration;
        final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;

        // 只在秒数变化时打印
        if (position.inSeconds != _lastPrintedSecond) {
          print('Track: ${currentTrack['name']}');
          print('Position: ${formatDuration(position)} / ${formatDuration(duration)}');
          print('Progress: ${(progress * 100).toStringAsFixed(1)}%');
          _lastPrintedSecond = position.inSeconds;
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity, // 确保宽度与父级相同
                  height: 2,
                  color: Colors.white.withOpacity(0.1),
                  child: StreamBuilder<Duration>(
                    stream: controller.player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = controller.duration;
                      final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;

                      print('[DEBUG] Progress bar value: $progress');

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 2,
                        ),
                      );
                    },
                  ),
                ),
                Container(
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
                                onPressed: controller.previous,
                              ),
                              IconButton(
                                icon: FaIcon(
                                  controller.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: controller.togglePlay,
                              ),
                              IconButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.forward,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: controller.next,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 添加静态变量来跟踪上次打印的秒数
  static int _lastPrintedSecond = -1;
}
