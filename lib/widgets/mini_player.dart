import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/audio_service.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../screens/pages/now_playing_page.dart';
import '../services/user_service.dart';

class MiniPlayer extends StatefulWidget {
  final bool isAboveBottomBar;

  const MiniPlayer({
    super.key,
    this.isAboveBottomBar = false,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _handleDragEnd(DragEndDetails details) async {
    if (details.primaryVelocity == null) return;

    final controller = Get.find<AudioService>();
    if (details.primaryVelocity! > 0) {
      // 向右滑动，播放上一首
      _slideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(1.0, 0.0),
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ));
      await _slideController.forward();
      controller.previous();
      _slideController.reset();
    } else if (details.primaryVelocity! < 0) {
      // 向左滑动，播放下一首
      _slideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-1.0, 0.0),
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ));
      await _slideController.forward();
      controller.next();
      _slideController.reset();
    }
  }

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
          // print('Track: ${currentTrack['name']}');
          // print('Position: ${formatDuration(position)} / ${formatDuration(duration)}');
          // print('Progress: ${(progress * 100).toStringAsFixed(1)}%');
          _lastPrintedSecond = position.inSeconds;
        }

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0,
            end: widget.isAboveBottomBar ? 90 : 0, // 80 是 SalomonBottomBar 的高度
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
            child: Material(
              // 添加 Material widget 以支持水波纹效果
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return const NowPlayingPage();
                      },
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(0.0, 1.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(begin: begin, end: end).chain(
                          CurveTween(curve: curve),
                        );
                        var offsetAnimation = animation.drive(tween);
                        return SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        );
                      },
                    ),
                  );
                },
                onHorizontalDragEnd: _handleDragEnd,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 播放器主体
                      Container(
                        height: 64,
                        color: Colors.black87,
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
                                // 播放/暂停按钮
                                GetX<AudioService>(
                                  builder: (controller) => IconButton(
                                    icon: FaIcon(
                                      controller.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    onPressed: controller.togglePlay,
                                  ),
                                ),
                                // 喜欢按钮 - 只在登录时显示
                                Obx(() {
                                  if (UserService.to.isLoggedIn) {
                                    return IconButton(
                                      icon: const FaIcon(
                                        FontAwesomeIcons.heart,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        // TODO: 处理喜欢/取消喜欢
                                      },
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 进度条
                      Container(
                        width: double.infinity,
                        height: 2,
                        color: Colors.black87, // 与播放器主体颜色相同
                        child: StreamBuilder<Duration>(
                          stream: controller.player.positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final duration = controller.duration;
                            final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 2,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 添加静态变量来跟踪上次打印的秒数
  static int _lastPrintedSecond = -1;
}
