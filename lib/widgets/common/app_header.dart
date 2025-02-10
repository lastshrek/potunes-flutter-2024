import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final bool showDrawer;
  final List<Widget>? actions;
  final bool showSearch;
  final Function(String)? onSearchChanged;

  const AppHeader({
    super.key,
    required this.title,
    this.showDrawer = true,
    this.actions,
    this.showSearch = false,
    this.onSearchChanged,
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
      title: showSearch
          ? SizedBox(
              height: 40,
              child: TextField(
                style: const TextStyle(color: Colors.white),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[900],
                  hintText: '搜索音乐...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onSearchChanged,
              ),
            )
          : Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
      actions: actions,
    );
  }
}
