import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/top_charts_controller.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_drawer.dart';
import '../../services/audio_service.dart';
import '../../widgets/common/current_track_highlight.dart';

class TopChartsPage extends GetView<TopChartsController> {
  const TopChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(),
      body: CustomScrollView(
        slivers: [
          const AppHeader(title: 'Top Charts'),
          Obx(() {
            print('Building TopChartsPage with ${controller.charts.length} items');
            print('isNetworkReady: ${controller.isNetworkReady}');

            // 显示加载动画
            if (controller.isRefreshing) {
              return _buildSkeletonList();
            }

            // 显示错误信息
            if (controller.error.value != null) {
              return SliverFillRemaining(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      controller.error.value!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: controller.retryConnection,
                      child: const Text(
                        '重试',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            }

            // 显示空状态
            if (controller.charts.isEmpty) {
              if (!controller.isNetworkReady) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      '等待网络连接...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
              return const SliverFillRemaining(
                child: Center(
                  child: Text(
                    '暂无数据',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            }

            // 显示数据列表
            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chart = controller.charts[index];
                    return _buildTrackItem(chart, index);
                  },
                  childCount: controller.charts.length,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrackItem(Map<String, dynamic> chart, int index) {
    final audioService = Get.find<AudioService>();
    final highlightColor = const Color(0xFFDA5597);

    return Obx(() {
      final currentTrack = audioService.currentTrack;
      final isCurrentTrack = currentTrack != null && ((currentTrack['id']?.toString() == chart['id']?.toString()) || (currentTrack['nId']?.toString() == chart['nId']?.toString()));

      // 创建基础文本样式
      final baseTextStyle = const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

      // 根据是否是当前播放的歌曲获取高亮样式
      final highlightedStyle = baseTextStyle.withHighlight(isCurrentTrack);

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: () => controller.openChart(chart),
        leading: CurrentTrackHighlight(
          track: chart,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              chart['cover_url'] ?? '',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${index + 1}. ',
                style: TextStyle(
                  color: isCurrentTrack ? highlightColor : (index < 3 ? Colors.white : Colors.grey[400]),
                  fontSize: index < 3 ? 18 : 14,
                  fontWeight: index < 3 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              TextSpan(
                text: chart['name'] ?? '',
                style: highlightedStyle,
              ),
            ],
          ),
        ),
        subtitle: Text(
          chart['artist'] ?? '',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ).withSubtleHighlight(isCurrentTrack),
        ),
      );
    });
  }

  Widget _buildSkeletonList() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Shimmer.fromColors(
            baseColor: Colors.grey[900]!,
            highlightColor: Colors.grey[800]!,
            child: _buildSkeletonItem(),
          ),
          childCount: 10,
        ),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 20,
            color: Colors.grey[800],
          ),
          const SizedBox(width: 8),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.grey[800],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  color: Colors.grey[800],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
