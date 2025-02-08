import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/network_service.dart';
import '../services/audio_service.dart';

class TopChartsController extends GetxController {
  final NetworkService _networkService = NetworkService();
  final AudioService _audioService = Get.find<AudioService>();
  final _charts = <Map<String, dynamic>>[].obs;
  final _isInitialLoading = true.obs;
  final _isRefreshing = false.obs;
  final _error = Rxn<String>();

  static const String _chartsKey = 'top_charts_data';
  static const String _lastUpdateKey = 'top_charts_last_update';

  List<Map<String, dynamic>> get charts => _charts;
  bool get isInitialLoading => _isInitialLoading.value;
  bool get isRefreshing => _isRefreshing.value;
  bool get isLoading => _isInitialLoading.value || _isRefreshing.value;
  Rxn<String> get error => _error;

  @override
  void onInit() {
    super.onInit();
    _loadCachedData();
  }

  // 加载缓存的数据
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_chartsKey);
      final lastUpdate = prefs.getInt(_lastUpdateKey);

      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        _charts.value = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        _isInitialLoading.value = false;

        // 如果数据超过1小时，自动刷新
        final now = DateTime.now().millisecondsSinceEpoch;
        if (lastUpdate == null || now - lastUpdate > const Duration(hours: 1).inMilliseconds) {
          await refreshData();
        }
      } else {
        await refreshData();
      }
    } catch (e) {
      print('Error loading cached data: $e');
      await refreshData();
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

  // 刷新数据
  Future<void> refreshData() async {
    try {
      _isRefreshing.value = true;
      _error.value = null;
      final response = await _networkService.getTopCharts();

      if (response['charts'] is List) {
        final chartsList = response['charts'] as List;
        final newCharts = chartsList.map((item) => item as Map<String, dynamic>).toList();
        _charts.value = newCharts;
        await _saveToCache(newCharts);
      } else {
        _error.value = 'Invalid data format';
      }
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _isRefreshing.value = false;
      _isInitialLoading.value = false;
    }
  }

  void openChart(Map<String, dynamic> chart) async {
    try {
      _audioService.currentPlaylist = _charts.toList();

      final index = _charts.indexWhere((item) => item['id'] == chart['id']);
      if (index != -1) {
        await _audioService.playTrack(chart);
      }
    } catch (e) {
      print('Error playing track: $e');
    }
  }
}
