import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/horizontal_playlist_list.dart';
import '../../screens/pages/playlist_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../screens/pages/all_playlists_page.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import '../../services/audio_service.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_drawer.dart';

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
        drawer: const AppDrawer(),
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
                AppHeader(
                  title: '', // 空标题
                  showSearch: true, // 显示搜索栏
                  onSearchChanged: (value) {
                    // TODO: 实现搜索功能
                    print('Search query: $value');
                  },
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    _buildCollectionsSection(context),
                    const SizedBox(height: 24),
                    _buildRadioSection(),
                    const SizedBox(height: 24),
                    _buildAlbumsSection(),
                    const SizedBox(height: 24),
                    // Final 部分
                    HorizontalPlaylistList(
                      title: 'Finals',
                      playlists: controller.finals,
                      isLoading: controller.isRefreshing,
                      onTitleTap: () {
                        _navigateToPage(
                          AllPlaylistsPage(
                            title: 'Final',
                            playlists: controller.finals,
                            apiPath: ApiConfig.allFinals,
                          ),
                        );
                      },
                      onPlaylistTap: _onPlaylistTap,
                    ),
                    const SizedBox(height: 8),
                    // Netease Toplist 部分
                    HorizontalPlaylistList(
                      title: 'Netease Toplist',
                      playlists: controller.neteaseToplist,
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
                ),
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

    return Column(
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
    );
  }

  Widget _buildRadioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FM 标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'FM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Radio 卡片
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.05),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        '正在加载歌曲...',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.only(
                        bottom: 16,
                        left: 16,
                        right: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                      backgroundColor: Colors.white,
                    ),
                  );
                  AudioService.to.playFMTrack();
                },
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    const Icon(
                      Icons.radio,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Just Listen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onCollectionPlaylistTap(Map<String, dynamic> playlist) {
    _navigateToPage(
      PlaylistPage(
        playlist: playlist,
        playlistId: int.parse(playlist['id'].toString()),
        isFromCollections: true,
      ),
    );
  }

  void _onViewAllCollectionsTap() {
    _navigateToPage(
      AllPlaylistsPage(
        title: 'Collections',
        playlists: collections,
        apiPath: ApiConfig.allCollections,
      ),
    );
  }

  void _onPlaylistTap(Map<String, dynamic> playlist) {
    _navigateToPage(
      PlaylistPage(
        playlist: playlist,
        playlistId: int.parse(playlist['id'].toString()),
        trackCount: playlist['track_count'],
        description: playlist['content'],
        coverUrl: playlist['cover'],
      ),
    );
  }

  Widget _buildAlbumsSection() {
    return HorizontalPlaylistList(
      title: 'Albums',
      playlists: controller.albums,
      isLoading: controller.isRefreshing,
      onTitleTap: () {
        _navigateToPage(
          AllPlaylistsPage(
            title: 'Albums',
            playlists: controller.albums,
            apiPath: ApiConfig.allAlbums,
          ),
        );
      },
      onPlaylistTap: _onPlaylistTap,
    );
  }

  void _onNeteaseToplistTap(Map<String, dynamic> playlist) {
    _navigateToPage(
      PlaylistPage(
        playlist: playlist,
        playlistId: int.parse(playlist['nId'].toString()),
        isFromTopList: true,
      ),
    );
  }

  void _onNeteaseNewAlbumTap(Map<String, dynamic> playlist) {
    _navigateToPage(
      PlaylistPage(
        playlist: playlist,
        playlistId: int.parse(playlist['nId'].toString()),
        isFromNewAlbum: true,
      ),
    );
  }

  void _navigateToPage(Widget page) {
    Get.to(
      () => page,
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );
  }
}
