import 'package:get/get.dart';
import '../services/network_service.dart';
import '../utils/http/api_exception.dart';

class MusicSearchController extends GetxController {
  final NetworkService _networkService = NetworkService.instance;

  final keyword = ''.obs;
  final tracks = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final error = RxnString();

  int _page = 1;
  static const int _limit = 20;

  void search(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      tracks.clear();
      keyword.value = '';
      error.value = null;
      return;
    }

    keyword.value = trimmed;
    _page = 1;
    hasMore.value = true;
    _fetchResults(reset: true);
  }

  void loadMore() {
    if (isLoadingMore.value || !hasMore.value) return;
    _page++;
    _fetchResults(reset: false);
  }

  Future<void> _fetchResults({required bool reset}) async {
    if (reset) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }
    error.value = null;

    try {
      final data = await _networkService.search(
        keyword.value,
        page: _page,
        limit: _limit,
      );

      final List<dynamic> rawTracks = data['tracks'] is List
          ? data['tracks'] as List<dynamic>
          : [];
      final results = rawTracks
          .whereType<Map<String, dynamic>>()
          .toList();

      if (reset) {
        tracks.value = results;
      } else {
        tracks.addAll(results);
      }

      final pagination = data['pagination'] as Map<String, dynamic>?;
      if (pagination != null) {
        final totalPages = pagination['totalPages'] as int? ?? 1;
        hasMore.value = _page < totalPages;
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      if (reset) tracks.clear();
      error.value = e is ApiException ? e.message : '搜索失败，请重试';
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  void clear() {
    keyword.value = '';
    tracks.clear();
    error.value = null;
    _page = 1;
    hasMore.value = true;
  }
}
