import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import '../../services/network_service.dart';
import 'package:flutter/foundation.dart';
import '../../utils/http/api_exception.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/horizontal_playlist_list.dart';
import '../../screens/pages/playlist_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NetworkService _networkService = NetworkService();
  Map<String, dynamic>? _homeData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      debugPrint('=================== Loading Home Data ===================');
      debugPrint('Starting to load home data...');

      final response = await _networkService.getHomeData();

      debugPrint('Home data loaded successfully');
      debugPrint('Response: $response');
      debugPrint('Response type: ${response.runtimeType}');
      debugPrint('====================================================');

      if (mounted) {
        setState(() {
          _homeData = response;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('=================== Error Loading Home Data ===================');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('===========================================================');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = _homeData?['collections'] as List<dynamic>? ?? [];
    final finalPlaylists = _homeData?['finals'] as List<dynamic>? ?? [];
    final albums = _homeData?['albums'] as List<dynamic>? ?? [];
    final neteaseToplist = _homeData?['netease_toplist'] as List<dynamic>? ?? [];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: false,
          leadingWidth: 48,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
          title: SizedBox(
            height: 40,
            child: TextField(
              style: const TextStyle(color: Colors.white),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                hintText: '搜索音乐...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                // TODO: 实现搜索功能
              },
            ),
          ),
          actions: const [
            SizedBox(width: 8),
          ],
          backgroundColor: Colors.black,
          elevation: 0,
          toolbarHeight: 64,
        ),
        if (_error != null)
          SliverFillRemaining(
            child: Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              // Collections 部分
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _isLoading
                            ? const SkeletonLoading(
                                width: 100,
                                height: 18,
                              )
                            : Text(
                                'Collections',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: _isLoading
                              ? const SkeletonLoading(
                                  width: 24,
                                  height: 24,
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.arrow_outward,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    // TODO: 处理点击事件
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AspectRatio(
                      aspectRatio: 32 / 15,
                      child: _isLoading
                          ? const SkeletonLoading()
                          : Swiper(
                              itemBuilder: (context, index) {
                                final item = collections[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PlaylistPage(
                                          playlist: item,
                                          playlistId: item['id'] ?? 0,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: item['cover'] ?? '',
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[800],
                                          child: const Center(
                                            child: Icon(
                                              Icons.music_note,
                                              color: Colors.white54,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[800],
                                          child: const Center(
                                            child: Icon(
                                              Icons.error_outline,
                                              color: Colors.white54,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              itemCount: collections.length,
                              autoplay: true,
                              autoplayDelay: 3000,
                              viewportFraction: 1.0,
                              scale: 1.0,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Final 部分
              HorizontalPlaylistList(
                title: 'Final',
                playlists: finalPlaylists,
                isLoading: _isLoading,
                onTitleTap: () {
                  // TODO: 处理标题点击事件
                },
                onPlaylistTap: (playlist) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaylistPage(
                        playlist: playlist,
                        playlistId: playlist['id'] ?? 0,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Albums 部分
              HorizontalPlaylistList(
                title: 'Albums',
                playlists: albums,
                isLoading: _isLoading,
                onTitleTap: () {
                  // TODO: 处理标题点击事件
                },
                onPlaylistTap: (playlist) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaylistPage(
                        playlist: playlist,
                        playlistId: playlist['id'] ?? 0,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Netease Toplist 部分
              HorizontalPlaylistList(
                title: 'Netease Toplist',
                playlists: neteaseToplist,
                isLoading: _isLoading,
                onTitleTap: () {
                  // TODO: 处理标题点击事件
                },
                onPlaylistTap: (playlist) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaylistPage(
                        playlist: playlist,
                        playlistId: playlist['id'] ?? 0,
                      ),
                    ),
                  );
                },
              ),
            ]),
          ),
      ],
    );
  }
}
