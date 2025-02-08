import 'package:flutter/material.dart';
import 'dart:async';

class ScrollingText extends StatefulWidget {
  final String title;
  final String subtitle;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final double width;

  const ScrollingText({
    super.key,
    required this.title,
    required this.subtitle,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.width,
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> with SingleTickerProviderStateMixin {
  late ScrollController _titleController;
  late ScrollController _subtitleController;
  Timer? _titleTimer;
  Timer? _subtitleTimer;
  bool _titleNeedsScroll = false;
  bool _subtitleNeedsScroll = false;

  @override
  void initState() {
    super.initState();
    _titleController = ScrollController();
    _subtitleController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNeedsScroll();
      _setupScrolling();
    });
  }

  @override
  void dispose() {
    _titleTimer?.cancel();
    _subtitleTimer?.cancel();
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  void _checkIfNeedsScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 检查标题是否需要滚动
      final titleContext = _titleKey.currentContext;
      if (titleContext != null) {
        final titleBox = titleContext.findRenderObject() as RenderBox;
        final titleWidth = titleBox.size.width;
        setState(() {
          _titleNeedsScroll = titleWidth > widget.width;
        });
        print('Title width: $titleWidth, Container width: ${widget.width}, Needs scroll: $_titleNeedsScroll');
      }

      // 检查副标题是否需要滚动
      final subtitleContext = _subtitleKey.currentContext;
      if (subtitleContext != null) {
        final subtitleBox = subtitleContext.findRenderObject() as RenderBox;
        final subtitleWidth = subtitleBox.size.width;
        setState(() {
          _subtitleNeedsScroll = subtitleWidth > widget.width;
        });
        print('Subtitle width: $subtitleWidth, Container width: ${widget.width}, Needs scroll: $_subtitleNeedsScroll');
      }

      // 如果需要滚动，启动滚动
      if (_titleNeedsScroll || _subtitleNeedsScroll) {
        _setupScrolling();
      }
    });
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当文本内容改变时重新检查
    if (oldWidget.title != widget.title || oldWidget.subtitle != widget.subtitle) {
      _checkIfNeedsScroll();
    }
  }

  void _setupScrolling() {
    if (_titleNeedsScroll) {
      _startTitleScrolling();
    }
    if (_subtitleNeedsScroll) {
      _startSubtitleScrolling();
    }
  }

  void _startTitleScrolling() {
    if (!_titleNeedsScroll) return;

    _titleTimer?.cancel();
    _titleTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || !_titleNeedsScroll) return;

      if (_titleController.hasClients) {
        final maxScroll = _titleController.position.maxScrollExtent;
        final currentScroll = _titleController.offset;

        if (currentScroll >= maxScroll) {
          _titleTimer?.cancel();
          Timer(const Duration(seconds: 5), () {
            if (mounted && _titleNeedsScroll) {
              _titleController
                  .animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              )
                  .then((_) {
                if (mounted) {
                  _startTitleScrolling();
                }
              });
            }
          });
        } else {
          _titleController.animateTo(
            currentScroll + 1,
            duration: const Duration(milliseconds: 50),
            curve: Curves.linear,
          );
        }
      }
    });
  }

  void _startSubtitleScrolling() {
    if (!_subtitleNeedsScroll) return;

    _subtitleTimer?.cancel();
    _subtitleTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || !_subtitleNeedsScroll) return;

      if (_subtitleController.hasClients) {
        final maxScroll = _subtitleController.position.maxScrollExtent;
        final currentScroll = _subtitleController.offset;

        if (currentScroll >= maxScroll) {
          _subtitleTimer?.cancel();
          Timer(const Duration(seconds: 5), () {
            if (mounted && _subtitleNeedsScroll) {
              _subtitleController
                  .animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              )
                  .then((_) {
                if (mounted) {
                  _startSubtitleScrolling();
                }
              });
            }
          });
        } else {
          _subtitleController.animateTo(
            currentScroll + 1,
            duration: const Duration(milliseconds: 50),
            curve: Curves.linear,
          );
        }
      }
    });
  }

  final _titleKey = GlobalKey();
  final _subtitleKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SingleChildScrollView(
            controller: _titleController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.title,
              key: _titleKey,
              style: widget.titleStyle,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            controller: _subtitleController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.subtitle,
              key: _subtitleKey,
              style: widget.subtitleStyle,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
