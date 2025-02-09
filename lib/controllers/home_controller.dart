import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/network_service.dart';
import '../config/api_config.dart';
import 'package:flutter/material.dart';
import '../utils/http/api_exception.dart';

class HomeController extends GetxController {
  final NetworkService _networkService = NetworkService();
  final _collections = <Map<String, dynamic>>[].obs;
  final _finals = <Map<String, dynamic>>[].obs;
  final _albums = <Map<String, dynamic>>[].obs;
  final _neteaseToplist = <Map<String, dynamic>>[].obs;
  final _isInitialLoading = true.obs;
  final _isRefreshing = false.obs;
  final _error = Rxn<String>();
  final RxList<Map<String, dynamic>> _neteaseNewAlbums = <Map<String, dynamic>>[].obs;
  final _isNetworkReady = false.obs;

  static const String _collectionsKey = 'home_collections_data';
  static const String _finalsKey = 'home_finals_data';
  static const String _albumsKey = 'home_albums_data';
  static const String _neteaseKey = 'home_netease_data';
  static const String _lastUpdateKey = 'home_last_update';

  List<Map<String, dynamic>> get collections => _collections;
  List<Map<String, dynamic>> get finals => _finals;
  List<Map<String, dynamic>> get albums => _albums;
  List<Map<String, dynamic>> get neteaseToplist => _neteaseToplist;
  List<Map<String, dynamic>> get neteaseNewAlbums => _neteaseNewAlbums;
  bool get isInitialLoading => _isInitialLoading.value;
  bool get isRefreshing => _isRefreshing.value;
  bool get isLoading => _isInitialLoading.value || _isRefreshing.value;
  Rxn<String> get error => _error;
  bool get isNetworkReady => _isNetworkReady.value;

  @override
  void onInit() {
    super.onInit();
    _checkNetworkAndInit();
  }

  Future<void> _checkNetworkAndInit() async {
    try {
      await _networkService.checkNetworkPermission();
      _isNetworkReady.value = true;
      await _initData();
    } catch (e) {
      _error.value = e is ApiException ? e.message : e.toString();
      Get.snackbar(
        '网络错误',
        _error.value ?? '未知错误',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // 添加重试按钮
      Future.delayed(const Duration(seconds: 2), () {
        _checkNetworkAndInit();
      });
    }
  }

  Future<void> _initData() async {
    try {
      await refreshData();
    } catch (e) {
      _error.value = e.toString();
    }
  }

  // 加载缓存的数据
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCollections = prefs.getString(_collectionsKey);
      final cachedFinals = prefs.getString(_finalsKey);
      final cachedAlbums = prefs.getString(_albumsKey);
      final cachedNetease = prefs.getString(_neteaseKey);
      final lastUpdate = prefs.getInt(_lastUpdateKey);

      if (cachedCollections != null && cachedFinals != null && cachedAlbums != null && cachedNetease != null) {
        _collections.value = List<Map<String, dynamic>>.from(jsonDecode(cachedCollections).map((x) => Map<String, dynamic>.from(x)));
        _finals.value = List<Map<String, dynamic>>.from(jsonDecode(cachedFinals).map((x) => Map<String, dynamic>.from(x)));
        _albums.value = List<Map<String, dynamic>>.from(jsonDecode(cachedAlbums).map((x) => Map<String, dynamic>.from(x)));
        _neteaseToplist.value = List<Map<String, dynamic>>.from(jsonDecode(cachedNetease).map((x) => Map<String, dynamic>.from(x)));
        _isInitialLoading.value = false;
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
      await prefs.setString(_albumsKey, jsonEncode(_albums));
      await prefs.setString(_neteaseKey, jsonEncode(_neteaseToplist));
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

      // 获取主页数据
      final response = await _networkService.getHomeData();
      _collections.value = List<Map<String, dynamic>>.from(response['collections'] ?? []);
      _finals.value = List<Map<String, dynamic>>.from(response['finals'] ?? []);
      _albums.value = List<Map<String, dynamic>>.from(response['albums'] ?? []);
      _neteaseToplist.value = List<Map<String, dynamic>>.from(response['netease_toplist'] ?? []);

      // 获取网易云新专辑数据
      final neteaseNewAlbumsResponse = await _networkService.get(ApiConfig.neteaseNewAlbum);
      if (neteaseNewAlbumsResponse is Map && neteaseNewAlbumsResponse['statusCode'] == 200 && neteaseNewAlbumsResponse['data'] is List) {
        final rawAlbums = neteaseNewAlbumsResponse['data'] as List;
        _neteaseNewAlbums.value = rawAlbums.map((album) {
          if (album is Map<String, dynamic>) {
            return {
              'id': album['id'] ?? 0,
              'nId': album['id'] ?? 0,
              'cover': album['picUrl'] ?? '',
              'title': album['name'] ?? '',
              'artist': (album['artists'] as List?)?.map((artist) => artist['name'] as String)?.join(' / ') ?? '',
            };
          }
          return <String, dynamic>{};
        }).toList();
      }

      await _saveToCache();
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _isRefreshing.value = false;
      _isInitialLoading.value = false;
    }
  }

  // 添加重试方法
  Future<void> retryConnection() async {
    _isNetworkReady.value = false;
    await _checkNetworkAndInit();
  }
}
