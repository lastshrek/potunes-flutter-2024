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
import '../../utils/image_cache_manager.dart';

class PlaylistPage extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final int playlistId;
  final bool isFromCollections;
  final bool isFromTopList;
  final bool isFromNewAlbum;
  final int? trackCount;
  final String? description;
  final String? coverUrl;

  const PlaylistPage({
    super.key,
    required this.playlist,
    required this.playlistId,
    this.isFromCollections = false,
    this.isFromTopList = false,
    this.isFromNewAlbum = false,
    this.trackCount,
    this.description,
    this.coverUrl,
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
  static const int _pageSize = 20; // 每页加载的数量
  List<dynamic> _allTracks = []; // 存储所有 tracks
  List<dynamic> _displayedTracks = []; // 当前显示的 tracks
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  final _colorTween = ColorTween(begin: Colors.black, end: Colors.black);
  final _colorAnimation = ValueNotifier<Color>(Colors.black);

  // 缓存 MediaQuery 的值
  late final double _screenWidth = MediaQuery.of(context).size.width;

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

  // 为横屏模式的左右两侧分别创建 ScrollController
  final ScrollController _landscapeLeftController = ScrollController();
  final ScrollController _landscapeRightController = ScrollController();

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_onScrollForPagination);
    // 为横屏模式的右侧列表添加滚动监听
    _landscapeRightController.addListener(_onScrollForPagination);

    // 直接加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTracks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.removeListener(_onScrollForPagination);
    _scrollController.dispose();
    // 移除横屏模式的滚动监听并释放
    _landscapeLeftController.removeListener(_onScrollForPagination);
    _landscapeLeftController.dispose();
    _landscapeRightController.removeListener(_onScrollForPagination);
    _landscapeRightController.dispose();
    dominantColor = null;
    secondaryColor = null;
    _allTracks.clear();
    _displayedTracks.clear();
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

  void _onScrollForPagination() {
    // 获取当前活动的 ScrollController
    final activeController = MediaQuery.of(context).orientation == Orientation.landscape
        ? _landscapeRightController // 使用右侧列表的 controller
        : _scrollController;

    if (!activeController.hasClients) return;

    final maxScroll = activeController.position.maxScrollExtent;
    final currentScroll = activeController.position.pixels;

    // 当滚动到距离底部 200 像素时加载更多
    if (maxScroll - currentScroll <= 200 && !_isLoadingMore && _hasMoreData) {
      _loadMoreTracks();
    }
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    final startIndex = _displayedTracks.length;
    final endIndex = math.min(startIndex + _pageSize, _allTracks.length);

    if (startIndex < _allTracks.length) {
      await Future.delayed(const Duration(milliseconds: 100)); // 添加小延迟避免卡顿

      setState(() {
        _displayedTracks.addAll(_allTracks.getRange(startIndex, endIndex));
        _isLoadingMore = false;
        _hasMoreData = endIndex < _allTracks.length;
      });
    } else {
      setState(() {
        _isLoadingMore = false;
        _hasMoreData = false;
      });
    }
  }

  Future<void> _loadTracks() async {
    try {
      final response = widget.isFromTopList
          ? await _networkService.getTopListDetail(widget.playlistId)
          : widget.isFromNewAlbum
              ? await _networkService.getNewAlbumDetail(widget.playlistId)
              : await _networkService.getPlaylistById(widget.playlistId);

      if (!mounted) return;

      if (response['tracks'] != null) {
        _allTracks = response['tracks'] as List<dynamic>;

        setState(() {
          _displayedTracks = _allTracks.take(_pageSize).toList();
          _isLoading = false;
          _hasMoreData = _allTracks.length > _pageSize;
        });

        // 等待一帧以确保 setState 完成
        await Future.microtask(() {});

        // 提取颜色
        if (widget.coverUrl != null) {
          await _extractColors();
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        print('Error loading playlist tracks: $e');
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

      // 获取第一主色调
      final Color mainColor = paletteGenerator.dominantColor?.color ?? const Color(0xff161616);

      // 确保颜色足够深
      final HSLColor hslColor = HSLColor.fromColor(mainColor);

      // 主背景色（第一主色调暗化）
      final Color adjustedColor = hslColor.withLightness((hslColor.lightness * 0.4).clamp(0.0, 0.2)).toColor();

      // AppBar 背景色（稍微亮一点的第一主色调）
      secondaryColor = hslColor.withLightness((hslColor.lightness * 0.5).clamp(0.0, 0.25)).toColor();

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
                      color.withOpacity(0.95), // 顶部更不透明
                      color.withOpacity(0.7), // 中间过渡色更深
                      const Color(0xff161616), // 底部保持黑色
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    // 主内容
                    child!,
                  ],
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
                              controller: _landscapeLeftController,
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
                                          width: constraints.maxWidth,
                                          child: Center(
                                            child: AspectRatio(
                                              aspectRatio: widget.isFromCollections ? 32 / 15 : 1,
                                              child: Container(
                                                width: constraints.maxWidth * 0.9,
                                                height: widget.isFromCollections ? (constraints.maxWidth * 0.9 * 15 / 32) : constraints.maxWidth * 0.9,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8.0),
                                                  color: const Color(0xff161616),
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
                                                  child: Container(
                                                    color: const Color(0xff161616),
                                                    child: Center(
                                                      child: ImageCacheManager.instance.buildImage(
                                                        url: widget.playlist['cover'] ?? '',
                                                        width: constraints.maxWidth * 0.9,
                                                        height: widget.isFromCollections ? (constraints.maxWidth * 0.9 * 15 / 32) : constraints.maxWidth * 0.9,
                                                        fit: widget.isFromCollections ? BoxFit.fitWidth : BoxFit.cover,
                                                        placeholder: Container(
                                                          color: const Color(0xff161616),
                                                          child: const Icon(Icons.music_note, color: Colors.white54),
                                                        ),
                                                        errorWidget: Container(
                                                          color: const Color(0xff161616),
                                                          child: const Icon(Icons.music_note, color: Colors.white54),
                                                        ),
                                                      ),
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
                              controller: _landscapeRightController,
                              physics: const ClampingScrollPhysics(),
                              slivers: [
                                SliverPadding(
                                  padding: EdgeInsets.only(
                                    top: MediaQuery.of(context).padding.top + 16,
                                  ),
                                  sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                                ),
                                _buildTrackList(),
                                // 添加底部空间以避免被 MiniPlayer 遮挡
                                SliverToBoxAdapter(
                                  child: SizedBox(height: miniPlayerHeight + 16),
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
                      color.withOpacity(0.95), // 顶部更不透明
                      color.withOpacity(0.7), // 中间过渡色更深
                      const Color(0xff161616), // 底部保持黑色
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
                child: child!,
              );
            },
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
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
      );
    }
  }

  Widget _buildSliverAppBar() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double imageSize = screenWidth * 0.7;
    final double minImageSize = screenWidth * 0.3;
    final double topPadding = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<double>(
      valueListenable: _bgOpacity,
      builder: (context, opacity, child) {
        // 使用 Transform.scale 代替直接改变 size
        final double scale = ((imageSize - (imageSize - minImageSize) * opacity) / imageSize).clamp(minImageSize / imageSize, 1.0);
        final double titleOpacity = ((opacity - 0.7) * 5).clamp(0.0, 1.0);

        final Color backgroundColor = opacity <= 0.01 ? Colors.transparent : (secondaryColor?.withOpacity(opacity) ?? const Color(0xff161616).withOpacity(opacity));

        // 计算 Collections 图片的高度
        final double imageHeight = widget.isFromCollections ? (screenWidth * 0.7 * 15 / 32) : imageSize;

        return SliverAppBar(
          expandedHeight: widget.isFromCollections ? imageHeight + topPadding + 10 : imageSize + topPadding + 10,
          pinned: true,
          stretch: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          backgroundColor: backgroundColor, // 恢复背景色
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
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: imageSize,
                        height: widget.isFromCollections ? (screenWidth * 0.7 * 15 / 32) : imageSize,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2 * (1 - opacity)), // 随滚动调整阴影
                                blurRadius: 8 * (1 - opacity), // 随滚动调整模糊
                                offset: Offset(0, 4 * (1 - opacity)), // 随滚动调整偏移
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: ImageCacheManager.instance.buildImage(
                              url: widget.playlist['cover'] ?? '',
                              width: imageSize,
                              height: widget.isFromCollections ? (screenWidth * 0.7 * 15 / 32) : imageSize,
                              fit: widget.isFromCollections ? BoxFit.fitWidth : BoxFit.cover,
                              placeholder: Container(
                                color: const Color(0xff161616),
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                              errorWidget: Container(
                                color: const Color(0xff161616),
                                child: const Icon(Icons.music_note, color: Colors.white54),
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
                      '${widget.trackCount ?? _allTracks.length} 首歌曲',
                      style: _subtitleStyle,
                    ),
                  ],
                ),
              ),
              _buildPlayControls(),
            ],
          ),
          if (widget.description?.isNotEmpty ?? false) ...[
            _divider,
            Text(
              widget.description!,
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
          tracks: List<Map<String, dynamic>>.from(_displayedTracks),
        ),
      ],
    );
  }

  Widget _buildTrackList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _displayedTracks.length) {
            if (_hasMoreData) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              );
            }
            return null;
          }
          return _buildTrackItem(index, _displayedTracks[index]);
        },
        childCount: _displayedTracks.length + (_hasMoreData ? 1 : 0),
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
            _playTrack(track, _displayedTracks, index);
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
