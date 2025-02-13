import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/network_service.dart';
import '../services/audio_service.dart';
import '../controllers/base_controller.dart';

class TopChartsController extends BaseController {
  static TopChartsController get to => Get.find();

  final NetworkService _networkService = NetworkService.instance;
  final AudioService _audioService = Get.find<AudioService>();
  final _charts = <Map<String, dynamic>>[].obs;
  final _isRefreshing = false.obs;

  static const String _chartsKey = 'top_charts_data';
  static const String _lastUpdateKey = 'top_charts_last_update';

  List<Map<String, dynamic>> get charts => _charts;
  bool get isRefreshing => _isRefreshing.value;

  @override
  void onInit() {
    super.onInit();
    loadCachedData();
  }

  @override
  void onNetworkReady() {
    refreshData();
  }

  @override
  Future<void> loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_chartsKey);

      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        _charts.assignAll(decoded.map((item) => Map<String, dynamic>.from(item)).toList());
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  // 保存数据到缓存
  Future<void> _saveToCache(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chartsKey, jsonEncode(data));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  @override
  Future<void> refreshData() async {
    if (!isNetworkReady) {
      return;
    }

    try {
      _isRefreshing.value = true;
      final response = await _networkService.getTopCharts();

      if (response['charts'] is List) {
        final chartsList = response['charts'] as List;
        final newCharts = chartsList.map((item) => item as Map<String, dynamic>).toList();
        _charts.assignAll(newCharts);
        await _saveToCache(newCharts);
      } else {
        print('Invalid data format');
      }
    } catch (e) {
      print('Error refreshing data: $e');
    } finally {
      _isRefreshing.value = false;
    }
  }

  void openChart(Map<String, dynamic> chart) async {
    try {
      final audioService = Get.find<AudioService>();

      // 检查是否是同一个播放列表
      final isSamePlaylist = audioService.isCurrentPlaylist(_charts);

      // 找到点击歌曲的索引
      final index = _charts.indexWhere((item) => item['id'] == chart['id']);

      if (index != -1) {
        if (isSamePlaylist) {
          // 如果是同一个播放列表，直接跳转到指定歌曲
          await audioService.skipToQueueItem(index);
        } else {
          // 如果是新的播放列表，从指定歌曲开始播放整个列表
          await audioService.playPlaylist(_charts, initialIndex: index);
        }
      }
    } catch (e) {
      print('Error playing track: $e');
    }
  }
}
