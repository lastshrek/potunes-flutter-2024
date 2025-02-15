import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/top_charts_controller.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_drawer.dart';
import '../../services/audio_service.dart';
import '../../widgets/common/current_track_highlight.dart';
import '../../widgets/common/cached_image.dart';

class TopChartsPage extends GetView<TopChartsController> {
  const TopChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: controller.refreshData,
        backgroundColor: Colors.black,
        color: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const AppHeader(title: 'Top Charts'),
            Obx(() {
              // 显示加载动画
              if (controller.isRefreshing) {
                return _buildSkeletonList();
              }

              // 显示错误信息
              if (controller.error.value != null) {
                return SliverFillRemaining(
                  hasScrollBody: false,
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
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: const Center(
                      child: Text(
                        '等待网络连接...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: const Center(
                    child: Text(
                      '暂无数据',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }

              // 显示数据列表
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chart = controller.charts[index];
                    return _buildTrackItem(chart, index);
                  },
                  childCount: controller.charts.length,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackItem(Map<String, dynamic> chart, int index) {
    final audioService = Get.find<AudioService>();
    final highlightColor = const Color(0xFFDA5597);
    final isTop3 = index < 3;

    return Obx(() {
      final isCurrentTrack = audioService.isCurrentTrack(chart);

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: () => controller.openChart(chart),
        leading: CurrentTrackHighlight(
          track: chart,
          child: CachedImage(
            url: chart['cover_url'] ?? '',
            width: 56,
            height: 56,
          ),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${index + 1}. ',
                style: TextStyle(
                  color: isCurrentTrack ? highlightColor : (isTop3 ? Colors.white : Colors.grey[400]),
                  fontSize: isTop3 ? 18 : 14,
                  fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              TextSpan(
                text: chart['name'] ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTop3 ? 16 : 15,
                  fontWeight: isTop3 ? FontWeight.w600 : FontWeight.w500,
                ).withHighlight(isCurrentTrack),
              ),
            ],
          ),
        ),
        subtitle: Text(
          chart['artist'] ?? '',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: isTop3 ? 14 : 13,
          ).withSubtleHighlight(isCurrentTrack),
        ),
      );
    });
  }

  Widget _buildSkeletonList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey[900]!,
          highlightColor: Colors.grey[800]!,
          child: _buildSkeletonItem(),
        ),
        childCount: 10,
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
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
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
