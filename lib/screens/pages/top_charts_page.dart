import 'package:flutter/material.dart';

class TopChartsPage extends StatelessWidget {
  const TopChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Top Charts',
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
