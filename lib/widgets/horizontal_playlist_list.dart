import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'skeleton_loading.dart';

class HorizontalPlaylistList extends StatelessWidget {
  final String title;
  final List<dynamic> playlists;
  final VoidCallback? onTitleTap;
  final Function(Map<String, dynamic>)? onPlaylistTap;
  final bool isLoading;

  const HorizontalPlaylistList({
    super.key,
    required this.title,
    required this.playlists,
    this.onTitleTap,
    this.onPlaylistTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_outward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: onTitleTap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: isLoading ? 3 : playlists.length,
            itemBuilder: (context, index) {
              if (isLoading) {
                return const _PlaylistCard.loading();
              }
              final item = playlists[index];
              return _PlaylistCard(
                imageUrl: item['cover'] ?? '',
                title: item['title'] ?? '',
                onTap: () {
                  onPlaylistTap?.call(item);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistItem(Map<String, dynamic> playlist) {
    return GestureDetector(
      onTap: () => onPlaylistTap?.call(playlist),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
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
                  memCacheWidth: 240, // 限制缓存图片大小
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.music_note,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist['title'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (playlist['count'] != null) ...[
              const SizedBox(height: 4),
              Text(
                '${playlist['count']} 首歌曲',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final VoidCallback? onTap;
  final bool isLoading;

  const _PlaylistCard({
    required this.imageUrl,
    required this.title,
    this.onTap,
  }) : isLoading = false;

  const _PlaylistCard.loading()
      : imageUrl = '',
        title = '',
        onTap = null,
        isLoading = true;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AspectRatio(
              aspectRatio: 1,
              child: SkeletonLoading(),
            ),
            const SizedBox(height: 6),
            const SkeletonLoading(
              width: 100,
              height: 24,
            ),
          ],
        ),
      );
    }

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
