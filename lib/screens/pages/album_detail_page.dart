import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/audio_service.dart';
import '../../widgets/mini_player.dart';

class AlbumDetailPage extends StatelessWidget {
  final String albumName;
  final List<dynamic> songs;

  const AlbumDetailPage({
    super.key,
    required this.albumName,
    required this.songs,
  });

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

    // 转换歌曲数据为播放列表格式
    final tracks = songs
        .map((item) => {
              'id': item['id'].toString(),
              'nId': item['nId'].toString(),
              'name': item['name'],
              'artist': item['artist'],
              'album': item['album'] ?? '',
              'duration': item['duration'],
              'cover_url': item['cover_url'],
              'url': item['url'],
              'source': 'album', // 添加来源标记
            })
        .toList();

    audioService.playPlaylist(
      tracks,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        albumName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${songs.length} songs',
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
                              if (songs.isNotEmpty) {
                                final shuffledList = List<Map<String, dynamic>>.from(songs)..shuffle();
                                _playSong(shuffledList[0], 0);
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
                              if (songs.isNotEmpty) {
                                _playSong(songs[0], 0);
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
                    final song = songs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: song['cover_url']?.toString() ?? '',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[900],
                            child: const Icon(
                              Icons.music_note,
                              color: Color(0xFFDA5597),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[900],
                            child: const Icon(
                              Icons.music_note,
                              color: Color(0xFFDA5597),
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        song['name']?.toString() ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song['artist']?.toString() ?? 'Unknown Artist',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  },
                  childCount: songs.length,
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
}
