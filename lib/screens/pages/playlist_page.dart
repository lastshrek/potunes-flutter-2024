import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import '../../services/network_service.dart';
import '../../services/audio_service.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/track_list_tile.dart';

class PlaylistPage extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final int playlistId;
  final bool isFromCollections;
  final bool isFromTopList;
  final bool isFromNewAlbum;

  const PlaylistPage({
    super.key,
    required this.playlist,
    required this.playlistId,
    this.isFromCollections = false,
    this.isFromTopList = false,
    this.isFromNewAlbum = false,
  });

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final NetworkService _networkService = NetworkService.instance;
  bool _isLoading = true;
  Color? dominantColor;
  Color? secondaryColor;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _bgOpacity = ValueNotifier<double>(0.0);
  List<dynamic> tracks = [];
  final _colorTween = ColorTween(begin: Colors.black, end: Colors.black);
  final _colorAnimation = ValueNotifier<Color>(Colors.black);

  // 缓存 MediaQuery 的值
  late final double _screenWidth = MediaQuery.of(context).size.width;
  late final double _topPadding = MediaQuery.of(context).padding.top;

  // 缓存计算值
  late final double _imageSize = _screenWidth * 0.7;

  // 使用 const 构造器优化性能
  static const _placeholderIcon = Icon(Icons.music_note, color: Colors.white54);
  static const _errorIcon = Icon(Icons.music_note, color: Colors.white54);
  static const _boxColor = Color(0xff161616);

  // 添加常量组件
  static const _divider = SizedBox(height: 12);
  static const _smallDivider = SizedBox(height: 4);
  static const _horizontalDivider = SizedBox(width: 8);

  // 缓存主题相关样式
  late final _titleStyle = const TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  late final _subtitleStyle = TextStyle(
    color: Colors.grey[400],
    fontSize: 14,
  );

  // 缓存布局常量
  static const _contentPadding = EdgeInsets.all(16.0);
  static const _borderRadius = BorderRadius.all(Radius.circular(8.0));

  // 缓存阴影效果
  late final _shadowDecoration = BoxDecoration(
    borderRadius: _borderRadius,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _isLoading = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        dominantColor = Colors.black;
        secondaryColor = Colors.black;
      });
      _loadPlaylistData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    print('PlaylistPage disposed');
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    dominantColor = null;
    secondaryColor = null;
    tracks.clear();
    _colorAnimation.dispose();
    super.dispose();
  }

  // 优化滚动监听器
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double offset = _scrollController.offset;
    final double delayHeight = 90.0;

    // 只在必要时更新值
    final double newOpacity = offset <= 0 ? 0.0 : ((offset - delayHeight) / _imageSize).clamp(0.0, 1.0);
    if ((_bgOpacity.value - newOpacity).abs() > 0.01) {
      _bgOpacity.value = newOpacity;
    }
  }

  Future<void> _loadPlaylistData() async {
    try {
      final response = widget.isFromTopList
          ? await _networkService.getTopListDetail(widget.playlistId)
          : widget.isFromNewAlbum
              ? await _networkService.getNewAlbumDetail(widget.playlistId)
              : await _networkService.getPlaylistById(widget.playlistId);

      if (!mounted) return;

      setState(() {
        if (response['tracks'] != null) {
          tracks = response['tracks'] as List<dynamic>;

          // 预加载前10个封面
          for (var i = 0; i < math.min(10, tracks.length); i++) {
            precacheImage(
              CachedNetworkImageProvider(
                tracks[i]['cover_url'] ?? '',
                maxWidth: 80,
                maxHeight: 80,
              ),
              context,
            );
          }
        }
        _isLoading = false;
      });

      _extractColors();
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
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
      );

      if (!mounted) return;

      // 获取深色主色调
      final Color mainColor = paletteGenerator.darkMutedColor?.color ?? paletteGenerator.darkVibrantColor?.color ?? paletteGenerator.dominantColor?.color ?? const Color(0xff161616);

      // 确保颜色足够深
      final HSLColor hslColor = HSLColor.fromColor(mainColor);
      final Color adjustedColor = hslColor.withLightness((hslColor.lightness * 0.7).clamp(0.0, 0.3)).toColor();

      // 设置动画
      _colorTween.begin = _colorAnimation.value;
      _colorTween.end = adjustedColor;

      // 执行颜色过渡动画
      const duration = Duration(milliseconds: 500);
      final startTime = DateTime.now();

      void updateColor() {
        final elapsedTime = DateTime.now().difference(startTime);
        if (elapsedTime >= duration) {
          _colorAnimation.value = adjustedColor;
          return;
        }

        final t = (elapsedTime.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
        _colorAnimation.value = Color.lerp(_colorTween.begin!, _colorTween.end!, t)!;
        Future.microtask(updateColor);
      }

      updateColor();
    } catch (e) {
      debugPrint('Error extracting colors: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return WillPopScope(
        onWillPop: () async {
          _handlePopBack();
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ValueListenableBuilder<Color>(
            valueListenable: _colorAnimation,
            builder: (context, color, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withOpacity(0.8),
                      const Color(0xff161616),
                    ],
                    stops: const [0.0, 0.5],
                  ),
                ),
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity! > 0) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final miniPlayerHeight = 80.0;
                                final topPadding = MediaQuery.of(context).padding.top;
                                final bottomPadding = 16.0;
                                final availableHeight = constraints.maxHeight - miniPlayerHeight - topPadding - bottomPadding;

                                // 减小 coverSize 的比例，为底部留出更多空间
                                final coverSize = widget.isFromCollections
                                    ? availableHeight * 0.4 // collections 的封面高度比例降低
                                    : availableHeight * 0.5; // 普通封面也降低比例
                                final infoSize = availableHeight * 0.3; // 减小信息区域
                                final spacing = availableHeight * 0.1;

                                return CustomScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  slivers: [
                                    SliverAppBar(
                                      backgroundColor: Colors.transparent,
                                      pinned: true,
                                      expandedHeight: 0,
                                      leading: IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        onPressed: _handlePopBack,
                                      ),
                                      systemOverlayStyle: const SystemUiOverlayStyle(
                                        statusBarColor: Colors.transparent,
                                        statusBarIconBrightness: Brightness.light,
                                        systemNavigationBarColor: Colors.transparent,
                                        systemNavigationBarIconBrightness: Brightness.light,
                                      ),
                                    ),
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // 专辑封面
                                            SizedBox(
                                              height: coverSize,
                                              child: Center(
                                                child: AspectRatio(
                                                  aspectRatio: widget.isFromCollections ? 32 / 15 : 1,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.3),
                                                          blurRadius: 20,
                                                          offset: const Offset(0, 10),
                                                        ),
                                                      ],
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: CachedNetworkImage(
                                                        imageUrl: widget.playlist['cover'] ?? '',
                                                        fit: BoxFit.cover,
                                                        memCacheWidth: MediaQuery.of(context).size.width.toInt(),
                                                        memCacheHeight: MediaQuery.of(context).size.width.toInt(),
                                                        fadeInDuration: Duration.zero,
                                                        fadeOutDuration: Duration.zero,
                                                        placeholder: (context, url) => const ColoredBox(
                                                          color: Color(0xff161616),
                                                          child: Icon(Icons.music_note, color: Colors.white54),
                                                        ),
                                                        errorWidget: (context, url, error) => const ColoredBox(
                                                          color: Color(0xff161616),
                                                          child: Icon(Icons.music_note, color: Colors.white54),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // 间距
                                            SizedBox(height: spacing * 0.5),
                                            // 播放列表信息
                                            SizedBox(
                                              height: infoSize,
                                              child: SingleChildScrollView(
                                                // 添加滚动支持
                                                child: _buildPlaylistHeader(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // 增加底部空间
                                    SliverToBoxAdapter(
                                      child: SizedBox(height: miniPlayerHeight + bottomPadding + 32), // 增加更多底部间距
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final miniPlayerHeight = 80.0;

                                return CustomScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  slivers: [
                                    SliverPadding(
                                      padding: EdgeInsets.only(
                                        top: MediaQuery.of(context).padding.top + 16,
                                      ),
                                      sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                                    ),
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final track = tracks[index];
                                            return TrackListTile(
                                              track: track,
                                              onTap: () => _playTrack(track, tracks, index),
                                              isPlaying: AudioService.to.isPlaying && AudioService.to.currentPlaylist?.contains(track) == true,
                                              index: index,
                                            );
                                          },
                                          childCount: tracks.length,
                                        ),
                                      ),
                                    ),
                                    // 添加底部空间以避免被 MiniPlayer 遮挡
                                    SliverToBoxAdapter(
                                      child: SizedBox(height: miniPlayerHeight + 16), // 添加额外的间距
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: MiniPlayer(isAboveBottomBar: false),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! > 0) {
                  Navigator.of(context).pop();
                }
              },
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final miniPlayerHeight = 80.0;
                            final topPadding = MediaQuery.of(context).padding.top;
                            final bottomPadding = 16.0;
                            final availableHeight = constraints.maxHeight - miniPlayerHeight - topPadding - bottomPadding;

                            // 减小 coverSize 的比例，为底部留出更多空间
                            final coverSize = widget.isFromCollections
                                ? availableHeight * 0.4 // collections 的封面高度比例降低
                                : availableHeight * 0.5; // 普通封面也降低比例
                            final infoSize = availableHeight * 0.3; // 减小信息区域
                            final spacing = availableHeight * 0.1;

                            return CustomScrollView(
                              physics: const ClampingScrollPhysics(),
                              slivers: [
                                SliverAppBar(
                                  backgroundColor: Colors.transparent,
                                  pinned: true,
                                  expandedHeight: 0,
                                  leading: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: _handlePopBack,
                                  ),
                                  systemOverlayStyle: const SystemUiOverlayStyle(
                                    statusBarColor: Colors.transparent,
                                    statusBarIconBrightness: Brightness.light,
                                    systemNavigationBarColor: Colors.transparent,
                                    systemNavigationBarIconBrightness: Brightness.light,
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 专辑封面
                                        SizedBox(
                                          height: coverSize,
                                          child: Center(
                                            child: AspectRatio(
                                              aspectRatio: widget.isFromCollections ? 32 / 15 : 1,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.3),
                                                      blurRadius: 20,
                                                      offset: const Offset(0, 10),
                                                    ),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: CachedNetworkImage(
                                                    imageUrl: widget.playlist['cover'] ?? '',
                                                    fit: BoxFit.cover,
                                                    memCacheWidth: MediaQuery.of(context).size.width.toInt(),
                                                    memCacheHeight: MediaQuery.of(context).size.width.toInt(),
                                                    fadeInDuration: Duration.zero,
                                                    fadeOutDuration: Duration.zero,
                                                    placeholder: (context, url) => const ColoredBox(
                                                      color: Color(0xff161616),
                                                      child: Icon(Icons.music_note, color: Colors.white54),
                                                    ),
                                                    errorWidget: (context, url, error) => const ColoredBox(
                                                      color: Color(0xff161616),
                                                      child: Icon(Icons.music_note, color: Colors.white54),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 间距
                                        SizedBox(height: spacing * 0.5),
                                        // 播放列表信息
                                        SizedBox(
                                          height: infoSize,
                                          child: SingleChildScrollView(
                                            // 添加滚动支持
                                            child: _buildPlaylistHeader(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 增加底部空间
                                SliverToBoxAdapter(
                                  child: SizedBox(height: miniPlayerHeight + bottomPadding + 32), // 增加更多底部间距
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final miniPlayerHeight = 80.0;

                            return CustomScrollView(
                              physics: const ClampingScrollPhysics(),
                              slivers: [
                                SliverPadding(
                                  padding: EdgeInsets.only(
                                    top: MediaQuery.of(context).padding.top + 16,
                                  ),
                                  sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final track = tracks[index];
                                        return TrackListTile(
                                          track: track,
                                          onTap: () => _playTrack(track, tracks, index),
                                          isPlaying: AudioService.to.isPlaying && AudioService.to.currentPlaylist?.contains(track) == true,
                                          index: index,
                                        );
                                      },
                                      childCount: tracks.length,
                                    ),
                                  ),
                                ),
                                // 添加底部空间以避免被 MiniPlayer 遮挡
                                SliverToBoxAdapter(
                                  child: SizedBox(height: miniPlayerHeight + 16), // 添加额外的间距
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MiniPlayer(isAboveBottomBar: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return WillPopScope(
        onWillPop: () async {
          _handlePopBack();
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ValueListenableBuilder<Color>(
            valueListenable: _colorAnimation,
            builder: (context, color, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withOpacity(0.8),
                      const Color(0xff161616),
                    ],
                    stops: const [0.0, 0.5],
                  ),
                ),
                child: child,
              );
            },
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! > 0) {
                  Navigator.of(context).pop();
                }
              },
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : CustomScrollView(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              slivers: [
                                _buildSliverAppBar(),
                                SliverToBoxAdapter(
                                  child: _buildPlaylistHeader(),
                                ),
                                _buildTrackList(),
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
          ),
        ),
      );
    }
  }

  Widget _buildSliverAppBar() {
    final double imageSize = MediaQuery.of(context).size.width * 0.7;
    final double minImageSize = MediaQuery.of(context).size.width * 0.3;
    final double topPadding = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<double>(
      valueListenable: _bgOpacity,
      builder: (context, opacity, child) {
        final double titleOpacity = ((opacity - 0.7) * 5).clamp(0.0, 1.0);
        final double currentSize = (imageSize - (imageSize - minImageSize) * opacity).clamp(minImageSize, imageSize);

        final Color backgroundColor = opacity <= 0.01 ? Colors.transparent : (secondaryColor?.withOpacity(opacity) ?? const Color(0xff161616).withOpacity(opacity));

        return SliverAppBar(
          expandedHeight: imageSize + topPadding + 10,
          pinned: true,
          stretch: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          backgroundColor: backgroundColor,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
            onPressed: _handlePopBack,
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
                  top: topPadding,
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(
                    child: SizedBox(
                      width: currentSize,
                      height: widget.isFromCollections ? (currentSize * 15 / 32) : currentSize,
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
                            memCacheWidth: MediaQuery.of(context).size.width.toInt(),
                            memCacheHeight: MediaQuery.of(context).size.width.toInt(),
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (context, url) => const ColoredBox(
                              color: Color(0xff161616),
                              child: Icon(Icons.music_note, color: Colors.white54),
                            ),
                            errorWidget: (context, url, error) => const ColoredBox(
                              color: Color(0xff161616),
                              child: Icon(Icons.music_note, color: Colors.white54),
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
                      style: _titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _smallDivider,
                    Text(
                      '${tracks.length} 首歌曲',
                      style: _subtitleStyle,
                    ),
                  ],
                ),
              ),
              _buildPlayControls(),
            ],
          ),
          if (widget.playlist['content']?.isNotEmpty ?? false) ...[
            _divider,
            Text(
              widget.playlist['content'] ?? '',
              style: _subtitleStyle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const FaIcon(
            FontAwesomeIcons.shuffle,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            if (!AudioService.to.isShuffleMode) {
              AudioService.to.toggleShuffle();
            }
            AudioService.to.skipToQueueItem(0);
          },
        ),
        _horizontalDivider,
        PlayButton(
          backgroundColor: dominantColor?.withOpacity(0.8),
          tracks: List<Map<String, dynamic>>.from(tracks),
        ),
      ],
    );
  }

  Widget _buildTrackList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= tracks.length) return null;
          return _buildTrackItem(index, tracks[index]);
        },
        childCount: tracks.length,
        // 添加key以优化重建
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
      ),
    );
  }

  Widget _buildTrackItem(int index, dynamic track) {
    return RepaintBoundary(
      child: Material(
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
              memCacheWidth: 80,
              memCacheHeight: 80,
              fadeInDuration: Duration.zero,
              placeholder: (_, __) => const ColoredBox(
                color: _boxColor,
                child: _placeholderIcon,
              ),
              errorWidget: (_, __, ___) => const ColoredBox(
                color: _boxColor,
                child: _errorIcon,
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
            _playTrack(track, tracks, index);
          },
        ),
      ),
    );
  }

  void _playTrack(dynamic track, List<dynamic> tracks, int index) {
    AudioService.to.playPlaylist(
      List<Map<String, dynamic>>.from(tracks),
      initialIndex: index,
    );
  }

  void _handlePopBack() {
    Navigator.of(context).pop();

    // 在返回过程中执行颜色渐变，目标颜色改为纯黑色
    _colorTween.begin = _colorAnimation.value;
    _colorTween.end = Colors.black;

    const duration = Duration(milliseconds: 150);
    final startTime = DateTime.now();

    void updateColor() {
      final elapsedTime = DateTime.now().difference(startTime);
      if (elapsedTime >= duration) {
        _colorAnimation.value = Colors.black;
        return;
      }

      final t = (elapsedTime.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      _colorAnimation.value = Color.lerp(_colorTween.begin!, _colorTween.end!, t)!;
      if (mounted) {
        Future.microtask(updateColor);
      }
    }

    updateColor();
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
          onTap: () => AudioService.to.playPlaylist(
            List<Map<String, dynamic>>.from(tracks),
            initialIndex: 0,
          ),
          child: Obx(() => Center(
                child: FaIcon(
                  AudioService.to.isPlaying && AudioService.to.currentPlaylist == tracks ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                  color: Colors.white,
                  size: 24,
                ),
              )),
        ),
      ),
    );
  }
}
