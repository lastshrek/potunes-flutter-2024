import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CarouselSlider extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Function(int) onTap;

  const CarouselSlider({
    super.key,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 添加组件级别的调试信息
    print('=== CarouselSlider Debug ===');
    print('Total items: ${items.length}');
    print('All items: $items');

    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.9),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          // 添加详细的单项调试信息
          print('Building carousel item $index:');
          print('- Full item: $item');
          print('- Title: ${item['title']}');
          print('- Cover URL: ${item['cover_url']}');

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: () => onTap(index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item['cover_url'] ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                  // 渐变遮罩
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // 标题
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      item['title']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
