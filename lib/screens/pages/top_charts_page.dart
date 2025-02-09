import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/top_charts_controller.dart';

class TopChartsPage extends GetView<TopChartsController> {
  const TopChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: const Text(
          'Top Charts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Obx(() {
        print('Building TopChartsPage with ${controller.charts.length} items');
        print('isNetworkReady: ${controller.isNetworkReady}');

        // 显示加载动画
        if (controller.isRefreshing) {
          return _buildSkeletonList();
        }

        // 显示错误信息
        if (controller.error.value != null) {
          return Center(
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
            return const Center(
              child: Text(
                '等待网络连接...',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          return const Center(
            child: Text(
              '暂无数据',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        // 显示数据列表
        return RefreshIndicator(
          onRefresh: controller.refreshData,
          backgroundColor: Colors.black,
          color: Colors.white,
          child: ListView.builder(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16,
            ),
            itemCount: controller.charts.length,
            itemBuilder: (context, index) {
              final chart = controller.charts[index];
              return controller.isRefreshing ? _buildSkeletonItem() : _buildTrackItem(chart, index);
            },
          ),
        );
      }),
    );
  }

  Widget _buildTrackItem(Map<String, dynamic> chart, int index) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => controller.openChart(chart),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: index < 3 ? Colors.white : Colors.grey[400],
                fontSize: index < 3 ? 18 : 14,
                fontWeight: index < 3 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              chart['cover_url'] ?? '',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
      title: Text(
        chart['name'] ?? '',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        chart['artist'] ?? '',
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) {
          return _buildSkeletonItem();
        },
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
