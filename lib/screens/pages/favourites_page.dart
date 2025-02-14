import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/network_service.dart';
import '../../widgets/mini_player.dart';
import '../../services/audio_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../screens/pages/album_detail_page.dart';
import '../../widgets/common/current_track_highlight.dart';
import '../../widgets/common/cached_image.dart';

class FavouritesPage extends StatefulWidget {
  const FavouritesPage({super.key});

  @override
  State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage> {
  Future<List<dynamic>>? _favouritesFuture;
  final selectedIndex = 0.obs; // 添加分段选择器的状态

  // 添加预加载标记
  bool _isPreloading = true;

  static const _appBarTitle = Text(
    'Favourites',
    style: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  );

  static const _loadingIndicator = Center(
    child: CircularProgressIndicator(
      color: Color(0xFFDA5597),
    ),
  );

  static const _appBarActions = [
    IconButton(
      icon: Icon(Icons.search, color: Colors.white),
      onPressed: null, // TODO: 实现搜索功能
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 预加载数据
    _preloadData();
  }

  // 添加预加载方法
  Future<void> _preloadData() async {
    // 在后台线程加载数据
    unawaited(_loadFavourites().then((data) {
      if (mounted) {
        setState(() {
          _favouritesFuture = Future.value(data);
        });
      }
    }));

    // 等待页面转场动画完成后再显示内容
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _isPreloading = false;
      });
    }
  }

  @override
  void dispose() {
    selectedIndex.close(); // 记得在 dispose 中关闭
    super.dispose();
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

  void _playSong(Map<String, dynamic> song, List<dynamic> playlist, int index) {
    final audioService = Get.find<AudioService>();

    // 转换歌曲数据为播放列表格式
    final tracks = playlist
        .map((item) => {
              'id': item['id'],
              'nId': item['nId'],
              'name': item['name'],
              'artist': item['artist'],
              'album': item['album'] ?? '',
              'album_id': item['album_id'] ?? 0,
              'duration': item['duration'],
              'cover_url': item['cover_url'],
              'url': item['url'],
              'source': 'favourites',
              'ar': item['ar'] ?? [],
              'original_album': item['original_album'] ?? '',
              'original_album_id': item['original_album_id'] ?? 0,
              'mv': item['mv'] ?? 0,
              'playlist_id': item['playlist_id'],
              'type': item['type'] ?? ((item['id'] == 0) ? 'netease' : 'potunes'),
            })
        .toList();

    // 使用 AudioService 播放
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
    // 在预加载时显示空白页面
    if (_isPreloading) {
      return const Material(
        color: Colors.black,
        child: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: _appBarTitle,
        actions: _appBarActions,
      ),
      body: Stack(
        children: [
          FutureBuilder<List<dynamic>>(
            future: _favouritesFuture,
            builder: (context, snapshot) {
              if (_favouritesFuture == null) {
                return const SizedBox.shrink();
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loadingIndicator;
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
                                final audioService = Get.find<AudioService>();

                                return _buildTrackItem(
                                  song: song,
                                  index: index,
                                  audioService: audioService,
                                  playlist: favourites,
                                );
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: albums.length,
                              itemBuilder: (context, index) {
                                final albumName = albums.keys.elementAt(index);
                                final albumSongs = albums[albumName]!;

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

  Widget _buildTrackItem({
    required Map<String, dynamic> song,
    required int index,
    required AudioService audioService,
    required List<dynamic> playlist,
  }) {
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
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                song['artist'] ?? '',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ).withSubtleHighlight(isCurrentTrack),
              ),
            ),
            Text(
              _formatDuration(song['duration']),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () => _playSong(song, playlist, index),
      );
    });
  }

  Future<List<dynamic>> _loadFavourites() async {
    try {
      final networkService = NetworkService.instance;
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
