import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/audio_service.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = Get.find<AudioService>();

    return Obx(() {
      final currentTrack = audioService.currentTrack;
      if (currentTrack == null) return const SizedBox.shrink();

      return Container(
        height: 64,
        color: Colors.black87,
        child: Row(
          children: [
            // 专辑封面
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(currentTrack['cover_url'] ?? ''),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // 歌曲信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack['name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTrack['artist'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // 控制按钮
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: audioService.previous,
                  color: Colors.white,
                ),
                Obx(() {
                  final isPlaying = audioService.isPlaying;
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: audioService.togglePlay,
                    color: Colors.white,
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: audioService.next,
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
