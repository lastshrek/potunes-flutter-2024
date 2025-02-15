import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/audio_service.dart';
import '../services/user_service.dart';
import 'package:get/get.dart';
import '../screens/pages/now_playing_page.dart';
import 'package:palette_generator/palette_generator.dart';
import '../utils/error_reporter.dart';

class MiniPlayer extends StatefulWidget {
  final bool isAboveBottomBar;

  const MiniPlayer({
    super.key,
    this.isAboveBottomBar = false,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _swipeController;
  Animation<double>? _swipeAnimation;
  final ValueNotifier<Color> _backgroundColor = ValueNotifier<Color>(Colors.black);
  int _lastPrintedSecond = -1;
  String? _lastCoverUrl;

  // 滑动相关变量
  double _dragStartX = 0;
  double _dragDistance = 0;
  bool _isDragging = false;

  // 添加用于切换动画的变量
  late final PageController _pageController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    // 初始化滑动动画
    _swipeAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOutCubic,
    ));

    // 初始化 PageController，设置 viewportFraction 使页面之间有间距
    _pageController = PageController(
      initialPage: 1,
      viewportFraction: 1.0,
    );

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
    _swipeController.dispose();
    _backgroundColor.dispose();
    _pageController.dispose();
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
      ErrorReporter.showError(e);
      _backgroundColor.value = Colors.black;
    }
  }

  // 处理滑动手势
  void _handleHorizontalDragStart(DragStartDetails details) {
    // FM 模式下不允许滑动切歌
    if (AudioService.to.isFMMode) return;

    _isDragging = true;
    _dragStartX = details.localPosition.dx;
    _dragDistance = 0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || AudioService.to.isFMMode) return;

    setState(() {
      _dragDistance = details.localPosition.dx - _dragStartX;
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging || AudioService.to.isFMMode) return;

    final velocity = details.primaryVelocity ?? 0;
    final distance = _dragDistance.abs();
    final width = context.size?.width ?? 0;

    if (distance > width * 0.2 || velocity.abs() > 300) {
      final isNext = _dragDistance < 0;
      setState(() => _isAnimating = true);

      // 设置动画目标页
      final targetPage = isNext ? 2 : 0;

      // 执行页面切换动画
      _pageController
          .animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      )
          .then((_) {
        // 动画完成后切换歌曲
        if (isNext) {
          AudioService.to.skipToNext();
        } else {
          AudioService.to.previous();
        }

        // 重置状态
        setState(() {
          _dragDistance = 0;
          _isDragging = false;
          _isAnimating = false;
        });

        // 重置到中间页
        _pageController.jumpToPage(1);
      });
    } else {
      // 距离不够，回弹
      _swipeAnimation = Tween<double>(
        begin: _dragDistance,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _swipeController,
        curve: Curves.easeOutCubic,
      ));

      _swipeController.reset();
      _swipeController.forward().then((_) {
        setState(() {
          _dragDistance = 0;
          _isDragging = false;
        });
      });
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
                return _buildContent(controller, backgroundColor);
              },
            ),
          );
        });
      },
    );
  }

  Widget _buildContent(AudioService controller, Color backgroundColor) {
    return SizedBox(
      height: 66,
      child: PageView.builder(
        controller: _pageController,
        physics: controller.isFMMode ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
        onPageChanged: (page) {
          if (page != 1) {
            // 切换歌曲
            if (page == 0) {
              AudioService.to.previous();
            } else {
              AudioService.to.skipToNext();
            }
            // 重置到中间页
            _pageController.jumpToPage(1);
          }
        },
        itemBuilder: (context, index) {
          if (index == 1) {
            return controller.isFMMode ? _buildFMMode(controller, backgroundColor) : _buildNormalMode(controller, backgroundColor);
          } else if (index == 0) {
            // 左侧页面（上一首）
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: controller.isFMMode ? _buildFMMode(controller, backgroundColor) : _buildNormalMode(controller, backgroundColor),
            );
          } else {
            // 右侧页面（下一首）
            return Padding(
              padding: const EdgeInsets.only(left: 16),
              child: controller.isFMMode ? _buildFMMode(controller, backgroundColor) : _buildNormalMode(controller, backgroundColor),
            );
          }
        },
        itemCount: 3,
      ),
    );
  }

  Widget _buildFMMode(AudioService controller, Color backgroundColor) {
    return GestureDetector(
      onTap: () => _navigateToNowPlaying(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlayerBody(controller),
          _buildProgressBar(controller, backgroundColor),
        ],
      ),
    );
  }

  Widget _buildNormalMode(AudioService controller, Color backgroundColor) {
    return GestureDetector(
      onTap: () => _navigateToNowPlaying(),
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlayerBody(controller),
            _buildProgressBar(controller, backgroundColor),
          ],
        ),
      ),
    );
  }

  void _navigateToNowPlaying() {
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
  }

  Widget _buildPlayerBody(AudioService controller) {
    return Container(
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
                  // 下一首按钮 - 只在非 FM 模式下显示
                  if (controller.isFMMode)
                    IconButton(
                      icon: const FaIcon(
                        FontAwesomeIcons.forward,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: controller.skipToNext,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  // 喜欢按钮
                  if (UserService.to.isLoggedIn)
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
    );
  }

  Widget _buildProgressBar(AudioService controller, Color backgroundColor) {
    return Container(
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
