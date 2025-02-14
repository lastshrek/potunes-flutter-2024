import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/audio_service.dart';
import '../services/user_service.dart';
import 'package:get/get.dart';
import '../screens/pages/now_playing_page.dart';
import 'package:palette_generator/palette_generator.dart';

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
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  final ValueNotifier<Color> _backgroundColor = ValueNotifier<Color>(Colors.black);
  int _lastPrintedSecond = -1;
  String? _lastCoverUrl;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // 创建滑动动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    // 监听路由变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = Navigator.of(context);
      navigator.widget.observers.add(
        _RouteObserver(
          onPush: () {
            _slideController.forward();
          },
          onPop: () {
            _slideController.reverse();
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _backgroundColor.dispose();
    super.dispose();
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
        if (controller.currentTrack == null) {
          return const SizedBox.shrink();
        }

        // 当歌曲改变时更新背景色
        if (controller.currentTrack!['cover_url'] != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateBackgroundColor(controller.currentTrack!['cover_url']);
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
          final isFMMode = controller.isFMMode;

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
                  child: isFMMode
                      ? GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                settings: const RouteSettings(name: '/now_playing'),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 播放器主体
                              Container(
                                height: 64,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      child: Hero(
                                        tag: 'player_cover',
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: CachedNetworkImage(
                                            imageUrl: controller.currentTrack!['cover_url'] ?? '',
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
                                    ),
                                    const SizedBox(width: 6),
                                    // 标题和艺术家
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            controller.currentTrack!['name'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            controller.currentTrack!['artist'] ?? '',
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
                                    const SizedBox(width: 8),
                                    // 控制按钮
                                    Obx(() => Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // 播放/暂停按钮
                                            IconButton(
                                              icon: FaIcon(
                                                controller.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              onPressed: controller.togglePlayPause,
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            // FM 模式下的下一首按钮
                                            if (controller.isFMMode)
                                              IconButton(
                                                icon: const FaIcon(
                                                  FontAwesomeIcons.forward,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                onPressed: controller.next,
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            // 喜欢按钮
                                            if (isLoggedIn)
                                              IconButton(
                                                icon: Icon(
                                                  controller.isLike ? Icons.favorite : Icons.favorite_border,
                                                  color: controller.isLike ? const Color(0xFFDA5597) : Colors.white,
                                                ),
                                                onPressed: controller.toggleLike,
                                              ),
                                          ],
                                        )),
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
                        )
                      : GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                settings: const RouteSettings(name: '/now_playing'),
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
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity! > 0) {
                              AudioService.to.previous();
                            } else if (details.primaryVelocity! < 0) {
                              AudioService.to.next();
                            }
                          },
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 播放器主体
                                Container(
                                  height: 64,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        child: Hero(
                                          tag: 'player_cover',
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: CachedNetworkImage(
                                              imageUrl: controller.currentTrack!['cover_url'] ?? '',
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
                                      ),
                                      const SizedBox(width: 6),
                                      // 标题和艺术家
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              controller.currentTrack!['name'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              controller.currentTrack!['artist'] ?? '',
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
                                      const SizedBox(width: 8),
                                      // 控制按钮
                                      Obx(() => Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // 播放/暂停按钮
                                              IconButton(
                                                icon: FaIcon(
                                                  controller.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                onPressed: controller.togglePlayPause,
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              // FM 模式下的下一首按钮
                                              if (controller.isFMMode)
                                                IconButton(
                                                  icon: const FaIcon(
                                                    FontAwesomeIcons.forward,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  onPressed: controller.next,
                                                  padding: EdgeInsets.zero,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              // 喜欢按钮
                                              if (isLoggedIn)
                                                IconButton(
                                                  icon: Icon(
                                                    controller.isLike ? Icons.favorite : Icons.favorite_border,
                                                    color: controller.isLike ? const Color(0xFFDA5597) : Colors.white,
                                                  ),
                                                  onPressed: controller.toggleLike,
                                                ),
                                            ],
                                          )),
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

// 自定义路由观察者
class _RouteObserver extends NavigatorObserver {
  final VoidCallback onPush;
  final VoidCallback onPop;

  _RouteObserver({
    required this.onPush,
    required this.onPop,
  });

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 只在进入 NowPlayingPage 时触发动画
    if (route.settings.name == '/now_playing') {
      onPush();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 只在退出 NowPlayingPage 时触发动画
    if (route.settings.name == '/now_playing') {
      onPop();
    }
  }
}
