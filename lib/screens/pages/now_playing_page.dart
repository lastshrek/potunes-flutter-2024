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

  @override
  void initState() {
    super.initState();
    _extractColors();
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

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => Navigator.pop(context),
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
            child: Column(
              children: [
                const SizedBox(height: kToolbarHeight + 16),
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
                // 歌曲信息
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      children: [
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
                        const SizedBox(height: 32),
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
                        const SizedBox(height: 24),
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
                                child: InkWell(
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
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
