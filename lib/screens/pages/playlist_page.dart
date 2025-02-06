import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../services/network_service.dart';
import '../../services/audio_service.dart';
import '../../widgets/mini_player.dart';

class PlaylistPage extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final int playlistId;

  const PlaylistPage({
    super.key,
    required this.playlist,
    required this.playlistId,
  });

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final NetworkService _networkService = NetworkService();
  bool _isLoading = true;
  Color? dominantColor;
  Color? secondaryColor;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _bgOpacity = ValueNotifier<double>(0.0);
  List<dynamic> tracks = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 等待页面完全构建后再加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlaylistData();
      _extractColors();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final double offset = _scrollController.offset;
    final double imageSize = MediaQuery.of(context).size.width * 0.7;
    final double delayHeight = 90.0;
    final double opacity = offset <= 0 ? 0.0 : ((offset - delayHeight) / imageSize).clamp(0.0, 1.0);
    _bgOpacity.value = opacity;
  }

  Future<void> _loadPlaylistData() async {
    try {
      final response = await _networkService.getPlaylistById(widget.playlistId);
      if (!mounted) return; // 检查组件是否还在树中

      setState(() {
        if (response['tracks'] != null) {
          tracks = response['tracks'] as List<dynamic>;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        print('Error loading playlist: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _extractColors() async {
    try {
      final imageProvider = CachedNetworkImageProvider(widget.playlist['cover'] ?? '');
      await precacheImage(imageProvider, context);

      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
      );

      if (!mounted) return;
      setState(() {
        // 获取主色和次色
        dominantColor = paletteGenerator.darkMutedColor?.color ?? paletteGenerator.darkVibrantColor?.color ?? paletteGenerator.dominantColor?.color ?? const Color(0xff161616);

        // 获取第二主色
        secondaryColor = paletteGenerator.mutedColor?.color ?? paletteGenerator.vibrantColor?.color ?? dominantColor?.withOpacity(0.7) ?? const Color(0xff161616);

        // 确保颜色足够深
        secondaryColor = HSLColor.fromColor(secondaryColor!).withLightness((HSLColor.fromColor(secondaryColor!).lightness * 0.7).clamp(0.0, 1.0)).toColor();
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error extracting colors: $e');
      setState(() {
        dominantColor = const Color(0xff161616);
        secondaryColor = const Color(0xff121212);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.7],
            colors: [
              secondaryColor?.withOpacity(0.95) ?? const Color(0xff161616),
              secondaryColor?.withOpacity(0.7) ?? const Color(0xff121212),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? _buildSkeleton(context)
                    : CustomScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          _buildSliverAppBar(),
                          SliverToBoxAdapter(
                            child: _buildPlaylistHeader(),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index >= tracks.length) return null;
                                final track = tracks[index];
                                return Material(
                                  type: MaterialType.transparency,
                                  child: ListTile(
                                    key: ValueKey('track_${track['id']}'),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    tileColor: Colors.transparent,
                                    selectedTileColor: Colors.transparent,
                                    hoverColor: Colors.white.withOpacity(0.1),
                                    splashColor: Colors.transparent,
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(4.0),
                                      child: CachedNetworkImage(
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        imageUrl: track['cover_url'] ?? '',
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[800],
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white54,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[800],
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${index + 1}. ',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          TextSpan(
                                            text: track['name'] ?? '',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      track['artist'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                    onTap: () {
                                      AudioService.to.playPlaylist(
                                        List<Map<String, dynamic>>.from(tracks),
                                        index,
                                      );
                                    },
                                  ),
                                );
                              },
                              childCount: tracks.length,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 32),
                          ),
                        ],
                      ),
              ),
              const MiniPlayer(isAboveBottomBar: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final double imageSize = MediaQuery.of(context).size.width * 0.7;
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      color: const Color(0xff161616),
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          // 封面图骨架屏
          SliverAppBar(
            expandedHeight: imageSize + topPadding,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 20.0 + topPadding),
                    child: Center(
                      child: Container(
                        width: imageSize,
                        height: imageSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          color: Colors.grey[800],
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 标题和控制按钮骨架屏
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 200,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 80,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 歌曲列表骨架屏
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              childCount: 10, // 显示10个骨架项
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final double imageSize = MediaQuery.of(context).size.width * 0.7;
    final double minImageSize = MediaQuery.of(context).size.width * 0.3;
    final double topPadding = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<double>(
      valueListenable: _bgOpacity,
      builder: (context, opacity, child) {
        final bool showTitle = opacity > 0.9;
        final double titleOpacity = ((opacity - 0.7) * 5).clamp(0.0, 1.0);
        final double currentSize = (imageSize - (imageSize - minImageSize) * opacity).clamp(minImageSize, imageSize);

        // 使用第二主色作为 AppBar 背景
        final Color backgroundColor = opacity <= 0.01 ? Colors.transparent : (secondaryColor?.withOpacity(opacity) ?? const Color(0xff161616).withOpacity(opacity));

        return SliverAppBar(
          expandedHeight: imageSize + topPadding + 10,
          pinned: true,
          stretch: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: backgroundColor,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          backgroundColor: backgroundColor,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            ),
            onPressed: () => Get.back(),
          ),
          title: Opacity(
            opacity: titleOpacity,
            child: Text(
              widget.playlist['title'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: topPadding, // 从状态栏底部开始
                  left: 0,
                  right: 0,
                  bottom: 10, // 添加底部间距
                  child: Center(
                    child: SizedBox(
                      width: currentSize,
                      height: currentSize,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: CachedNetworkImage(
                            imageUrl: widget.playlist['cover'] ?? '',
                            fit: BoxFit.cover,
                            memCacheWidth: 800,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white54,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tracks.length} 首歌曲',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.shuffle,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      final shuffledTracks = List<Map<String, dynamic>>.from(tracks)..shuffle();
                      AudioService.to.playPlaylist(
                        shuffledTracks,
                        0,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dominantColor ?? const Color(0xff161616),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          AudioService.to.playPlaylist(
                            List<Map<String, dynamic>>.from(tracks),
                            0,
                          );
                        },
                        child: const Center(
                          child: FaIcon(
                            FontAwesomeIcons.play,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.playlist['content']?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(
              widget.playlist['content'] ?? '',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
