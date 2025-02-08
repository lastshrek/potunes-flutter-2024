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
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/home_controller.dart';
import '../../screens/pages/all_playlists_page.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isInitialLoading) {
          return _buildSkeletonList();
        }

        if (controller.error?.value != null) {
          return Center(
            child: Text(
              'Error: ${controller.error?.value}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshData,
          backgroundColor: Colors.black,
          color: Colors.white,
          child: CustomScrollView(
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
              _buildCollectionsSection(context),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      child: CustomScrollView(
        slivers: [
          // 添加骨架屏的 sliver 组件
          // ... 根据实际布局添加相应的骨架屏组件
        ],
      ),
    );
  }

  Widget _buildCollectionsSection(BuildContext context) {
    final collections = controller.collections;
    final finalPlaylists = controller.finals;
    final albums = controller.albums;
    final neteaseToplist = controller.neteaseToplist;

    return SliverList(
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
                  controller.isRefreshing
                      ? const SkeletonLoading(
                          width: 100,
                          height: 18,
                        )
                      : const Text(
                          'Collections',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: controller.isRefreshing
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AllPlaylistsPage(
                                    title: 'Collections',
                                    playlists: collections,
                                    apiPath: ApiConfig.allCollections,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

                if (isLandscape) {
                  // 横屏布局
                  return SizedBox(
                    height: 140, // 调整高度以适应 32:15 的比例
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.isRefreshing ? 3 : collections.length,
                      itemBuilder: (context, index) {
                        if (controller.isRefreshing) {
                          return Container(
                            width: 298, // 32:15 的比例，高度 140
                            margin: const EdgeInsets.only(right: 12),
                            child: const SkeletonLoading(),
                          );
                        }
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
                            width: 298, // 保持 32:15 的比例
                            margin: const EdgeInsets.only(right: 12),
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
                    ),
                  );
                } else {
                  // 竖屏布局
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AspectRatio(
                      aspectRatio: 32 / 15,
                      child: controller.isRefreshing
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
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Final 部分
        HorizontalPlaylistList(
          title: 'Final',
          playlists: finalPlaylists,
          isLoading: controller.isRefreshing,
          onTitleTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AllPlaylistsPage(
                  title: 'Final',
                  playlists: finalPlaylists,
                  apiPath: ApiConfig.allFinals,
                ),
              ),
            );
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
          isLoading: controller.isRefreshing,
          onTitleTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AllPlaylistsPage(
                  title: 'Albums',
                  playlists: albums,
                  apiPath: ApiConfig.allAlbums,
                ),
              ),
            );
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
          isLoading: controller.isRefreshing,
          onTitleTap: null,
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
        // 添加底部 padding，考虑 mini player 和底部导航栏的高度
        SizedBox(
          height: 16, // mini player 的高度
        ),
      ]),
    );
  }
}
