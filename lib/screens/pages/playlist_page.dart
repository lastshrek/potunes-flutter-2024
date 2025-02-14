import 'dart:async';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/common/cached_image.dart';

import '../../services/network_service.dart';
import '../../services/audio_service.dart';
import '../../widgets/mini_player.dart';
import '../../utils/image_cache_manager.dart';
import '../../widgets/common/current_track_highlight.dart';

extension ColorExtension on Color {
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  Color saturate([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl.withSaturation((hsl.saturation + amount).clamp(0.0, 1.0)).toColor();
  }
}

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

class _PlaylistPageState extends State<PlaylistPage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, RouteAware {
  final NetworkService _networkService = NetworkService.instance;
  bool _isLoading = false;
  bool _isRouteReady = false;
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
  final _colorNotifier = ValueNotifier<Color>(Colors.black);
  Timer? _colorAnimationTimer;

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

  // 添加预加载标记
  bool _isPreloading = true;

  // 修改颜色缓存的类型声明
  static final Map<String, Color> _colorCache = {};
  String? _lastTrackUrl;

  @override
  bool get wantKeepAlive => false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 使用正确的类型获取 RouteObserver
    final RouteObserver<Route<dynamic>> routeObserver = Get.find<RouteObserver<Route<dynamic>>>();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_onScrollForPagination);
    _landscapeRightController.addListener(_onScrollForPagination);

    // 预加载数据
    _preloadData();
  }

  @override
  void dispose() {
    // 使用正确的类型获取 RouteObserver
    Get.find<RouteObserver<Route<dynamic>>>().unsubscribe(this);
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
    _colorNotifier.dispose();
    _colorAnimationTimer?.cancel();
    super.dispose();
  }

  // 监听路由动画完成
  @override
  void didPushNext() {
    // 路由被覆盖
  }

  @override
  void didPopNext() {
    // 上层路由被移除
  }

  @override
  void didPush() {
    // 路由被推入
  }

  @override
  void didPop() {
    // 路由被弹出
  }

  // 预加载数据
  Future<void> _preloadData() async {
    // 在后台线程加载数据
    unawaited(_loadTracks());

    // 等待页面转场动画完成后再显示内容
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _isPreloading = false;
        _isRouteReady = true;
        _isLoading = true;
      });

      // 开始提取颜色
      _extractColors();
    }
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
      // 添加小延迟，确保颜色提取有足够时间完成
      await Future.delayed(const Duration(milliseconds: 100));

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

  // 优化颜色提取
  Future<void> _extractColors() async {
    try {
      // 获取所有可能的封面 URL
      String? coverUrl = widget.coverUrl;

      // 如果没有直接的 coverUrl，尝试从 playlist 中获取
      if (coverUrl == null || coverUrl.isEmpty) {
        // 尝试所有可能的封面字段
        coverUrl = widget.playlist['cover_url'] ?? widget.playlist['cover'] ?? widget.playlist['coverUrl'] ?? widget.playlist['coverImgUrl'] ?? widget.playlist['picUrl'] ?? '';
      }

      // 检查 coverUrl 是否为空
      if (coverUrl?.isEmpty ?? true) {
        debugPrint('No cover URL found for playlist');
        // 使用默认颜色
        setState(() {
          dominantColor = Colors.black;
          secondaryColor = Colors.black.withOpacity(0.7);
        });
        return;
      }

      // 将 coverUrl 转换为非空类型
      final String nonNullCoverUrl = coverUrl!;

      // 检查是否是相同的图片
      if (nonNullCoverUrl == _lastTrackUrl) return;
      _lastTrackUrl = nonNullCoverUrl;

      debugPrint('Extracting colors from cover: $nonNullCoverUrl');

      // 检查缓存
      if (_colorCache.containsKey(nonNullCoverUrl)) {
        final cachedColor = _colorCache[nonNullCoverUrl]!;
        setState(() {
          dominantColor = cachedColor;
          secondaryColor = cachedColor.withOpacity(0.7);
        });
        // 添加颜色过渡动画
        _startColorTransition(
          from: _colorNotifier.value,
          to: cachedColor,
          duration: const Duration(milliseconds: 300),
        );
        return;
      }

      // 使用较小的图片尺寸
      final imageProvider = ResizeImage(
        CachedNetworkImageProvider(nonNullCoverUrl),
        width: 100,
        height: 100,
      );

      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100),
        maximumColorCount: 8,
      );

      if (!mounted) return;

      final newColor = paletteGenerator.darkMutedColor?.color ?? paletteGenerator.dominantColor?.color ?? Colors.black;

      setState(() {
        dominantColor = newColor;
        secondaryColor = newColor.withOpacity(0.7);
        _colorCache[nonNullCoverUrl] = newColor;
      });

      // 添加颜色过渡动画
      _startColorTransition(
        from: _colorNotifier.value,
        to: newColor,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      debugPrint('Error extracting colors: $e');
      // 使用默认颜色
      setState(() {
        dominantColor = Colors.black;
        secondaryColor = Colors.black.withOpacity(0.7);
      });
    }
  }

  void _startColorTransition({
    required Color from,
    required Color to,
    required Duration duration,
  }) {
    if (!mounted) return;

    final startTime = DateTime.now();
    _colorTween.begin = from;
    _colorTween.end = to;

    void updateColor() {
      if (!mounted) {
        _colorAnimationTimer?.cancel();
        return;
      }

      final elapsedTime = DateTime.now().difference(startTime);
      if (elapsedTime >= duration) {
        _colorNotifier.value = to;
        _colorAnimationTimer?.cancel();
        return;
      }

      final t = (elapsedTime.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      _colorNotifier.value = Color.lerp(_colorTween.begin!, _colorTween.end!, t)!;

      _colorAnimationTimer = Timer(const Duration(milliseconds: 16), updateColor);
    }

    _colorAnimationTimer?.cancel();
    _colorAnimationTimer = Timer(Duration.zero, updateColor);
  }

  // 修改图片加载方法
  static Future<Uint8List> _loadImageData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw Exception('Failed to load image');
    } catch (e) {
      print('Error loading image data: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 在预加载时显示空白页面
    if (_isPreloading) {
      return const Material(
        color: Colors.black,
        child: SizedBox.shrink(),
      );
    }

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
            valueListenable: _colorNotifier,
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
                                                  child: Center(
                                                    child: CachedImage(
                                                      url: widget.playlist['cover'] ?? '',
                                                      width: constraints.maxWidth * 0.9,
                                                      height: widget.isFromCollections ? (constraints.maxWidth * 0.9 * 15 / 32) : constraints.maxWidth * 0.9,
                                                      fit: widget.isFromCollections ? BoxFit.fitWidth : BoxFit.cover,
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
                              physics: const BouncingScrollPhysics(),
                              slivers: [
                                const SliverAppBar(
                                  backgroundColor: Colors.transparent,
                                  pinned: true,
                                  expandedHeight: 0,
                                  toolbarHeight: 0,
                                ),
                                _buildTrackList(),
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
            valueListenable: _colorNotifier,
            builder: (context, color, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withOpacity(0.95),
                      color.withOpacity(0.7),
                      const Color(0xff161616),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
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
              );
            },
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
                            child: CachedImage(
                              url: widget.playlist['cover'] ?? '',
                              width: imageSize,
                              height: widget.isFromCollections ? (screenWidth * 0.7 * 15 / 32) : imageSize,
                              fit: widget.isFromCollections ? BoxFit.fitWidth : BoxFit.cover,
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
            AudioService.to.playPlaylist(
              List<Map<String, dynamic>>.from(_allTracks),
              initialIndex: 0,
            );
          },
        ),
        const SizedBox(width: 8),
        PlayButton(
          backgroundColor: dominantColor?.darken(0.15).withOpacity(0.8),
          tracks: List<Map<String, dynamic>>.from(_allTracks),
        ),
      ],
    );
  }

  Widget _buildTrackList() {
    if (!_isRouteReady || _isPreloading) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

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
    final audioService = Get.find<AudioService>();
    final highlightColor = const Color(0xFFDA5597);

    return Obx(() {
      final isCurrentTrack = audioService.isCurrentTrack(track);

      // 创建基础文本样式
      final baseTextStyle = const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

      // 根据是否是当前播放的歌曲获取高亮样式
      final highlightedStyle = baseTextStyle.copyWith(
        color: isCurrentTrack ? highlightColor : Colors.white,
      );

      return RepaintBoundary(
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            key: ValueKey('track_${track['id']}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            tileColor: Colors.transparent,
            selectedTileColor: Colors.transparent,
            hoverColor: Colors.white.withOpacity(0.1),
            splashColor: Colors.transparent,
            leading: CurrentTrackHighlight(
              track: track,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedImage(
                  url: track['cover_url'] ?? '',
                  width: 56,
                  height: 56,
                  borderRadius: BorderRadius.circular(8),
                ),
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
                    text: track['name'] ?? '',
                    style: highlightedStyle,
                  ),
                ],
              ),
            ),
            subtitle: Text(
              track['artist'] ?? '',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ).withSubtleHighlight(isCurrentTrack),
            ),
            onTap: () {
              _playTrack(track, _displayedTracks, index);
            },
          ),
        ),
      );
    });
  }

  void _playTrack(dynamic track, List<dynamic> tracks, int index) {
    AudioService.to.playPlaylist(
      List<Map<String, dynamic>>.from(_allTracks),
      initialIndex: index,
    );
  }

  void _handlePopBack() {
    Navigator.of(context).pop();
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
