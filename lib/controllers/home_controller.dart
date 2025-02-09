import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/network_service.dart';
import '../config/api_config.dart';
import 'package:flutter/material.dart';
import '../utils/http/api_exception.dart';
import '../controllers/base_controller.dart';

class HomeController extends BaseController {
  final NetworkService _networkService = NetworkService.instance;
  final _collections = <Map<String, dynamic>>[].obs;
  final _finals = <Map<String, dynamic>>[].obs;
  final _albums = <Map<String, dynamic>>[].obs;
  final _neteaseToplist = <Map<String, dynamic>>[].obs;
  final _isRefreshing = false.obs;
  final RxList<Map<String, dynamic>> _neteaseNewAlbums = <Map<String, dynamic>>[].obs;

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
  bool get isRefreshing => _isRefreshing.value;

  @override
  void onInit() {
    super.onInit();
    print('HomeController onInit called');
    loadCachedData();
  }

  @override
  void onReady() {
    super.onReady();
    print('HomeController onReady called');
    // 总是刷新数据，不管缓存是否存在
    refreshData();
  }

  @override
  void onNetworkReady() {
    print('HomeController network ready, refreshing data...');
    refreshData();
  }

  @override
  Future<void> refreshData() async {
    if (!isNetworkReady) {
      print('Network not ready, skipping refresh');
      return;
    }

    print('Starting data refresh...');
    try {
      _isRefreshing.value = true;

      // 获取主页数据
      final response = await _networkService.getHomeData();
      print('Home data response: $response');

      if (response != null) {
        if (response['collections'] != null) {
          _collections.assignAll(List<Map<String, dynamic>>.from(response['collections']));
          print('Updated collections: ${_collections.length}');
        }

        if (response['finals'] != null) {
          _finals.assignAll(List<Map<String, dynamic>>.from(response['finals']));
          print('Updated finals: ${_finals.length}');
        }

        if (response['albums'] != null) {
          _albums.assignAll(List<Map<String, dynamic>>.from(response['albums']));
          print('Updated albums: ${_albums.length}');
        }

        if (response['netease_toplist'] != null) {
          _neteaseToplist.assignAll(List<Map<String, dynamic>>.from(response['netease_toplist']));
          print('Updated netease toplist: ${_neteaseToplist.length}');
        }
      } else {
        print('Home data response is null');
      }

      // 获取网易云新专辑数据
      await _fetchNeteaseNewAlbums();

      await _saveToCache();
      print('Data refresh complete');
    } catch (e, stackTrace) {
      print('Error refreshing data: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _isRefreshing.value = false;
    }
  }

  @override
  Future<void> loadCachedData() async {
    print('Loading cached data...');
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载收藏
      final cachedCollections = prefs.getString(_collectionsKey);
      if (cachedCollections != null) {
        final List<dynamic> decoded = jsonDecode(cachedCollections);
        _collections.assignAll(decoded.map((item) => Map<String, dynamic>.from(item)).toList());
        print('Loaded ${_collections.length} collections from cache');
      }

      // 加载最终版
      final cachedFinals = prefs.getString(_finalsKey);
      if (cachedFinals != null) {
        final List<dynamic> decoded = jsonDecode(cachedFinals);
        _finals.assignAll(decoded.map((item) => Map<String, dynamic>.from(item)).toList());
        print('Loaded ${_finals.length} finals from cache');
      }

      // 加载专辑
      final cachedAlbums = prefs.getString(_albumsKey);
      if (cachedAlbums != null) {
        final List<dynamic> decoded = jsonDecode(cachedAlbums);
        _albums.assignAll(decoded.map((item) => Map<String, dynamic>.from(item)).toList());
        print('Loaded ${_albums.length} albums from cache');
      }

      // 加载网易云排行榜
      final cachedNetease = prefs.getString(_neteaseKey);
      if (cachedNetease != null) {
        final List<dynamic> decoded = jsonDecode(cachedNetease);
        _neteaseToplist.assignAll(decoded.map((item) => Map<String, dynamic>.from(item)).toList());
        print('Loaded ${_neteaseToplist.length} netease items from cache');
      }

      print('Cache load complete');
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  Future<void> _fetchNeteaseNewAlbums() async {
    try {
      print('Fetching netease new albums...');
      final neteaseNewAlbumsResponse = await _networkService.get(ApiConfig.neteaseNewAlbum);
      print('New albums raw response: $neteaseNewAlbumsResponse');

      if (neteaseNewAlbumsResponse != null && neteaseNewAlbumsResponse is Map<String, dynamic> && neteaseNewAlbumsResponse['data'] != null) {
        final rawAlbums = neteaseNewAlbumsResponse['data'] is List ? neteaseNewAlbumsResponse['data'] as List : neteaseNewAlbumsResponse['data']['albums'] as List;

        print('Raw albums data: $rawAlbums');

        final mappedAlbums = rawAlbums.map((album) {
          if (album is Map<String, dynamic>) {
            return {
              'id': album['id'] ?? 0,
              'nId': album['id'] ?? 0,
              'cover': album['picUrl'] ?? '',
              'title': album['name'] ?? '',
              'artist': (album['artist'] != null) ? album['artist']['name'] ?? '' : (album['artists'] as List?)?.map((artist) => artist['name'] as String)?.join(' / ') ?? '',
            };
          }
          return <String, dynamic>{};
        }).toList();

        _neteaseNewAlbums.assignAll(mappedAlbums);
        print('Updated new albums: ${_neteaseNewAlbums.length}');
      }
    } catch (e, stackTrace) {
      print('Error loading new albums: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_collectionsKey, jsonEncode(_collections));
      await prefs.setString(_finalsKey, jsonEncode(_finals));
      await prefs.setString(_albumsKey, jsonEncode(_albums));
      await prefs.setString(_neteaseKey, jsonEncode(_neteaseToplist));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);

      print('Data saved to cache');
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }
}
