import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/top_charts_controller.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/track_list_item.dart';
import '../../widgets/song_options_sheet.dart';
import '../../screens/pages/add_to_playlist_page.dart';

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
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        '等待网络连接...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
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
                    return RepaintBoundary(
                      child: Material(
                        type: MaterialType.transparency,
                        child: TrackListItem(
                          track: chart,
                          index: index,
                          playlist: controller.charts,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          indexStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          subtitleStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          durationStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => _showTrackOptions(context, chart),
                          ),
                          onTap: () => controller.openChart(chart),
                        ),
                      ),
                    );
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

  void _showTrackOptions(BuildContext context, dynamic track) {
    SongOptionsSheet.show(
      context: context,
      track: track as Map<String, dynamic>,
      onAddToPlaylist: () {
        AddToPlaylistPage.show(
          context: context,
          track: track as Map<String, dynamic>,
        );
      },
    );
  }
}
