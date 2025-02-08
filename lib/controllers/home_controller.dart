import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/network_service.dart';

class HomeController extends GetxController {
  final NetworkService _networkService = NetworkService();
  final _collections = <Map<String, dynamic>>[].obs;
  final _finals = <Map<String, dynamic>>[].obs;
  final _albums = <Map<String, dynamic>>[].obs;
  final _neteaseToplist = <Map<String, dynamic>>[].obs;
  final _isInitialLoading = true.obs;
  final _isRefreshing = false.obs;
  final _error = Rxn<String>();

  static const String _collectionsKey = 'home_collections_data';
  static const String _finalsKey = 'home_finals_data';
  static const String _lastUpdateKey = 'home_last_update';

  List<Map<String, dynamic>> get collections => _collections;
  List<Map<String, dynamic>> get finals => _finals;
  List<Map<String, dynamic>> get albums => _albums;
  List<Map<String, dynamic>> get neteaseToplist => _neteaseToplist;
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
      final cachedCollections = prefs.getString(_collectionsKey);
      final cachedFinals = prefs.getString(_finalsKey);
      final lastUpdate = prefs.getInt(_lastUpdateKey);

      if (cachedCollections != null && cachedFinals != null) {
        _collections.value = List<Map<String, dynamic>>.from(jsonDecode(cachedCollections).map((x) => Map<String, dynamic>.from(x)));
        _finals.value = List<Map<String, dynamic>>.from(jsonDecode(cachedFinals).map((x) => Map<String, dynamic>.from(x)));
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
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_collectionsKey, jsonEncode(_collections));
      await prefs.setString(_finalsKey, jsonEncode(_finals));
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

      final response = await _networkService.getHomeData();

      if (response != null) {
        _collections.value = List<Map<String, dynamic>>.from(response['collections'] ?? []);
        _finals.value = List<Map<String, dynamic>>.from(response['finals'] ?? []);
        _albums.value = List<Map<String, dynamic>>.from(response['albums'] ?? []);
        _neteaseToplist.value = List<Map<String, dynamic>>.from(response['netease_toplist'] ?? []);
        await _saveToCache();
      }
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _isRefreshing.value = false;
      _isInitialLoading.value = false;
    }
  }
}
