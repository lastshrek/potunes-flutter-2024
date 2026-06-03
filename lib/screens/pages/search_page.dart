import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/search_controller.dart';
import '../../services/audio_service.dart';
import '../../widgets/common/track_list_item.dart';
import '../../widgets/song_options_sheet.dart';
import '../../screens/pages/add_to_playlist_page.dart';

class SearchPage extends GetView<MusicSearchController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 16, top: 8, bottom: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                autofocus: true,
                onChanged: controller.search,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[900],
                  hintText: '搜索音乐...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: Obx(() =>
                      controller.keyword.value.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.grey, size: 20),
                              onPressed: () {
                                controller.clear();
                              },
                            )
                          : const SizedBox()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (controller.isLoading.value) {
        return _buildSkeletonList();
      }

      if (controller.error.value != null) {
        return _buildErrorState();
      }

      if (controller.keyword.value.isEmpty) {
        return _buildInitialState();
      }

      if (controller.tracks.isEmpty) {
        return _buildEmptyState();
      }

      return _buildResultsList();
    });
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, color: Colors.grey[700], size: 64),
          const SizedBox(height: 16),
          Text(
            '搜索你喜欢的音乐...',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off_outlined, color: Colors.grey[700], size: 64),
          const SizedBox(height: 16),
          Text(
            '未找到相关歌曲',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, color: Colors.grey[700], size: 64),
          const SizedBox(height: 16),
          Text(
            controller.error.value!,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => controller.search(controller.keyword.value),
            child: const Text(
              '重试',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    final audioService = Get.find<AudioService>();
    final scrollController = ScrollController();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        controller.loadMore();
      }
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          controller.loadMore();
        }
        return false;
      },
      child: Obx(() {
        final items = controller.tracks;
        return ListView.builder(
          controller: scrollController,
          itemCount: items.length + (controller.isLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            }

            final track = items[index];
            return RepaintBoundary(
              child: Material(
                type: MaterialType.transparency,
                child: TrackListItem(
                  track: track,
                  index: index,
                  playlist: items,
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
                    onPressed: () => _showTrackOptions(context, track),
                  ),
                  onTap: () {
                    audioService.playPlaylist(items, initialIndex: index);
                  },
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _showTrackOptions(BuildContext context, Map<String, dynamic> track) {
    SongOptionsSheet.show(
      context: context,
      track: track,
      onAddToPlaylist: () {
        AddToPlaylistPage.show(
          context: context,
          track: track,
        );
      },
    );
  }
}
