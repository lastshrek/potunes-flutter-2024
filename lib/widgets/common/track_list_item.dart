import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/audio_service.dart';
import 'current_track_highlight.dart';
import 'cached_image.dart';

class TrackListItem extends StatelessWidget {
  final Map<String, dynamic> track;
  final int index;
  final List<Map<String, dynamic>> playlist;
  final bool showIndex;
  final bool showDuration;
  final VoidCallback? onTap;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final TextStyle? indexStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? durationStyle;

  const TrackListItem({
    super.key,
    required this.track,
    required this.index,
    required this.playlist,
    this.showIndex = true,
    this.showDuration = true,
    this.onTap,
    this.trailing,
    this.titleStyle,
    this.indexStyle,
    this.subtitleStyle,
    this.durationStyle,
  });

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleTap() {
    if (onTap != null) {
      onTap!();
      return;
    }

    final audioService = Get.find<AudioService>();
    audioService.playPlaylist(playlist, initialIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Get.find<AudioService>();
    final highlightColor = const Color(0xFFDA5597);

    return Obx(() {
      final isCurrentTrack = audioService.isCurrentTrack(track);

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: CurrentTrackHighlight(
          track: track,
          child: CachedImage(
            url: track['cover_url'] ?? '',
            width: 56,
            height: 56,
          ),
        ),
        title: RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              if (showIndex)
                TextSpan(
                  text: '${index + 1}. ',
                  style: (indexStyle ??
                          TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ))
                      .copyWith(
                    color: isCurrentTrack ? highlightColor : null,
                  ),
                ),
              TextSpan(
                text: track['name'] ?? '',
                style: (titleStyle ??
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ))
                    .withHighlight(isCurrentTrack, highlightColor),
              ),
            ],
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                track['artist'] ?? '',
                style: (subtitleStyle ??
                        TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ))
                    .withSubtleHighlight(isCurrentTrack, highlightColor),
              ),
            ),
            if (track['type'] == 'netease')
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey[600]!),
                  ),
                  child: Text(
                    '网易',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDuration)
              Text(
                _formatDuration(int.parse(track['duration'].toString())),
                style: (durationStyle ??
                    const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    )),
              ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
        onTap: _handleTap,
      );
    });
  }
}
