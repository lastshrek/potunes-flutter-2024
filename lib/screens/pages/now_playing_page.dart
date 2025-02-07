import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../services/audio_service.dart';
import '../../services/network_service.dart';
import '../../config/api_config.dart';
import '../../models/lyric_line.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  Color? dominantColor;
  Color? secondaryColor;
  static final Map<String, Color> _colorCache = {};
  String? _lastTrackUrl;
  late final PageController _pageController;

  final ScrollController _lyricsScrollController = ScrollController();
  final _showControls = true.obs;
  final _isLoadingLyrics = false.obs;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: AudioService.to.currentPageIndex,
    );
    _extractColors();

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
    super.dispose();
  }

  Future<void> _extractColors() async {
    final track = AudioService.to.currentTrack;
    if (track == null) return;

    final String coverUrl = track['cover_url'] ?? '';
    if (coverUrl == _lastTrackUrl) return;
    _lastTrackUrl = coverUrl;

    if (_colorCache.containsKey(coverUrl)) {
      setState(() {
        dominantColor = _colorCache[coverUrl];
        secondaryColor = dominantColor?.withOpacity(0.7);
      });
      return;
    }

    try {
      final imageProvider = CachedNetworkImageProvider(coverUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200),
      );

      if (!mounted) return;

      setState(() {
        dominantColor = paletteGenerator.darkMutedColor?.color ?? paletteGenerator.dominantColor?.color ?? Colors.black;
        secondaryColor = dominantColor?.withOpacity(0.7);
        _colorCache[coverUrl] = dominantColor!;
      });
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

  // 添加获取当前行高度的方法
  double _getCurrentLineHeight() {
    final lyrics = AudioService.to.lyrics;
    if (lyrics == null || lyrics.isEmpty) return 48.0;
    return _calculateLineHeight(lyrics[AudioService.to.currentLineIndex].toString());
  }

  // 添加计算最大缩放比例的方法
  double _calculateMaxScale(String text, double maxWidth) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 16,
        height: 1.5,
        letterSpacing: 0.5,
        fontWeight: FontWeight.bold, // 使用加粗字体计算，因为当前行会加粗
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      textAlign: TextAlign.left,
    );

    textPainter.layout(maxWidth: maxWidth);

    // 如果文本宽度超过容器宽度的80%，限制缩放比例
    final maxScale = math.min(1.2, (maxWidth * 0.8) / textPainter.width);
    return maxScale;
  }

  @override
  Widget build(BuildContext context) {
    return GetX<AudioService>(
      builder: (controller) {
        final track = controller.currentTrack;
        if (track == null) return const SizedBox.shrink();

        if (track['cover_url'] != _lastTrackUrl) {
          _extractColors();
        }

        return WillPopScope(
          onWillPop: () async {
            if (_pageController.hasClients) {
              AudioService.to.currentPageIndex = _pageController.page?.round() ?? 0;
            }
            return true;
          },
          child: Scaffold(
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
                    dominantColor?.withOpacity(0.8) ?? Colors.black,
                    secondaryColor?.withOpacity(0.5) ?? Colors.black87,
                    Colors.black,
                  ],
                  stops: const [0.0, 0.5, 0.9],
                ),
              ),
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  AudioService.to.currentPageIndex = index;
                },
                children: [
                  _buildPlayerPage(track, controller),
                  _buildLyricsPage(track),
                ],
              ),
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

  Widget _buildPlayerPage(Map<String, dynamic> track, AudioService controller) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
                tag: 'mini_player',
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
                // 歌曲信息
                Text(
                  track['name'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  track['artist'] ?? '',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: GetX<AudioService>(
                        builder: (controller) => FaIcon(
                          FontAwesomeIcons.shuffle,
                          size: 20,
                          color: Colors.white.withOpacity(
                            controller.isShuffleMode ? 1.0 : 0.4,
                          ),
                        ),
                      ),
                      onPressed: AudioService.to.toggleShuffle,
                    ),
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.backward,
                        size: 24,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: controller.previous,
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (dominantColor ?? Theme.of(context).colorScheme.secondary).withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: GetX<AudioService>(
                          builder: (controller) => InkWell(
                            borderRadius: BorderRadius.circular(32),
                            onTap: controller.togglePlay,
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
                    ),
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.forward,
                        size: 24,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: controller.next,
                    ),
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.repeat,
                        size: 20,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: () {
                        // TODO: 实现循环模式切换
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 添加 Coming Up Next 容器
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

  double _getControlsPosition(double page, double totalHeight) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final flex4Height = (totalHeight * 4) / 9;
    final normalPosition = flex4Height * 0.4; // 正常位置
    final bottomPosition = flex4Height - bottomPadding - 96; // 使用整个 flex4Height

    // 根据页面滑动进度计算位置
    if (page <= 0) return normalPosition;
    if (page >= 1) return bottomPosition;
    return normalPosition + (bottomPosition - normalPosition) * page;
  }

  Widget _buildLyricsPage(Map<String, dynamic> track) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final controlsHeight = 64.0 + bottomPadding + 16.0; // 减小控制栏高度
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
                                '加载歌词中...',
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
                        return const Center(
                          child: Text(
                            '暂无歌词',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: GetX<AudioService>(
                                builder: (controller) => FaIcon(
                                  FontAwesomeIcons.shuffle,
                                  size: 20,
                                  color: Colors.white.withOpacity(
                                    controller.isShuffleMode ? 1.0 : 0.4,
                                  ),
                                ),
                              ),
                              onPressed: AudioService.to.toggleShuffle,
                            ),
                            IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.backward,
                                size: 24,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              onPressed: AudioService.to.previous,
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (dominantColor ?? Theme.of(context).colorScheme.secondary).withOpacity(0.2),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: GetX<AudioService>(
                                  builder: (controller) => InkWell(
                                    borderRadius: BorderRadius.circular(32),
                                    onTap: controller.togglePlay,
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
                            ),
                            IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.forward,
                                size: 24,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              onPressed: AudioService.to.next,
                            ),
                            IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.repeat,
                                size: 20,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              onPressed: () {
                                // TODO: 实现循环模式切换
                              },
                            ),
                          ],
                        ),
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
    final currentIndex = AudioService.to.currentIndex;
    final scrollController = ScrollController(
      initialScrollOffset: currentIndex * 72.0, // 72.0 是每个列表项的高度
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 顶部拖动条
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
            // 标题
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
            // 播放列表
            Expanded(
              child: GetX<AudioService>(
                builder: (controller) {
                  final playlist = controller.currentPlaylist;
                  final currentIndex = controller.currentIndex;
                  if (playlist == null) return const SizedBox.shrink();

                  // 重新排序列表，将当前播放的歌曲放在第一位
                  final reorderedPlaylist = [
                    playlist[currentIndex],
                    ...playlist.sublist(0, currentIndex),
                    ...playlist.sublist(currentIndex + 1),
                  ];

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: reorderedPlaylist.length,
                    itemBuilder: (context, index) {
                      final track = reorderedPlaylist[index];
                      final isPlaying = track['id'] == playlist[currentIndex]['id'];

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // 找到原始索引
                            final originalIndex = playlist.indexWhere((t) => t['id'] == track['id']);
                            controller.playTrack(playlist[originalIndex]);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // 播放状态指示器
                                SizedBox(
                                  width: 24,
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
                                const SizedBox(width: 8), // 减小间距
                                // 歌曲封面
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: track['cover_url'] ?? '',
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 8), // 减小间距
                                // 歌曲信息
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // 创建三个错开的动画
    for (int i = 0; i < 3; i++) {
      _animations.add(
        Tween<double>(begin: 3, end: 15).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(i * 0.2, 0.6 + i * 0.2, curve: Curves.easeInOut),
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
    return SizedBox(
      width: 14,
      height: 15,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 2,
                height: _animations[index].value,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
