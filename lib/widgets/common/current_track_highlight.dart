import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/audio_service.dart';

class CurrentTrackHighlight extends StatelessWidget {
  final Map<String, dynamic> track;
  final Widget child;

  const CurrentTrackHighlight({
    super.key,
    required this.track,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final audioService = Get.find<AudioService>();

    return Obx(() {
      final isCurrentTrack = audioService.isCurrentTrack(track);
      final isPlaying = audioService.isPlaying;

      // 只有当前播放的歌曲且正在播放时才显示波浪线
      final shouldShowWave = isCurrentTrack && isPlaying;

      return Stack(
        children: [
          child,
          if (shouldShowWave)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Center(
                  child: AudioWaveBar(),
                ),
              ),
            ),
        ],
      );
    });
  }
}

// 添加扩展方法
extension HighlightTextStyle on TextStyle {
  TextStyle withHighlight(bool isCurrentTrack, [Color? highlightColor]) {
    final color = highlightColor ?? const Color(0xFFDA5597);
    return copyWith(
      color: isCurrentTrack ? color : null,
      fontWeight: isCurrentTrack ? FontWeight.bold : null,
    );
  }

  TextStyle withSubtleHighlight(bool isCurrentTrack, [Color? highlightColor]) {
    final color = highlightColor ?? const Color(0xFFDA5597);
    return copyWith(
      color: isCurrentTrack ? color.withOpacity(0.7) : null,
    );
  }
}

// 波形动画组件
class _WaveformBar extends StatefulWidget {
  final Color color;
  final bool isPlaying;
  final double delay;

  const _WaveformBar({
    required this.color,
    required this.isPlaying,
    required this.delay,
  });

  @override
  State<_WaveformBar> createState() => _WaveformBarState();
}

class _WaveformBarState extends State<_WaveformBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isPlaying) {
      Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
        if (mounted) {
          _controller.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(_WaveformBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 2,
          height: 20 * _animation.value,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }
}

// 添加 AudioWaveBar 组件
class AudioWaveBar extends StatefulWidget {
  const AudioWaveBar({super.key});

  @override
  State<AudioWaveBar> createState() => _AudioWaveBarState();
}

class _AudioWaveBarState extends State<AudioWaveBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // 创建3个不同的动画
    for (int i = 0; i < 3; i++) {
      _animations.add(
        Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              i * 0.2, // 错开开始时间
              0.7 + i * 0.2,
              curve: Curves.easeInOut,
            ),
          ),
        ),
      );
    }

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                width: 3,
                height: 20 * _animations[index].value,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
