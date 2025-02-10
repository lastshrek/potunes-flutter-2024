import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/horizontal_playlist_list.dart';
import '../../screens/pages/playlist_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/home_controller.dart';
import '../../screens/pages/all_playlists_page.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import '../../services/audio_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController controller;
  List<Map<String, dynamic>> get collections => controller.collections;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeController>();
  }

  Future<void> _openSettings() async {
    if (Platform.isIOS) {
      try {
        // 使用 URL Scheme 打开设置
        final settingsUrl = Uri.parse('App-Prefs:root=General');
        if (await canLaunchUrl(settingsUrl)) {
          await launchUrl(settingsUrl, mode: LaunchMode.externalApplication);
        } else {
          // 如果无法打开设置，尝试使用系统设置 URL
          final fallbackUrl = Uri.parse('app-settings:');
          if (await canLaunchUrl(fallbackUrl)) {
            await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
          }
        }
      } catch (e) {
        // 如果出现错误，显示提示
        Get.snackbar(
          '提示',
          '无法打开设置，请手动前往系统设置允许网络访问',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isNetworkReady) {
        return Scaffold(
          backgroundColor: const Color(0xff161616),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '需要网络权限',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.error.value ?? '请在设置中允许网络访问',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _openSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('去设置'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: controller.retryConnection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: Colors.black,
        body: Obx(() {
          if (controller.collections.isEmpty) {
            return _buildSkeletonList();
          }

          if (controller.error.value != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    controller.error.value!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: controller.retryConnection,
                    child: const Text(
                      '重试',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
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
    });
  }

  Widget _buildSkeletonList() {
    return CustomScrollView(
      slivers: [
        // AppBar 骨架屏
        const SliverAppBar(
          pinned: true,
          floating: false,
          leadingWidth: 48,
          leading: SizedBox(width: 48),
          title: SizedBox(
            height: 40,
            child: SkeletonLoading(
              width: double.infinity,
              height: 40,
            ),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          toolbarHeight: 64,
        ),

        // 内容区域骨架屏
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 8),
            // Collections 标题骨架屏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLoading(width: 100, height: 20),
                  SkeletonLoading(width: 24, height: 24),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Collections 轮播图骨架屏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AspectRatio(
                aspectRatio: 32 / 15,
                child: SkeletonLoading(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Final 部分骨架屏
            _buildSectionSkeleton(),
            const SizedBox(height: 24),

            // Albums 部分骨架屏
            _buildSectionSkeleton(),
            const SizedBox(height: 24),

            // Netease Toplist 部分骨架屏
            _buildSectionSkeleton(),
            const SizedBox(height: 24),

            // Netease New Albums 部分骨架屏
            _buildSectionSkeleton(),
            const SizedBox(height: 56),
          ]),
        ),
      ],
    );
  }

  // 抽取通用的section骨架屏组件
  Widget _buildSectionSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题骨架屏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonLoading(width: 120, height: 20),
              SkeletonLoading(width: 24, height: 24),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 横向滚动列表骨架屏
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 封面图骨架屏
                    SkeletonLoading(
                      width: 120,
                      height: 120,
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 8),
                    // 标题骨架屏
                    SkeletonLoading(
                      width: 100,
                      height: 16,
                    ),
                    const SizedBox(height: 4),
                    // 副标题骨架屏
                    SkeletonLoading(
                      width: 80,
                      height: 12,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionsSection(BuildContext context) {
    final collections = controller.collections;
    final finalPlaylists = controller.finals;
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
                              _onViewAllCollectionsTap();
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
                    height: 140,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.isRefreshing ? 3 : collections.length,
                      itemBuilder: (context, index) {
                        if (controller.isRefreshing) {
                          return Container(
                            width: 298,
                            margin: const EdgeInsets.only(right: 12),
                            child: const SkeletonLoading(),
                          );
                        }
                        final item = collections[index];
                        return GestureDetector(
                          onTap: () => _onCollectionPlaylistTap(item),
                          child: Stack(
                            children: [
                              Container(
                                width: 298,
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
                              // 渐变遮罩
                              Positioned(
                                left: 0,
                                right: 12,
                                bottom: 0,
                                top: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                      stops: const [0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // 标题
                              Positioned(
                                left: 24,
                                right: 36,
                                bottom: 16,
                                child: Text(
                                  item['title']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
                                  onTap: () => _onCollectionPlaylistTap(item),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(
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
                                      // 渐变遮罩
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.7),
                                            ],
                                            stops: const [0.6, 1.0],
                                          ),
                                        ),
                                      ),
                                      // 标题
                                      Positioned(
                                        left: 12,
                                        right: 12,
                                        bottom: 12,
                                        child: Text(
                                          item['title']?.toString() ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(
                                                offset: Offset(1, 1),
                                                blurRadius: 3,
                                                color: Colors.black,
                                              ),
                                            ],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
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
            _onPlaylistTap(playlist);
          },
        ),
        const SizedBox(height: 24),
        // Albums 部分
        _buildAlbumsSection(),
        const SizedBox(height: 24),
        // Netease Toplist 部分
        HorizontalPlaylistList(
          title: 'Netease Toplist',
          playlists: neteaseToplist,
          isLoading: controller.isRefreshing,
          onTitleTap: null,
          onPlaylistTap: _onNeteaseToplistTap,
        ),
        const SizedBox(height: 24),
        // Netease New Albums 部分
        HorizontalPlaylistList(
          title: 'Netease New Albums',
          playlists: controller.neteaseNewAlbums,
          isLoading: controller.isRefreshing,
          onTitleTap: null,
          onPlaylistTap: _onNeteaseNewAlbumTap,
        ),
        // 添加固定的底部间距
        SizedBox(
          height: AudioService.to.currentTrack != null ? 0 : 56,
        ),
      ]),
    );
  }

  void _onCollectionPlaylistTap(Map<String, dynamic> playlist) {
    if (Platform.isAndroid) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaylistPage(
            playlist: playlist,
            playlistId: int.parse(playlist['id'].toString()),
            isFromCollections: true,
          ),
        ),
      );
    } else {
      Get.to(
        () => PlaylistPage(
          playlist: playlist,
          playlistId: int.parse(playlist['id'].toString()),
          isFromCollections: true,
        ),
        transition: Transition.rightToLeft,
      );
    }
  }

  void _onViewAllCollectionsTap() {
    if (Platform.isAndroid) {
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
    } else {
      Get.to(
        () => AllPlaylistsPage(
          title: 'Collections',
          playlists: collections,
          apiPath: ApiConfig.allCollections,
        ),
        transition: Transition.rightToLeft,
      );
    }
  }

  void _onPlaylistTap(Map<String, dynamic> playlist) {
    if (Platform.isAndroid) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaylistPage(
            playlist: playlist,
            playlistId: int.parse(playlist['id'].toString()),
          ),
        ),
      );
    } else {
      Get.to(
        () => PlaylistPage(
          playlist: playlist,
          playlistId: int.parse(playlist['id'].toString()),
        ),
        transition: Transition.rightToLeft,
      );
    }
  }

  Widget _buildAlbumsSection() {
    return HorizontalPlaylistList(
      title: 'Albums',
      playlists: controller.albums,
      isLoading: controller.isRefreshing,
      onTitleTap: () {
        if (Platform.isAndroid) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AllPlaylistsPage(
                title: 'Albums',
                playlists: controller.albums,
                apiPath: ApiConfig.allAlbums,
              ),
            ),
          );
        } else {
          Get.to(
            () => AllPlaylistsPage(
              title: 'Albums',
              playlists: controller.albums,
              apiPath: ApiConfig.allAlbums,
            ),
            transition: Transition.rightToLeft,
          );
        }
      },
      onPlaylistTap: _onPlaylistTap,
    );
  }

  void _onNeteaseToplistTap(Map<String, dynamic> playlist) {
    if (Platform.isAndroid) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaylistPage(
            playlist: playlist,
            playlistId: int.parse(playlist['nId'].toString()),
            isFromTopList: true,
          ),
        ),
      );
    } else {
      Get.to(
        () => PlaylistPage(
          playlist: playlist,
          playlistId: int.parse(playlist['nId'].toString()),
          isFromTopList: true,
        ),
        transition: Transition.rightToLeft,
      );
    }
  }

  void _onNeteaseNewAlbumTap(Map<String, dynamic> playlist) {
    if (Platform.isAndroid) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaylistPage(
            playlist: playlist,
            playlistId: int.parse(playlist['nId'].toString()),
            isFromNewAlbum: true,
          ),
        ),
      );
    } else {
      Get.to(
        () => PlaylistPage(
          playlist: playlist,
          playlistId: int.parse(playlist['nId'].toString()),
          isFromNewAlbum: true,
        ),
        transition: Transition.rightToLeft,
      );
    }
  }
}
