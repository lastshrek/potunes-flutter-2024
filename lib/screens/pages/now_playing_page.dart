import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../services/audio_service.dart';
import '../../services/network_service.dart';
import '../../config/api_config.dart';

class LyricLine {
  final Duration time;
  final String original;
  final String? translation;

  LyricLine({
    required this.time,
    required this.original,
    this.translation,
  });

  @override
  String toString() {
    if (translation != null) {
      return '$original\n$translation';
    }
    return original;
  }
}

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
  final NetworkService _networkService = NetworkService();
  String? _lyrics;
  String? _currentLyricsId;

  // 只保留 Rx 变量
  final _parsedLyrics = Rx<List<LyricLine>?>(null);
  final _currentLineIndex = RxInt(0);

  // 添加一个 ScrollController 作为类成员
  final ScrollController _lyricsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: AudioService.to.currentPageIndex,
    );
    _extractColors();
    _loadInitialLyrics();

    // 监听页面变化
    _pageController.addListener(() {
      if (_pageController.hasClients && _pageController.page != null) {
        AudioService.to.currentPageIndex = _pageController.page!.round();
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

  Future<void> _loadLyrics(Map<String, dynamic> track) async {
    final id = track['id']?.toString();
    final nId = track['nId']?.toString();

    print('=== Checking lyrics load conditions ===');
    print('Track ID: $id');
    print('Track nID: $nId');
    print('Current lyrics ID: $_currentLyricsId');
    print('Should load lyrics: ${id != null && nId != null && id != _currentLyricsId}');

    if (id == null || nId == null || id == _currentLyricsId) return;
    _currentLyricsId = id;

    try {
      print('=== Loading lyrics for track: ${track['name']} ===');
      print('Making request to: ${ApiConfig.getLyricsPath(id, nId)}');

      final response = await _networkService.getLyrics(id, nId);
      print('=== Raw lyrics response: $response ===');

      if (!mounted) return;

      if (response.containsKey('lrc') || response.containsKey('lrc_cn')) {
        print('=== Lyrics loaded successfully ===');
        print('Original lyrics: ${response['lrc']}');
        print('Translated lyrics: ${response['lrc_cn']}');

        _parsedLyrics.value = _formatLyrics(response);
        _currentLineIndex.value = 0; // 重置当前行索引
      } else {
        print('=== No lyrics found in response ===');
        _parsedLyrics.value = null;
        _currentLineIndex.value = 0;
      }
    } catch (e) {
      print('=== Error loading lyrics: $e ===');
      if (mounted) {
        _parsedLyrics.value = null;
        _currentLineIndex.value = 0;
      }
    }
  }

  List<LyricLine>? _formatLyrics(Map<String, dynamic> response) {
    final original = response['lrc'] as String?;
    final translated = response['lrc_cn'] as String?;

    if (original == null) return null;

    final List<LyricLine> lyrics = [];
    final Map<Duration, String> translationMap = {};

    // 解析翻译歌词
    if (translated != null) {
      final translatedLines = translated.split('\n');
      for (final line in translatedLines) {
        final match = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(line);
        if (match != null) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
          final text = match.group(4)!.trim();

          final time = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );
          translationMap[time] = text;
        }
      }
    }

    // 解析原文歌词
    final originalLines = original.split('\n');
    for (final line in originalLines) {
      final match = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)!.trim();

        final time = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        lyrics.add(LyricLine(
          time: time,
          original: text,
          translation: translationMap[time],
        ));
      }
    }

    // 按时间排序
    lyrics.sort((a, b) => a.time.compareTo(b.time));
    return lyrics.isNotEmpty ? lyrics : null;
  }

  void _loadInitialLyrics() {
    final track = AudioService.to.currentTrack;
    if (track != null) {
      _loadLyrics(track);
    }
  }

  void _updateCurrentLine(Duration position) {
    if (_parsedLyrics.value == null) return;

    int index = _parsedLyrics.value!.indexWhere((line) => line.time > position);
    if (index == -1) {
      index = _parsedLyrics.value!.length;
    }
    index = (index - 1).clamp(0, _parsedLyrics.value!.length - 1);

    if (index != _currentLineIndex.value) {
      _currentLineIndex.value = index;
    }
  }

  // 修改滚动到当前行的方法
  void _scrollToCurrentLine(int currentIndex, double availableHeight) {
    if (!_lyricsScrollController.hasClients) return;

    final itemHeight = 72.0;
    final viewportHeight = _lyricsScrollController.position.viewportDimension;
    final screenCenter = viewportHeight / 2;
    final currentLineOffset = currentIndex * itemHeight;

    // 考虑 ListView 的顶部 padding
    final topPadding = availableHeight / 2;
    final targetOffset = currentLineOffset - screenCenter + topPadding;

    print('=== Lyrics Position Debug ===');
    print('Viewport Height: $viewportHeight');
    print('Screen Center: $screenCenter');
    print('Current Line Index: $currentIndex');
    print('Current Line Offset: $currentLineOffset');
    print('Top Padding: $topPadding');
    print('Target Scroll Offset: $targetOffset');
    print('Current Scroll Offset: ${_lyricsScrollController.offset}');
    print('Max Scroll Extent: ${_lyricsScrollController.position.maxScrollExtent}');
    print('===========================');

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
        if (track == null) return const SizedBox.shrink();

        if (track['cover_url'] != _lastTrackUrl) {
          _extractColors();
        }

        if (track['id']?.toString() != _currentLyricsId) {
          print('=== Track changed, loading new lyrics ===');
          _loadLyrics(track);
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
        double width = pageIndex == page.round() ? 24.0 : 16.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: width,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withOpacity(pageIndex == page.round() ? 1.0 : 0.5),
          ),
        );
      },
    );
  }

  Widget _buildPlayerPage(Map<String, dynamic> track, AudioService controller) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
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
              bottom: bottomPadding + 32.0,
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
                const SizedBox(height: 8),
                Text(
                  track['artist'] ?? '',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32), // 减小间距
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
                const SizedBox(height: 16), // 减小间距
                // 播放控制
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.shuffle,
                        size: 20,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: () {
                        // TODO: 实现随机播放
                      },
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
                const SizedBox(height: 32),
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
        final controlsHeight = 96.0 + bottomPadding; // 控制栏高度
        final appBarHeight = kToolbarHeight;
        final statusBarHeight = MediaQuery.of(context).padding.top;
        final indicatorHeight = 24.0; // 滑动指示器高度
        final topPadding = statusBarHeight + appBarHeight + indicatorHeight;
        final availableHeight = totalHeight - controlsHeight - topPadding;

        return Stack(
          children: [
            // 歌词部分
            GetX<AudioService>(
              builder: (controller) {
                _updateCurrentLine(controller.position);

                return Obx(() {
                  final lyrics = _parsedLyrics.value;
                  final currentIndex = _currentLineIndex.value;

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

                  return Stack(
                    children: [
                      // 顶部渐变遮罩
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: topPadding + 32,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                dominantColor?.withOpacity(0.8) ?? Colors.black,
                                dominantColor?.withOpacity(0.0) ?? Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 底部渐变遮罩
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: controlsHeight + 32,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 歌词列表
                      ListView.builder(
                        controller: _lyricsScrollController,
                        padding: EdgeInsets.only(
                          top: availableHeight / 2,
                          bottom: availableHeight / 2 + controlsHeight,
                          left: 32.0,
                          right: 32.0,
                        ),
                        itemCount: lyrics.length,
                        itemBuilder: (context, index) {
                          final line = lyrics[index];
                          final isCurrentLine = index == currentIndex;

                          if (isCurrentLine) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final itemPosition = index * 72.0;
                              final screenCenter = _lyricsScrollController.position.viewportDimension / 2;
                              final topPadding = availableHeight / 2;

                              print('=== Item Position Debug ===');
                              print('Item Index: $index');
                              print('Item Position: $itemPosition');
                              print('Screen Center: $screenCenter');
                              print('Top Padding: $topPadding');
                              print('Current Scroll Offset: ${_lyricsScrollController.offset}');
                              print('Item to Center Distance: ${itemPosition - (_lyricsScrollController.offset + screenCenter - topPadding)}');
                              print('========================');

                              _scrollToCurrentLine(currentIndex, availableHeight);
                            });
                          }

                          return Container(
                            height: 72.0,
                            alignment: Alignment.center,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: isCurrentLine ? 1.0 : 1.2,
                                end: isCurrentLine ? 1.2 : 1.0,
                              ),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
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
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  );
                });
              },
            ),
            // 控制部分
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 播放控制
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: FaIcon(
                          FontAwesomeIcons.shuffle,
                          size: 20,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        onPressed: () {
                          // TODO: 实现随机播放
                        },
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
                  SizedBox(height: bottomPadding + 32.0),
                ],
              ),
            ),
          ],
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
}
