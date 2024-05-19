/*
 * @Author       : lastshrek
 * @Date         : 2024-05-19 13:38:40
 * @LastEditors  : lastshrek
 * @LastEditTime : 2024-05-19 13:50:58
 * @FilePath     : /lib/widgets/gradient_containers.dart
 * @Description  : gradient containers
 * Copyright 2024 lastshrek, All Rights Reserved.
 * 2024-05-19 13:38:40
 */

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:potunes_flutter_2024/helpers/helpers.dart';

class GradientContainer extends StatefulWidget {
  final Widget? child;
  final bool? opacity;
  const GradientContainer({super.key, required this.child, this.opacity});

  @override
  State<GradientContainer> createState() => _GradientContainerState();
}

class _GradientContainerState extends State<GradientContainer> {
  MyTheme currentTheme = GetIt.I<MyTheme>();
  @override
  Widget build(BuildContext context) {
    // ignore: use_decorated_box
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? ((widget.opacity == true) ? currentTheme.getTransBackGradient() : currentTheme.getBackGradient())
              : [
                  const Color(0xfff5f9ff),
                  Colors.white,
                ],
        ),
      ),
      child: widget.child,
    );
  }
}
