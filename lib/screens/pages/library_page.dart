import 'package:flutter/material.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Library',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
