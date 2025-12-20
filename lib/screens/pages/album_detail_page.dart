import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/audio_service.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/common/current_track_highlight.dart';
import '../../widgets/common/cached_image.dart';
import '../../utils/error_reporter.dart';

class AlbumDetailPage extends StatefulWidget {
  final String albumName;
  final List<dynamic> songs;

  const AlbumDetailPage({
    super.key,
    required this.albumName,
    required this.songs,
  });

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  late List<dynamic> _songs;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _songs = widget.songs;
    _validateAndLoadData();
  }

  // 验证和加载数据
  Future<void> _validateAndLoadData() async {
    try {
      // 检查数据是否为空或不完整
      if (_songs.isEmpty) {
        ErrorReporter.showError('Album data is empty');
        return;
      }

      // 验证每首歌曲的必要字段
      for (var song in _songs) {
        if (song is! Map<String, dynamic>) {
          ErrorReporter.showError('Invalid song data format');
          return;
        }

        // 检查必要字段
        if (song['id'] == null || song['nId'] == null || song['url'] == null) {
          ErrorReporter.showError('Song data is incomplete');
          return;
        }
      }

      // 数据验证成功
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorReporter.showError('Error validating album data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(dynamic milliseconds) {
    try {
      final duration = Duration(milliseconds: int.parse(milliseconds.toString()));
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  void _playSong(Map<String, dynamic> song, int index) {
    final audioService = Get.find<AudioService>();

    // 验证歌曲数据
    if (song['id'] == null || song['nId'] == null || song['url'] == null) {
      ErrorReporter.showError('Invalid song data');
      return;
    }

    // 转换歌曲数据为播放列表格式
    final tracks = _songs
        .map((item) {
          try {
            return {
              'id': item['id']?.toString() ?? '',
              'nId': item['nId']?.toString() ?? '',
              'name': item['name'] ?? 'Unknown',
              'artist': item['artist'] ?? 'Unknown Artist',
              'album': item['album'] ?? widget.albumName,
              'duration': item['duration'] ?? 0,
              'cover_url': item['cover_url'] ?? '',
              'url': item['url'] ?? '',
              'source': 'album',
              'ar': item['ar'] ?? [],
              'original_album': item['original_album'] ?? '',
              'original_album_id': item['original_album_id'] ?? 0,
              'mv': item['mv'] ?? 0,
              'playlist_id': item['playlist_id'] ?? 0,
              'type': item['type'] ?? 'potunes',
            };
          } catch (e) {
            ErrorReporter.showError('Error processing song: $e');
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (tracks.isEmpty) {
      ErrorReporter.showError('No valid songs to play');
      return;
    }

    audioService.playPlaylist(
      tracks,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 如果数据为空，显示错误提示
    if (_songs.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.albumName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'No songs available',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 自定义 AppBar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFDA5597),
                          Color(0xFF904C77),
                          Colors.black,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 装饰性圆形图案
                        Positioned(
                          top: 40,
                          right: 20,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: const Center(
                              child: FaIcon(
                                FontAwesomeIcons.compactDisc,
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 专辑信息
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.albumName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_songs.length} songs',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 播放控制按钮
                      Row(
                        children: [
                          // 随机播放按钮
                          IconButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.shuffle,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              if (_songs.isNotEmpty) {
                                final shuffledList = List<dynamic>.from(_songs)..shuffle();
                                _playSong(shuffledList[0] as Map<String, dynamic>, 0);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          // 播放全部按钮
                          IconButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.play,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              if (_songs.isNotEmpty) {
                                _playSong(_songs[0] as Map<String, dynamic>, 0);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 歌曲列表
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _songs[index];
                    return _buildTrackItem(index, song);
                  },
                  childCount: _songs.length,
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 100),
              ),
            ],
          ),
          // MiniPlayer
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackItem(int index, dynamic song) {
    final audioService = Get.find<AudioService>();
    final highlightColor = const Color(0xFFDA5597);

    return Obx(() {
      final currentTrack = audioService.currentTrack;
      final isCurrentTrack = currentTrack != null && ((currentTrack['id']?.toString() == song['id']?.toString()) && (currentTrack['nId']?.toString() == song['nId']?.toString()));

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: CurrentTrackHighlight(
          track: song,
          child: CachedImage(
            url: song['cover_url'] ?? '',
            width: 56,
            height: 56,
          ),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${index + 1}. ',
                style: TextStyle(
                  color: isCurrentTrack ? highlightColor : Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              TextSpan(
                text: song['name'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ).withHighlight(isCurrentTrack),
              ),
            ],
          ),
        ),
        subtitle: Text(
          song['artist'] ?? '',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ).withSubtleHighlight(isCurrentTrack),
        ),
        trailing: Text(
          _formatDuration(song['duration']),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        onTap: () => _playSong(song, index),
      );
    });
  }
}
