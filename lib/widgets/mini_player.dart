import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/audio_service.dart';
import '../services/user_service.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../screens/pages/now_playing_page.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter/rendering.dart';

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
  final ValueNotifier<Color> _backgroundColor = ValueNotifier<Color>(Colors.black);
  int _lastPrintedSecond = -1;
  String? _lastCoverUrl;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _backgroundColor.dispose();
    super.dispose();
  }

  void _handleDragEnd(DragEndDetails details) async {
    if (details.primaryVelocity == null) return;

    final controller = Get.find<AudioService>();
    if (details.primaryVelocity! > 0) {
      // 向右滑动，暂停播放
      _slideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(1.0, 0.0),
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeInOut,
      ));
      await _slideController.forward();
      controller.togglePlayPause();
      _slideController.reverse();
    } else if (details.primaryVelocity! < 0) {
      // 向左滑动，播放下一首
      _slideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-1.0, 0.0),
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeInOut,
      ));
      await _slideController.forward();
      controller.skipToNext();
      _slideController.reverse();
    }
  }

  Future<void> _updateBackgroundColor(String imageUrl) async {
    if (_lastCoverUrl == imageUrl) {
      return;
    }
    _lastCoverUrl = imageUrl;

    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100),
        maximumColorCount: 20,
      );

      // 获取调色板中所有可用的颜色
      final colors = [
        paletteGenerator.darkMutedColor,
        paletteGenerator.darkVibrantColor,
        paletteGenerator.mutedColor,
        paletteGenerator.vibrantColor,
      ].where((color) => color != null).map((color) => color!.color).toList();

      if (colors.isEmpty) {
        _backgroundColor.value = Colors.black;
        return;
      }

      // 按照亮度排序，选择较暗的颜色
      colors.sort((a, b) {
        final aLightness = HSLColor.fromColor(a).lightness;
        final bLightness = HSLColor.fromColor(b).lightness;
        return aLightness.compareTo(bLightness);
      });

      // 选择最暗的颜色，但确保不会太暗
      Color selectedColor = colors.first;
      final hsl = HSLColor.fromColor(selectedColor);

      // 如果颜色太暗，稍微提高亮度
      if (hsl.lightness < 0.1) {
        selectedColor = hsl.withLightness(0.1).toColor();
      }

      // 如果颜色太亮，降低亮度
      if (hsl.lightness > 0.3) {
        selectedColor = hsl.withLightness(0.3).toColor();
      }

      _backgroundColor.value = selectedColor;
    } catch (e) {
      print('Error generating palette: $e');
      _backgroundColor.value = Colors.black;
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

        // 当歌曲改变时更新背景色
        if (currentTrack['cover_url'] != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateBackgroundColor(currentTrack['cover_url']);
          });
        }

        // 打印详细的播放信息（每秒打印一次）
        final position = controller.position;

        // 只在秒数变化时打印
        if (position.inSeconds != _lastPrintedSecond) {
          _lastPrintedSecond = position.inSeconds;
        }

        return Obx(() {
          final isLoggedIn = UserService.to.isLoggedIn;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: widget.isAboveBottomBar ? 90 : 0,
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            builder: (context, bottomMargin, child) {
              return Padding(
                padding: EdgeInsets.only(bottom: bottomMargin),
                child: child,
              );
            },
            child: ValueListenableBuilder<Color>(
              valueListenable: _backgroundColor,
              builder: (context, backgroundColor, child) {
                return Material(
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey[900]!,
                                  width: 0.5,
                                ),
                              ),
                            ),
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
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 播放/暂停按钮
                                      IconButton(
                                        icon: Obx(() => FaIcon(
                                              controller.isPlaying
                                                  ? FontAwesomeIcons.pause // 使用 FontAwesome 的暂停图标
                                                  : FontAwesomeIcons.play, // 使用 FontAwesome 的播放图标
                                              color: Colors.white,
                                              size: 18, // 稍微调小一点图标尺寸
                                            )),
                                        onPressed: controller.togglePlayPause,
                                        padding: EdgeInsets.zero, // 减小内边距使图标看起来更协调
                                        visualDensity: VisualDensity.compact, // 使按钮更紧凑
                                      ),
                                      // 喜欢按钮 - 根据登录状态显示
                                      if (isLoggedIn)
                                        IconButton(
                                          icon: Obx(() => Icon(
                                                controller.isLike ? Icons.favorite : Icons.favorite_border,
                                                color: controller.isLike ? Colors.pink : Colors.white,
                                              )),
                                          onPressed: controller.toggleLike,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 进度条
                          Container(
                            width: double.infinity,
                            height: 2,
                            color: backgroundColor.withOpacity(0.95),
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
                );
              },
            ),
          );
        });
      },
    );
  }
}
