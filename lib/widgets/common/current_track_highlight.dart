import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/audio_service.dart';
import 'dart:math' as math;

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
    // 使用 GetX 而不是 Obx，只监听需要的状态
    return GetX<AudioService>(
      builder: (controller) {
        // 提取需要的状态，避免不必要的重建
        final isCurrentTrack = controller.isCurrentTrack(track);
        final isPlaying = controller.isPlaying;

        if (!isCurrentTrack || !isPlaying) {
          return child;
        }

        return Stack(
          children: [
            child,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Center(
                  child: AudioWaveBar(key: ValueKey('wave_bar')),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// 修改扩展方法
extension HighlightTextStyle on TextStyle {
  TextStyle withHighlight(bool isCurrentTrack, [Color? highlightColor]) {
    final color = highlightColor ?? const Color(0xFFDA5597);
    return copyWith(
      color: isCurrentTrack ? color : null,
      fontWeight: isCurrentTrack ? FontWeight.bold : null,
    );
  }

  // 修改 withSubtleHighlight，不再改变颜色
  TextStyle withSubtleHighlight(bool isCurrentTrack, [Color? highlightColor]) {
    return copyWith(
      // 移除颜色变化，保持原有颜色
      fontWeight: isCurrentTrack ? FontWeight.w500 : null, // 可以稍微加粗一点
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
  late final AnimationController _controller;
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // 修改动画区间，确保不超过 1.0
    for (int i = 0; i < 3; i++) {
      _animations.add(
        Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              i * 0.2, // start: 0.0, 0.2, 0.4
              math.min(0.6 + i * 0.2, 1.0), // end: 0.6, 0.8, 1.0
              curve: Curves.easeInOut,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _WaveBar(animation: _animations[index]),
          ),
        ),
      ),
    );
  }
}

// 分离单个波形条
class _WaveBar extends StatelessWidget {
  final Animation<double> animation;

  const _WaveBar({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Container(
        width: 3,
        height: 20 * animation.value,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}
