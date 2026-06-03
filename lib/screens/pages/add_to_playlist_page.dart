import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../widgets/common/cached_image.dart';
import '../../services/network_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AddToPlaylistPage extends StatefulWidget {
  final Map<String, dynamic> track;

  const AddToPlaylistPage({
    super.key,
    required this.track,
  });

  // 静态方法用于显示页面
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> track,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddToPlaylistPage(track: track),
      ),
    );
  }

  @override
  State<AddToPlaylistPage> createState() => _AddToPlaylistPageState();
}

class _AddToPlaylistPageState extends State<AddToPlaylistPage> {
  final NetworkService _networkService = NetworkService.instance;
  final List<Map<String, dynamic>> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 打印传入的 track 数据
    if (kDebugMode) {
      print('AddToPlaylistPage received track: ${widget.track}');
    }
    // 延迟加载以等待页面转场动画完成
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadPlaylists();
      }
    });
  }

  Future<void> _loadPlaylists() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final playlists = await _networkService.getUserPlaylists();

      if (mounted) {
        setState(() {
          _playlists.clear();
          _playlists.addAll(playlists);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取歌单失败')),
        );
      }
    }
  }

  Future<void> _createPlaylist() async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      '新建歌单',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: '请输入歌单标题',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                        filled: true,
                        fillColor: Colors.grey[850],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.white24,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[800]!,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 0.5,
                      height: 52,
                      color: Colors.grey[800],
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, controller.text),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          '确定',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final newPlaylist = await _networkService.createPlaylist(result);
        setState(() {
          if (_playlists.isEmpty) {
            _playlists.add(newPlaylist);
          } else {
            _playlists.insert(0, newPlaylist);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建歌单成功')),
          );
        }
      } catch (e) {
        print('createPlaylist error: $e');
        if (mounted && (e is! DioException || (e.response?.statusCode != 201))) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建歌单失败')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '加入歌单',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _createPlaylist,
            child: const Text(
              '新建歌单',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              '保存位置',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: _playlists.length + 1, // +1 for liked songs
                    separatorBuilder: (context, index) => const SizedBox(height: 8.0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.purple.withOpacity(0.6),
                                  Colors.blue.withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          title: const Text(
                            '已点赞的歌曲',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          onTap: () async {
                            try {
                              final bool success = await _networkService.likeTrack(widget.track);
                              if (mounted) {
                                Navigator.pop(context);
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已添加到喜欢')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('添加失败')),
                                  );
                                }
                              }
                              // ignore: empty_catches
                            } catch (e) {}
                          },
                        );
                      }
                      final playlist = _playlists[index - 1];
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.queue_music,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          playlist['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () async {
                          try {
                            final bool success = await _networkService.addTrackToPlaylist(
                              playlist['id'],
                              widget.track,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已添加到歌单')),
                                );
                              }
                            }
                          } catch (e) {}
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
