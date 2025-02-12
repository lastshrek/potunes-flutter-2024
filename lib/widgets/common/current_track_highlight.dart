import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/audio_service.dart';

class CurrentTrackHighlight extends StatelessWidget {
  final Map<String, dynamic> track;
  final Widget child;
  final Color? highlightColor;

  const CurrentTrackHighlight({
    super.key,
    required this.track,
    required this.child,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final audioService = Get.find<AudioService>();
    final color = highlightColor ?? const Color(0xFFDA5597);

    return Obx(() {
      final currentTrack = audioService.currentTrack;
      final isCurrentTrack = currentTrack != null && ((currentTrack['id']?.toString() == track['id']?.toString()) || (currentTrack['nId']?.toString() == track['nId']?.toString()));

      if (!isCurrentTrack) return child;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 动态波浪线
          SizedBox(
            width: 16,
            height: 56,
            child: _buildWaveform(color, audioService.isPlaying),
          ),
          const SizedBox(width: 16),
          // 专辑封面
          child,
        ],
      );
    });
  }

  Widget _buildWaveform(Color color, bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: _WaveformBar(
            color: color,
            isPlaying: isPlaying,
            delay: index * 0.2,
          ),
        );
      }),
    );
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
