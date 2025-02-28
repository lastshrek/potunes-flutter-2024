import 'package:flutter/material.dart';
import 'skeleton_loading.dart';
import 'common/cached_image.dart';

class HorizontalPlaylistList extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> playlists;
  final bool isLoading;
  final VoidCallback? onTitleTap;
  final Function(Map<String, dynamic>) onPlaylistTap;

  const HorizontalPlaylistList({
    super.key,
    required this.title,
    required this.playlists,
    required this.isLoading,
    this.onTitleTap,
    required this.onPlaylistTap,
  });

  Widget _buildPlaylistItem(BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => onPlaylistTap(item),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CachedImage(
                  url: item['cover'] ?? '',
                  width: 120,
                  height: 120,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (item['artist'] != null)
                    Text(
                      item['artist'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
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
    );
  }

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
              isLoading
                  ? const SkeletonLoading(
                      width: 100,
                      height: 18,
                    )
                  : Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
              if (onTitleTap != null)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: isLoading
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
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  child: const SkeletonLoading(),
                );
              }
              return _buildPlaylistItem(context, playlists[index]);
            },
          ),
        ),
      ],
    );
  }
}
