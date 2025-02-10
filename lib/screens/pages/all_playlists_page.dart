import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/network_service.dart';
import '../../config/api_config.dart';
import '../../utils/http/api_exception.dart';
import 'playlist_page.dart';
import '../../widgets/mini_player.dart';

class AllPlaylistsPage extends StatefulWidget {
  final String title;
  final List<dynamic> playlists;
  final String apiPath;

  const AllPlaylistsPage({
    super.key,
    required this.title,
    required this.playlists,
    required this.apiPath,
  });

  @override
  State<AllPlaylistsPage> createState() => _AllPlaylistsPageState();
}

class _AllPlaylistsPageState extends State<AllPlaylistsPage> {
  final _isLoading = false.obs;
  final _error = Rx<String?>(null);
  final _playlists = <dynamic>[].obs;

  @override
  void initState() {
    super.initState();
    _playlists.value = widget.playlists;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _isLoading.value = true;
      final networkService = NetworkService.instance;
      List<dynamic> data;

      switch (widget.apiPath) {
        case ApiConfig.allCollections:
          data = await networkService.getAllCollections();
          break;
        case ApiConfig.allFinals:
          data = await networkService.getAllFinals();
          break;
        case ApiConfig.allAlbums:
          data = await networkService.getAllAlbums();
          break;
        default:
          throw ApiException(
            statusCode: 500,
            message: '未知的 API 路径',
          );
      }

      _playlists.value = data;
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isCollections = widget.apiPath == ApiConfig.allCollections;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Obx(() {
                if (_isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                }

                if (_error.value != null) {
                  return Center(
                    child: Text(
                      'Error: ${_error.value}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadData,
                  backgroundColor: Colors.black,
                  color: Colors.white,
                  child: GridView.builder(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom + 40,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isLandscape ? 3 : 2,
                      childAspectRatio: isCollections ? 1.2 : 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      return GestureDetector(
                        onTap: () {
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
                        child: isCollections ? _buildCollectionItem(playlist) : _buildNormalItem(playlist),
                      );
                    },
                  ),
                );
              }),
            ),
            const MiniPlayer(isAboveBottomBar: false),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionItem(Map<String, dynamic> playlist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 32 / 15,
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
                imageUrl: playlist['cover'] ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
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
        ),
        const SizedBox(height: 8),
        Text(
          playlist['title'] ?? playlist['name'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (playlist['count'] != null || playlist['track_count'] != null) ...[
          const SizedBox(height: 4),
          Text(
            '${playlist['count'] ?? playlist['track_count']} 首歌曲',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNormalItem(Map<String, dynamic> playlist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
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
                imageUrl: playlist['cover'] ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
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
        ),
        const SizedBox(height: 8),
        Text(
          playlist['title'] ?? playlist['name'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (playlist['count'] != null || playlist['track_count'] != null) ...[
          const SizedBox(height: 4),
          Text(
            '${playlist['count'] ?? playlist['track_count']} 首歌曲',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
