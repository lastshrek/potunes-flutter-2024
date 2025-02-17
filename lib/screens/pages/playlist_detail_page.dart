import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import '../../services/audio_service.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/common/current_track_highlight.dart';
import '../../widgets/common/cached_image.dart';
import '../../services/network_service.dart';

class PlaylistDetailPage extends StatefulWidget {
  final int playlistId;
  final String title;

  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.title,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final NetworkService _networkService = NetworkService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _playlistData;
  List<dynamic> _tracks = [];
  bool _isPreloading = true;

  @override
  void initState() {
    super.initState();
    _preloadData();
  }

  Future<void> _preloadData() async {
    unawaited(_loadPlaylistDetail());
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isPreloading = false;
      });
    }
  }

  Future<void> _loadPlaylistDetail() async {
    try {
      final data = await _networkService.getPlaylistDetail(widget.playlistId);
      if (mounted) {
        setState(() {
          _playlistData = data;
          _tracks = data['tracks'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
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
    audioService.playPlaylist(
      List<Map<String, dynamic>>.from(_tracks),
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreloading) {
      return const Material(
        color: Colors.black,
        child: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
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
                                FontAwesomeIcons.music,
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
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // 歌单信息
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_tracks.length} songs',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.shuffle,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {
                                if (_tracks.isNotEmpty) {
                                  final shuffledList = List<Map<String, dynamic>>.from(_tracks)..shuffle();
                                  _playSong(shuffledList[0], 0);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.play,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {
                                if (_tracks.isNotEmpty) {
                                  _playSong(_tracks[0], 0);
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
                      final song = _tracks[index];
                      return _buildTrackItem(index, song);
                    },
                    childCount: _tracks.length,
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: 100),
                ),
              ],
            ],
          ),
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
      final isCurrentTrack = audioService.isCurrentTrack(song);

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
