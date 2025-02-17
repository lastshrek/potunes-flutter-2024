import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/common/cached_image.dart';
import '../screens/pages/add_to_playlist_page.dart';

class SongOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> track;
  final VoidCallback? onAddToPlaylist;

  const SongOptionsSheet({
    super.key,
    required this.track,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 专辑封面
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedImage(
                    url: track['cover_url'] ?? '',
                    width: 56,
                    height: 56,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 16),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track['artist'] ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add, color: Colors.white),
            title: const Text(
              '添加到歌单',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () {
              Navigator.pop(context);
              AddToPlaylistPage.show(
                context: context,
                track: track,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.album, color: Colors.white),
            title: const Text(
              '转至专辑',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('暂不支持转至专辑功能'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: const Text(
              '转至艺人',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('暂不支持转至艺人功能'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 静态方法用于显示底部菜单
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> track,
    VoidCallback? onAddToPlaylist,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SongOptionsSheet(
        track: track,
        onAddToPlaylist: onAddToPlaylist,
      ),
    );
  }
}
