import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final bool showDrawer;
  final List<Widget>? actions;
  final bool showSearch;
  final Function(String)? onSearchChanged;
  final VoidCallback? onSearchTap;

  const AppHeader({
    super.key,
    required this.title,
    this.showDrawer = true,
    this.actions,
    this.showSearch = false,
    this.onSearchChanged,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      pinned: false,
      centerTitle: false,
      leading: showDrawer
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        if (showSearch && onSearchTap != null)
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: onSearchTap,
          ),
        if (actions != null) ...actions!,
      ],
    );
  }
}
