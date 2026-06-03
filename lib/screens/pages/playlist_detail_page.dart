import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/audio_service.dart';
import '../../widgets/mini_player.dart';
import '../../services/network_service.dart';
import '../../widgets/common/track_list_item.dart';
import '../../widgets/song_options_sheet.dart';
import 'add_to_playlist_page.dart';

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
  Map<String, dynamic>? _playlistData;
  List<Map<String, dynamic>> _tracks = [];
  bool _isPreloading = true;
  String? _cachedUpdatedAt;

  @override
  void initState() {
    super.initState();
    _preloadData();
  }

  String _cacheKey() => 'playlist_detail_${widget.playlistId}';
  String _cacheUpdatedKey() => 'playlist_detail_updated_${widget.playlistId}';

  Future<void> _preloadData() async {
    unawaited(_loadCachedData());
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() => _isPreloading = false);
      _loadPlaylistDetail();
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey());
      if (cached == null) return;

      final data = jsonDecode(cached) as Map<String, dynamic>;
      _cachedUpdatedAt = data['playlist']?['updated_at']?.toString();

      final rawTracks = (data['tracks'] as List<dynamic>?) ?? [];
      final processedTracks = rawTracks.map((track) {
        if (track is Map<String, dynamic>) {
          return {
            ...track,
            'type': track['type'] ?? (track['nId'] != null && track['nId'] != 0 ? 'netease' : 'potunes'),
            'ar': track['ar'] ?? [],
            'original_album': track['original_album'] ?? '',
            'original_album_id': track['original_album_id'] ?? 0,
          };
        }
        return track;
      }).toList();

      if (mounted) {
        setState(() {
          _playlistData = data;
          _tracks = List<Map<String, dynamic>>.from(processedTracks);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveToCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(), jsonEncode(data));
      await prefs.setString(
        _cacheUpdatedKey(),
        data['playlist']?['updated_at']?.toString() ?? '',
      );
    } catch (_) {}
  }

  Future<void> _loadPlaylistDetail() async {
    try {
      final data = await _networkService.getPlaylistDetail(widget.playlistId);
      if (!mounted) return;

      final apiUpdatedAt = data['playlist']?['updated_at']?.toString();

      // 接口数据未更新，跳过
      if (_cachedUpdatedAt != null && apiUpdatedAt == _cachedUpdatedAt) return;

      final rawTracks = (data['tracks'] as List<dynamic>?) ?? [];
      final processedTracks = rawTracks.map((track) {
        if (track is Map<String, dynamic>) {
          return {
            ...track,
            'type': track['type'] ?? (track['nId'] != null && track['nId'] != 0 ? 'netease' : 'potunes'),
            'ar': track['ar'] ?? [],
            'original_album': track['original_album'] ?? '',
            'original_album_id': track['original_album_id'] ?? 0,
          };
        }
        return track;
      }).toList();

      setState(() {
        _playlistData = data;
        _tracks = List<Map<String, dynamic>>.from(processedTracks);
      });

      _saveToCache(data);
    } catch (_) {}
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

  Future<void> _onRefresh() async {
    _cachedUpdatedAt = null;
    await _loadPlaylistDetail();
  }

  void _playSong(Map<String, dynamic> song, int index) {
    final audioService = Get.find<AudioService>();
    audioService.playPlaylist(_tracks, initialIndex: index);
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
          RefreshIndicator(
            onRefresh: _onRefresh,
            displacement: 60,
            color: const Color(0xFFDA5597),
            child: CustomScrollView(
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
            ),
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

  void _showTrackOptions(BuildContext context, Map<String, dynamic> track) {
    SongOptionsSheet.show(
      context: context,
      track: track,
      onAddToPlaylist: () {
        AddToPlaylistPage.show(context: context, track: track);
      },
    );
  }

  Widget _buildTrackItem(int index, Map<String, dynamic> song) {
    return TrackListItem(
      track: song,
      index: index,
      playlist: _tracks,
      trailing: IconButton(
        icon: const Icon(
          Icons.more_vert,
          color: Colors.white54,
          size: 20,
        ),
        onPressed: () => _showTrackOptions(context, song),
      ),
    );
  }
}
