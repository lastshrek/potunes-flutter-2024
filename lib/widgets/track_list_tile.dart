import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrackListTile extends StatelessWidget {
  final Map<String, dynamic> track;
  final VoidCallback onTap;
  final bool isPlaying;
  final int index;

  const TrackListTile({
    super.key,
    required this.track,
    required this.onTap,
    required this.isPlaying,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
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
                      color: Colors.white,
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                    ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track['artist'] ?? '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}
