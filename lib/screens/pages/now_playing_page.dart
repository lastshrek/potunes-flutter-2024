import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../services/audio_service.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: AudioService.to.currentPageIndex,
    );
    _extractColors();

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
            appBar: AppBar(
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

        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            final page = _pageController.hasClients ? (_pageController.page ?? 0).toDouble() : 0.0;
            final controlsTop = _getControlsPosition(page, totalHeight);

            return Stack(
              children: [
                // 歌词部分
                Center(
                  child: Text(
                    '暂无歌词',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
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
