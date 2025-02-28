import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../services/audio_service.dart';
import '../../models/lyric_line.dart';
import '../../widgets/empty_screen.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import '../../services/user_service.dart';
import '../../widgets/scrolling_text.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> with SingleTickerProviderStateMixin {
  // 添加颜色状态管理
  final _dominantColor = Rx<Color>(Colors.black);
  final _secondaryColor = Rx<Color>(Colors.black.withOpacity(0.7));

  // 添加颜色缓存
  static final Map<String, Color> _colorCache = {};
  String? _lastTrackUrl;

  late final PageController _pageController;

  final ScrollController _lyricsScrollController = ScrollController();
  final _showControls = true.obs;
  Timer? _hideControlsTimer;

  // 添加动画控制器
  late AnimationController _animationController;
  late Animation<double> _bgOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: AudioService.to.currentPageIndex,
    );

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 背景色透明度动画
    _bgOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // 自动开始动画
    _animationController.forward();

    // 延迟提取颜色
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _extractColors();
        }
      });
    });

    // 监听播放位置变化
    ever(AudioService.to.rxPosition, (position) {
      if (_pageController.hasClients) {
        // 添加判断
        final page = _pageController.page;
        if (page != null && page == 1) {
          // 安全访问 page 属性
          final controller = AudioService.to;
          if (controller.lyrics != null) {
            _scrollToCurrentLine(controller.currentLineIndex, 0);
          }
        }
      }
    });

    // 监听页面变化
    _pageController.addListener(() {
      if (_pageController.hasClients && _pageController.page != null) {
        AudioService.to.currentPageIndex = _pageController.page!.round();

        // 当切换到歌词页面时
        if (_pageController.page == 1) {
          _resetHideControlsTimer();
          // 立即获取当前歌词状态
          final controller = AudioService.to;
          if (controller.lyrics != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToCurrentLine(controller.currentLineIndex, 0);
            });
          }
        } else {
          _hideControlsTimer?.cancel();
          _showControls.value = true;
        }
      }
    });
  }

  @override
  void dispose() {
    if (_pageController.hasClients) {
      AudioService.to.currentPageIndex = _pageController.page?.round() ?? 0;
    }
    _lyricsScrollController.dispose();
    _pageController.dispose();
    _hideControlsTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _extractColors() async {
    try {
      final track = AudioService.to.currentTrack;
      if (track == null) return;

      final coverUrl = track['cover_url'] ?? '';
      if (coverUrl.isEmpty) return;

      // 检查是否是相同的图片
      if (coverUrl == _lastTrackUrl) return;
      _lastTrackUrl = coverUrl;

      // 检查缓存
      if (_colorCache.containsKey(coverUrl)) {
        final cachedColor = _colorCache[coverUrl]!;
        _dominantColor.value = cachedColor;
        _secondaryColor.value = cachedColor.withOpacity(0.7);
        return;
      }

      // 使用较小的图片尺寸
      final imageProvider = ResizeImage(
        CachedNetworkImageProvider(coverUrl),
        width: 100,
        height: 100,
      );

      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100),
        maximumColorCount: 8,
      );

      if (!mounted) return;

      final newColor = paletteGenerator.darkMutedColor?.color ?? paletteGenerator.dominantColor?.color ?? Colors.black;

      _dominantColor.value = newColor;
      _secondaryColor.value = newColor.withOpacity(0.7);
      _colorCache[coverUrl] = newColor;
    } catch (e) {
      debugPrint('Error extracting colors: $e');
    }
  }

  // 修改滚动到当前行的方法
  void _scrollToCurrentLine(int currentIndex, double availableHeight) {
    if (!_lyricsScrollController.hasClients) return;

    final lyrics = AudioService.to.lyrics;
    if (lyrics == null) return;

    // 计算当前行之前所有行的总高度
    double offset = 0.0;
    for (int i = 0; i < currentIndex; i++) {
      offset += _calculateLineHeight(lyrics[i].toString());
    }

    // 计算目标偏移量：
    // 1. 计算容器中心点
    final containerHeight = MediaQuery.of(context).size.height - kToolbarHeight - 65;
    final centerY = containerHeight / 2;

    // 2. 计算当前行高度
    final currentLineHeight = _calculateLineHeight(lyrics[currentIndex].toString());

    // 3. 计算目标偏移量
    // offset: 当前行之前所有行的总高度
    // centerY: 容器中心点位置
    // currentLineHeight / 2: 当前行高度的一半，使文本中心对齐
    // listViewTopPadding: ListView 的顶部 padding
    final listViewTopPadding = MediaQuery.of(context).size.height / 2 - kToolbarHeight - 65;
    final targetOffset = offset - centerY + (currentLineHeight / 2) + listViewTopPadding;

    _lyricsScrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _lyricsScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetX<AudioService>(
      builder: (controller) {
        final track = controller.currentTrack;
        final isFMMode = controller.isFMMode;

        if (track == null) return const SizedBox.shrink();

        if (track['cover_url'] != _lastTrackUrl) {
          _extractColors();
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => Navigator.pop(context),
                ),
                centerTitle: true,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPageIndicator(0),
                    const SizedBox(width: 8),
                    _buildPageIndicator(1),
                  ],
                ),
                actions: [
                  // 添加喜欢按钮 - 只在登录时显示
                  Obx(() {
                    if (UserService.to.isLoggedIn) {
                      return IconButton(
                        icon: FaIcon(
                          AudioService.to.isLike ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                          color: AudioService.to.isLike ? const Color(0xFFFF69B4) : Colors.white,
                          size: 20,
                        ),
                        onPressed: AudioService.to.toggleLike,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _dominantColor.value.withOpacity(0.95),
                  _secondaryColor.value,
                  Colors.black,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                AudioService.to.currentPageIndex = index;
              },
              children: [
                _buildPlayerPage(track, controller, isFMMode),
                _buildLyricsPage(track),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageIndicator(int pageIndex) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double page = _pageController.hasClients ? _pageController.page ?? 0 : 0;
        bool isSelected = pageIndex == page.round();
        double width = isSelected ? 16.0 : 4.0; // 选中的长度减半，未选中使用圆点

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: width,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isSelected ? 2 : 2), // 圆角保持一致
            color: Colors.white.withOpacity(isSelected ? 1.0 : 0.5),
          ),
        );
      },
    );
  }

  Widget _buildPlayerPage(Map<String, dynamic> track, AudioService controller, bool isFMMode) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (!isLandscape) {
      // 保持原有的竖屏布局
      return Column(
        children: [
          const SizedBox(height: 40),
          // 专辑封面
          Expanded(
            flex: 5,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  maxHeight: MediaQuery.of(context).size.width * 0.8,
                ),
                child: Hero(
                  tag: 'player_cover',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: track['cover_url'] ?? '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 歌曲信息和控制部分
          Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.only(
                left: 32.0,
                right: 32.0,
                bottom: bottomPadding + 15.0,
              ),
              child: Column(
                children: [
                  // 歌曲标题
                  ScrollingText(
                    title: track['name'] ?? 'Unknown',
                    subtitle: '${track['artist'] ?? 'Unknown Artist'} • ${track['album'] ?? 'Unknown Album'}',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    subtitleStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    width: MediaQuery.of(context).size.width - 64, // 考虑左右padding
                  ),
                  const SizedBox(height: 20),
                  // 进度条
                  GetX<AudioService>(
                    builder: (controller) {
                      final position = controller.position;
                      final duration = controller.duration;
                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                              overlayColor: Colors.white24,
                            ),
                            child: Slider(
                              value: position.inMilliseconds.toDouble(),
                              min: 0,
                              max: duration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                controller.player.seek(
                                  Duration(milliseconds: value.toInt()),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // 播放控制
                  _buildControlButtons(controller, isFMMode),
                  const SizedBox(height: 16),
                  // 添加 Coming Up Next 容器
                  if (!isFMMode)
                    GestureDetector(
                      onTap: _showPlaylistSheet,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              height: 40,
                              width: 160,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.black.withOpacity(0.5),
                                    Colors.black.withOpacity(0.3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 0.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Coming Up Next',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 横屏布局
    return Row(
      children: [
        // 左侧专辑封面
        Expanded(
          flex: 1,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.height * 0.7,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Hero(
                tag: 'player_cover',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: track['cover_url'] ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // 右侧歌曲信息和控制部分
        Expanded(
          flex: 1,
          child: Padding(
            padding: EdgeInsets.only(
              left: 32.0,
              right: 32.0,
              bottom: bottomPadding + 15.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 歌曲标题
                ScrollingText(
                  title: track['name'] ?? 'Unknown',
                  subtitle: '${track['artist'] ?? 'Unknown Artist'} • ${track['album'] ?? 'Unknown Album'}',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  subtitleStyle: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                  width: MediaQuery.of(context).size.width * 0.4, // 根据可用宽度调整文本宽度
                ),
                const SizedBox(height: 20),
                // 进度条
                GetX<AudioService>(
                  builder: (controller) {
                    final position = controller.position;
                    final duration = controller.duration;
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white24,
                          ),
                          child: Slider(
                            value: position.inMilliseconds.toDouble(),
                            min: 0,
                            max: duration.inMilliseconds.toDouble(),
                            onChanged: (value) {
                              controller.player.seek(
                                Duration(milliseconds: value.toInt()),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // 播放控制
                _buildControlButtons(controller, isFMMode),
                const SizedBox(height: 16),
                // Coming Up Next 容器
                if (!isFMMode)
                  GestureDetector(
                    onTap: _showPlaylistSheet,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            height: 40,
                            width: 160,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Coming Up Next',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsPage(Map<String, dynamic> track) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final controlsHeight = 64.0 + bottomPadding + 16.0;
        final appBarHeight = kToolbarHeight + 65;

        return GestureDetector(
          onTapDown: (_) => _resetHideControlsTimer(),
          onVerticalDragStart: (_) => _resetHideControlsTimer(),
          child: Obx(() {
            final showControls = _showControls.value;
            final availableHeight = totalHeight - appBarHeight;

            return Stack(
              children: [
                // 歌词容器
                Positioned(
                  top: appBarHeight - 30,
                  left: 0,
                  right: 0,
                  bottom: -30,
                  child: GetX<AudioService>(
                    builder: (controller) {
                      final lyrics = controller.lyrics;
                      final currentIndex = controller.currentLineIndex;
                      final isLoading = controller.isLoadingLyrics;

                      if (isLoading) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading Lyrics...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (lyrics == null) {
                        return Center(
                          child: emptyScreen(
                            context,
                            0,
                            ':( ',
                            100.0,
                            'Lyrics',
                            60.0,
                            'notAvailable',
                            20.0,
                            useWhite: Theme.of(context).brightness == Brightness.light ? false : true,
                          ),
                        );
                      }

                      return ClipRect(
                        child: ListView.builder(
                          controller: _lyricsScrollController,
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).size.height / 2 - kToolbarHeight - 65,
                            bottom: MediaQuery.of(context).size.height / 2,
                          ),
                          itemCount: lyrics.length,
                          itemBuilder: (context, index) {
                            final line = lyrics[index];
                            final isCurrentLine = index == currentIndex;

                            if (isCurrentLine) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_pageController.page == 1) {
                                  _scrollToCurrentLine(currentIndex, availableHeight);
                                }
                              });
                            }

                            return _buildLyricLine(line, isCurrentLine);
                          },
                        ),
                      );
                    },
                  ),
                ),
                // 播放控制
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: 0,
                  right: 0,
                  bottom: showControls ? 0 : -controlsHeight,
                  child: Container(
                    height: controlsHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.8),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 播放控制按钮
                        _buildControlButtons(AudioService.to, false),
                        SizedBox(height: bottomPadding + 8),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildLyricLine(LyricLine line, bool isCurrentLine) {
    return Container(
      height: _calculateLineHeight(line.toString(), isCurrentLine: isCurrentLine),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.only(
          left: MediaQuery.of(context).padding.left + 10.0,
          top: 6.0,
          bottom: 6.0,
        ),
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - MediaQuery.of(context).padding.left - 20.0) / 1.2,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: isCurrentLine ? 1.0 : 1.0,
              end: isCurrentLine ? 1.2 : 1.0,
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..scale(scale)
                  ..translate(0.0, 0.0),
                alignment: Alignment.centerLeft,
                child: Text(
                  line.toString(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(
                      isCurrentLine ? 1.0 : 0.5,
                    ),
                    fontSize: 16,
                    height: 1.5,
                    letterSpacing: 0.5,
                    fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.left,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 添加重置计时器的方法
  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _showControls.value = true;

    if (_pageController.page == 1) {
      // 只在歌词页面启动计时器
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        _showControls.value = false;
      });
    }
  }

  // 修改计算文本高度的方法
  double _calculateLineHeight(String text, {bool isCurrentLine = false}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: isCurrentLine ? 16 * 1.2 : 16, // 只改变字号，不改变布局宽度
        height: 1.5,
        letterSpacing: 0.5,
        fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
      textAlign: TextAlign.left,
    );

    // 始终使用缩放后的宽度计算布局
    final maxWidth = (MediaQuery.of(context).size.width - MediaQuery.of(context).padding.left - 20.0) / 1.2;
    textPainter.layout(maxWidth: maxWidth);

    final textHeight = textPainter.height;
    const verticalPadding = 24.0;
    final bool hasTranslation = text.contains('\n');
    final extraPadding = hasTranslation ? 12.0 : 0.0;

    return math.max(56.0, textHeight + verticalPadding + extraPadding);
  }

  void _showPlaylistSheet() {
    final playlistScrollController = ScrollController();

    // 预先获取当前歌曲位置
    final currentIndex = AudioService.to.currentIndex;
    final itemHeight = 72.0;
    final targetOffset = currentIndex * itemHeight;

    // 计算初始显示位置（当前歌曲前面几首）
    final initialOffset = math.max(0.0, targetOffset - itemHeight * 2);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          snap: true,
          builder: (context, sheetScrollController) {
            // 先跳转到初始位置
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (playlistScrollController.hasClients) {
                // 先跳到大致位置
                playlistScrollController.jumpTo(initialOffset);

                // 然后平滑滚动到精确位置
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (playlistScrollController.hasClients && mounted) {
                    playlistScrollController.animateTo(
                      targetOffset.clamp(
                        0.0,
                        playlistScrollController.position.maxScrollExtent,
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                });
              }
            });

            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Coming Up Next',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GetX<AudioService>(
                      builder: (controller) {
                        final playlist = controller.displayPlaylist;
                        if (playlist == null || playlist.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        // 使用 ListView.builder 的优化版本
                        return ListView.custom(
                          controller: playlistScrollController,
                          padding: const EdgeInsets.only(
                            top: 8.0,
                            bottom: 72.0,
                          ),
                          // 使用自定义子项代理以优化性能
                          childrenDelegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final track = playlist[index];
                              final isPlaying = index == controller.currentIndex;

                              return RepaintBoundary(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque, // 优化点击响应区域
                                  onTap: () {
                                    Navigator.pop(context);
                                    Future.delayed(const Duration(milliseconds: 300), () {
                                      if (mounted) {
                                        controller.skipToQueueItem(index);
                                      }
                                    });
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Center(
                                            child: isPlaying
                                                ? const _PlayingIndicator()
                                                : Text(
                                                    '${index + 1}',
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.5),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: CachedNetworkImage(
                                            imageUrl: track['cover_url'] ?? '',
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                track['name'] ?? '',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(
                                                    isPlaying ? 1.0 : 0.9,
                                                  ),
                                                  fontSize: 16,
                                                  fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                track['artist'] ?? '',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.5),
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: playlist.length,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                          ),
                          // 优化滚动性能
                          physics: const RangeMaintainingScrollPhysics(),
                          cacheExtent: 72.0 * 10,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      playlistScrollController.dispose();
    });
  }

  Widget _buildControlButtons(AudioService controller, bool isFMMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 随机播放按钮
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.shuffle,
            size: 20,
            color: isFMMode
                ? Colors.grey.withOpacity(0.4) // FM 模式下置灰
                : Colors.white.withOpacity(controller.isShuffleMode ? 1.0 : 0.4),
          ),
          onPressed: isFMMode
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('FM 模式下不支持随机播放'),
                      duration: Duration(seconds: 1),
                    ),
                  )
              : controller.toggleShuffle,
        ),
        // 上一首按钮
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.backward,
            size: 24,
            color: isFMMode
                ? Colors.grey.withOpacity(0.4) // FM 模式下置灰
                : Colors.white.withOpacity(0.8),
          ),
          onPressed: isFMMode
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('FM 模式下不支持上一首'),
                      duration: Duration(seconds: 1),
                    ),
                  )
              : controller.previous,
        ),
        // 播放/暂停按钮
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (_dominantColor.value).withOpacity(0.2),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: controller.togglePlayPause,
              child: Center(
                child: FaIcon(
                  controller.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        // 下一首按钮
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.forward,
            size: 24,
            color: Colors.white.withOpacity(0.8),
          ),
          onPressed: controller.next,
        ),
        // 循环模式按钮
        IconButton(
          icon: isFMMode
              ? FaIcon(
                  FontAwesomeIcons.repeat,
                  size: 20,
                  color: Colors.grey.withOpacity(0.4),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.repeat,
                      size: 20,
                      color: Colors.white,
                    ),
                    if (controller.repeatMode == RepeatMode.single)
                      Positioned(
                        top: 4,
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
          onPressed: isFMMode
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('FM 模式下不支持循环播放'),
                      duration: Duration(seconds: 1),
                    ),
                  )
              : controller.toggleRepeatMode,
        ),
      ],
    );
  }
}

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator({Key? key}) : super(key: key);

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    // 创建三个错开的动画
    for (int i = 0; i < 3; i++) {
      _animations.add(
        Tween<double>(begin: 3, end: 12).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(i * 0.15, 0.45 + i * 0.15, curve: Curves.easeInOut),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // 添加一个容器来显示边界
      width: 24, // 匹配父容器宽度
      height: 15,
      alignment: Alignment.center, // 居中对齐
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // 居中对齐
        mainAxisSize: MainAxisSize.min, // 最小宽度
        children: List.generate(3, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1), // 添加间距
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 2,
                  height: _animations[index].value,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9), // 稍微调整透明度
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
