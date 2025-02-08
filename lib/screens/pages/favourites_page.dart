import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/network_service.dart';
import '../../widgets/mini_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/audio_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FavouritesPage extends StatelessWidget {
  const FavouritesPage({super.key});

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

  void _playSong(Map<String, dynamic> song, List<dynamic> playlist, int index) {
    final audioService = Get.find<AudioService>();

    // 转换歌曲数据为播放列表格式，并添加 source 标记
    final tracks = playlist
        .map((item) => {
              'id': item['id'].toString(),
              'nId': item['nId'].toString(),
              'name': item['name'],
              'artist': item['artist'],
              'album': item['album'] ?? '',
              'duration': item['duration'],
              'cover_url': item['cover_url'],
              'url': item['url'],
              'source': 'favourites', // 添加来源标记
            })
        .toList();

    // 打印转换后的数据
    print('=== Converted Track Data ===');
    print('First track: ${tracks[0]}');

    // 使用 AudioService 的正确方法来播放
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
          Column(
            children: [
              // AppBar
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
                title: const Text(
                  'Favourites',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      // TODO: 实现搜索功能
                    },
                  ),
                ],
              ),

              // 主内容区域
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _loadFavourites(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFDA5597),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading favourites',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }

                    final favourites = snapshot.data ?? [];

                    return Column(
                      children: [
                        // 顶部统计信息和控制按钮
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Color(0xFFDA5597),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${favourites.length} Songs',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              // 随机播放按钮
                              IconButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.shuffle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  if (favourites.isNotEmpty) {
                                    final shuffledList = List<Map<String, dynamic>>.from(favourites)..shuffle();
                                    _playSong(shuffledList[0], shuffledList, 0);
                                  }
                                },
                              ),
                              // 播放全部按钮
                              IconButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.play,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  if (favourites.isNotEmpty) {
                                    _playSong(favourites[0], favourites, 0);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        // 歌曲列表
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: favourites.length,
                            itemBuilder: (context, index) {
                              final song = favourites[index];
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatDuration(song['duration']),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () {
                                        // TODO: 显示更多选项菜单
                                      },
                                      child: const Icon(
                                        Icons.more_vert,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  // 打印歌曲数据
                                  print('=== Playing song ===');
                                  print('Song data: $song');
                                  print('Required fields:');
                                  print('id: ${song['id']}');
                                  print('nId: ${song['nId']}');
                                  print('url: ${song['url']}');
                                  print('name: ${song['name']}');
                                  print('artist: ${song['artist']}');
                                  print('duration: ${song['duration']}');
                                  print('cover_url: ${song['cover_url']}');

                                  _playSong(song, favourites, index);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
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

  Future<List<dynamic>> _loadFavourites() async {
    try {
      final networkService = NetworkService();
      return await networkService.getFavourites();
    } catch (e) {
      print('Error loading favourites: $e');
      return [];
    }
  }
}

class PlayButton extends StatelessWidget {
  final Color? backgroundColor;
  final List<Map<String, dynamic>> tracks;

  const PlayButton({
    super.key,
    required this.backgroundColor,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final audioService = Get.find<AudioService>();

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? const Color(0xff161616),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => audioService.playPlaylist(
            tracks,
            initialIndex: 0,
          ),
          child: Obx(() => Center(
                child: FaIcon(
                  audioService.isPlaying && audioService.isCurrentPlaylist(tracks) ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                  color: Colors.white,
                  size: 24,
                ),
              )),
        ),
      ),
    );
  }
}
