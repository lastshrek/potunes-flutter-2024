import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/network_service.dart';
import '../../widgets/mini_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/audio_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../screens/pages/album_detail_page.dart';

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

  // 添加一个方法来处理专辑数据
  Map<String, List<dynamic>> _groupByAlbum(List<dynamic> songs) {
    final Map<String, List<dynamic>> albums = {};
    for (var song in songs) {
      final albumName = song['album'] ?? 'Unknown Album';
      if (!albums.containsKey(albumName)) {
        albums[albumName] = [];
      }
      albums[albumName]!.add(song);
    }
    return albums;
  }

  @override
  Widget build(BuildContext context) {
    // 添加分段选择器的状态
    final selectedIndex = 0.obs;

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
                    final albums = _groupByAlbum(favourites);

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

                        // 添加分段选择器
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Obx(
                            () => Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => selectedIndex.value = 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selectedIndex.value == 0 ? const Color(0xFFDA5597) : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Songs',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => selectedIndex.value = 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selectedIndex.value == 1 ? const Color(0xFFDA5597) : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Albums',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 内容区域
                        Expanded(
                          child: Obx(
                            () => selectedIndex.value == 0
                                ? ListView.builder(
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
                                        trailing: Text(
                                          _formatDuration(song['duration']),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onTap: () => _playSong(song, favourites, index),
                                      );
                                    },
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 100),
                                    itemCount: albums.length,
                                    itemBuilder: (context, index) {
                                      final albumName = albums.keys.elementAt(index);
                                      final albumSongs = albums[albumName]!;
                                      final firstSong = albumSongs.first;

                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        leading: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFFDA5597),
                                                Color(0xFF904C77),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: const Offset(2, 2),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              // 装饰性圆形图案
                                              Positioned(
                                                top: -10,
                                                right: -10,
                                                child: Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white.withOpacity(0.1),
                                                  ),
                                                ),
                                              ),
                                              // 中心图标
                                              const Center(
                                                child: FaIcon(
                                                  FontAwesomeIcons.compactDisc,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                              // 装饰性条纹
                                              Positioned(
                                                bottom: 4,
                                                left: 4,
                                                right: 4,
                                                child: Container(
                                                  height: 2,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.3),
                                                    borderRadius: BorderRadius.circular(1),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        title: Text(
                                          albumName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '${albumSongs.length} songs',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onTap: () {
                                          Get.to(
                                            () => AlbumDetailPage(
                                              albumName: albumName,
                                              songs: albumSongs,
                                            ),
                                            transition: Transition.rightToLeft,
                                          );
                                        },
                                      );
                                    },
                                  ),
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
