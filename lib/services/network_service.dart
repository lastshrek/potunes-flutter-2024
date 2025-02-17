import '../utils/http/http_client.dart';
import '../config/api_config.dart';
import 'package:dio/dio.dart';
import '../utils/http/api_exception.dart';
import '../services/user_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../utils/error_reporter.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  static const platform = MethodChannel('pink.poche.potunes/network');
  // 改名为 NetworkService
  final _client = HttpClient.instance;
  static const String _networkPermissionKey = 'network_permission_granted';
  static bool _hasNetworkPermission = false;
  static bool get hasNetworkPermission => _hasNetworkPermission;

  static final NetworkService _instance = NetworkService._internal();
  static NetworkService get instance => _instance;

  NetworkService._internal();

  Future<List<dynamic>> getLatestCollections() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(ApiConfig.latestCollection);

      if (response is Map && response['statusCode'] == 200 && response['data'] is List) {
        return response['data'] as List<dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: 'Invalid response format',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<List<dynamic>> getLatestFinal() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(ApiConfig.latestFinal);

      if (response is Map && response['statusCode'] == 200 && response['data'] is List) {
        return response['data'] as List<dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getHomeData() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(ApiConfig.home);

      if (response is Map && response['statusCode'] == 200 && response['data'] is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>;

        // 处理所有可能包含歌曲的列表
        if (data['tracks'] is List) {
          final tracks = (data['tracks'] as List).map((track) {
            if (track is Map<String, dynamic>) {
              return _processTrackData(track);
            }
            return track;
          }).toList();

          data['tracks'] = tracks;
        }

        return data;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e, stackTrace) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPlaylistById(int id) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>('${ApiConfig.playlist}/$id');
      print('getPlaylistById response: $response');

      if (response is Map && response['statusCode'] == 200 && response['data'] is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>;

        // 处理 tracks 数组
        if (data['tracks'] is List) {
          final tracks = (data['tracks'] as List).map((track) {
            if (track is Map<String, dynamic>) {
              return _processTrackData(track);
            }
            return track;
          }).toList();

          data['tracks'] = tracks;
        }

        return data;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLyrics(String id, String nId) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get(
        '${ApiConfig.lyrics}/$id/$nId',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
        ),
      );

      // 检查响应格式并提取数据
      if (response['data'] is Map && response['statusCode'] == 200) {
        final data = response['data'] as Map<String, dynamic>;
        return {
          'lrc': data['lrc'] as String?,
          'lrc_cn': data['lrc_cn'] as String?,
          'isLike': data['isLike'] as int?,
        };
      }

      throw Exception('Invalid response format');
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<dynamic> get(String path) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }

    try {
      final response = await _client.get(
        path,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
        ),
      );

      // 如果响应是 Map 类型
      if (response is Map<String, dynamic>) {
        // 检查状态码
        if (response['statusCode'] == 200) {
          // 如果有 data 字段，返回整个响应
          return response;
        }
        // 如果状态码不是 200，抛出异常
        throw ApiException(
          statusCode: response['statusCode'] ?? 500,
          message: response['message'] ?? '请求失败',
        );
      }

      // 如果响应不是预期的格式，抛出异常
      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e, stackTrace) {
      ErrorReporter.showError(e);
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.post(
        path,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
        ),
      );

      if (response is Map<String, dynamic>) {
        return response;
      } else if (response.data is Map<String, dynamic>) {
        return response.data;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTopCharts() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(ApiConfig.topCharts);

      if (response is Map && response['statusCode'] == 200) {
        if (response['data'] is List) {
          // 处理每个歌曲的数据
          final processedTracks = (response['data'] as List).map((track) {
            if (track is Map<String, dynamic>) {
              return _processTrackData(track);
            }
            return track;
          }).toList();

          // 将处理后的数据包装成期望的格式
          return {
            'charts': processedTracks,
          };
        }
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<List<dynamic>> getAllCollections() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(ApiConfig.allCollections);

      if (response is Map && response['statusCode'] == 200 && response['data'] is List) {
        return response['data'] as List<dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<List<dynamic>> getAllFinals() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(ApiConfig.allFinals);

      if (response is Map && response['statusCode'] == 200 && response['data'] is List) {
        return response['data'] as List<dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<List<dynamic>> getAllAlbums() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(ApiConfig.allAlbums);

      if (response is Map && response['statusCode'] == 200 && response['data'] is List) {
        return response['data'] as List<dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<void> sendCaptcha(String phone) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.post<dynamic>(
        ApiConfig.captcha,
        data: {
          "phone": phone,
        },
      );

      if (response is Map && (response['statusCode'] == 200 || response['statusCode'] == 201)) {
        ErrorReporter.showSuccess('Verification code sent successfully');
        return;
      }

      throw ApiException(
        statusCode: 500,
        message: response['message'] ?? 'Failed to send verification code',
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 201) {
        ErrorReporter.showSuccess('Verification code sent successfully');
        return;
      }
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyCaptcha(String phone, String captcha) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.post<dynamic>(
        ApiConfig.verifyCaptcha,
        data: {
          "phone": phone,
          "captcha": captcha,
        },
      );

      print('Verify captcha response: $response'); // 打印响应内容

      if (response is Map && (response['statusCode'] == 200 || response['statusCode'] == 201)) {
        return response as Map<String, dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: response['message'] ?? '验证失败',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<List<dynamic>> getFavourites() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(ApiConfig.fav);

      if (response is Map && response['statusCode'] == 200 && response['data'] is List) {
        final List<dynamic> rawFavourites = response['data'];

        // 转换并验证数据
        final List<Map<String, dynamic>> favourites = rawFavourites.map((item) {
          if (item is Map) {
            // 使用 _processTrackData 处理歌曲数据
            final processed = _processTrackData({
              'id': item['id'],
              'nId': item['nId'],
              'name': item['name'],
              'artist': item['artist'],
              'album': item['album'],
              'duration': item['duration'],
              'cover_url': item['cover_url'],
              'url': item['url'],
              'playlist_id': item['playlist_id'],
              'ar': item['ar'],
              'original_album': item['original_album'],
              'original_album_id': item['original_album_id'],
              'mv': item['mv'],
            });

            return processed;
          }
          throw ApiException(
            statusCode: 500,
            message: '歌曲数据格式错误',
          );
        }).toList();

        return favourites;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<bool> likeTrack(Map<String, dynamic> track) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      // 根据 id 确定 type
      final trackType = track['id'] == 0 ? 'netease' : 'potunes';

      // 构建请求体
      final requestBody = {
        'id': track['id'],
        'nId': track['nId'],
        'name': track['name'],
        'artist': track['artist'],
        'album': track['album'],
        'duration': track['duration'],
        'cover_url': track['cover_url'],
        'url': track['url'],
        'type': trackType, // 使用确定的 type
        'playlist_id': track['playlist_id'],
        'ar': track['ar'] ?? [],
        'original_album': track['original_album'] ?? '',
        'original_album_id': track['original_album_id'] ?? 0,
        'mv': track['mv'] ?? 0,
      };

      final response = await _client.post<dynamic>(
        ApiConfig.like,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
          contentType: 'application/json',
        ),
      );

      if (response is Map && response['statusCode'] == 200) {
        return true;
      }
      ErrorReporter.showBusinessError(message: 'Failed to add to favorites');
      return false;
    } catch (e) {
      ErrorReporter.showError(e);
      return false;
    }
  }

  // 添加一个工具方法来处理歌曲数据
  Map<String, dynamic> _processTrackData(Map<String, dynamic> track) {
    return {
      ...track,
      'type': track['id'] == 0 ? 'netease' : 'potunes', // 根据 id 设置不同的 type
      'ar': track['ar'] ?? [],
      'original_album': track['original_album'] ?? '',
      'original_album_id': track['original_album_id'] ?? 0,
      'mv': track['mv'] ?? 0,
    };
  }

  // 添加获取 toplist 详情的方法
  Future<Map<String, dynamic>> getTopListDetail(int id) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get(
        '${ApiConfig.baseUrl}${ApiConfig.topListDetail}/$id',
      );
      if (response is Map<String, dynamic> && response['statusCode'] == 200) {
        final data = response['data'] as Map<String, dynamic>;

        // 如果存在 tracks 数组，为每个 track 添加 type 字段
        if (data['tracks'] is List) {
          final List<dynamic> tracks = data['tracks'] as List<dynamic>;
          final List<Map<String, dynamic>> processedTracks = tracks.map((track) {
            if (track is Map<String, dynamic>) {
              return {
                ...track,
                'type': 'netease', // 添加 type 字段
              };
            }
            return track as Map<String, dynamic>;
          }).toList();

          // 更新 data 中的 tracks
          data['tracks'] = processedTracks;
        }

        return data;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getNewAlbumDetail(int id) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get(
        '${ApiConfig.baseUrl}${ApiConfig.neteaseNewAlbumDetail}/$id',
      );

      if (response is Map<String, dynamic> && response['statusCode'] == 200) {
        final data = response['data'] as Map<String, dynamic>;

        // 处理 tracks 数组
        if (data['tracks'] is List) {
          final List<dynamic> tracks = data['tracks'] as List<dynamic>;
          final List<Map<String, dynamic>> processedTracks = tracks.map((track) {
            if (track is Map<String, dynamic>) {
              return {
                ...track,
                'type': 'netease',
              };
            }
            return track as Map<String, dynamic>;
          }).toList();

          // 更新 data 中的 tracks
          data['tracks'] = processedTracks;
        }

        return data;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  // 修改网络权限检查方法
  Future<bool> checkNetworkPermission() async {
    try {
      // 如果是 Android，直接返回 true
      if (Platform.isAndroid) {
        _hasNetworkPermission = true;
        Get.find<AppController>().updateNetworkStatus(true);
        return true;
      }

      // iOS 平台的权限检查逻辑
      if (Platform.isIOS) {
        // 先从本地存储读取权限状态
        final prefs = await SharedPreferences.getInstance();
        final hasStoredPermission = prefs.getBool(_networkPermissionKey) ?? false;

        if (hasStoredPermission) {
          _hasNetworkPermission = true;
          return true;
        }

        // 如果本地没有权限记录，检查网络连接
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult == ConnectivityResult.none) {
          ErrorReporter.showNetworkError();
          throw ApiException(
            statusCode: -1,
            message: 'Please check your network connection',
          );
        }

        // 尝试发起测试请求
        try {
          await _client.get(ApiConfig.home);
          // 如果请求成功，保存权限状态并通知所有监听者
          _hasNetworkPermission = true;
          await prefs.setBool(_networkPermissionKey, true);
          // 发送网络状态变更通知
          Get.find<AppController>().updateNetworkStatus(true);
          return true;
        } catch (e) {
          if (e is DioException && (e.type == DioExceptionType.connectionError || e.error.toString().contains('network'))) {
            ErrorReporter.showPermissionError(
              message: 'Network permission is required to use the app',
            );
            throw ApiException(
              statusCode: -2,
              message: 'Network permission required',
            );
          }
          ErrorReporter.showError(e);
          rethrow;
        }
      }

      // 其他平台直接返回 true
      _hasNetworkPermission = true;
      Get.find<AppController>().updateNetworkStatus(true);
      return true;
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  // 添加重置权限状态的方法
  Future<void> resetNetworkPermission() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_networkPermissionKey);
    _hasNetworkPermission = false;
  }

  Future<bool> checkLikeStatus(Map<String, dynamic> track) async {
    try {
      final response = await get('/like/check/${track['id']}');
      return response['isLiked'] == true;
    } catch (e) {
      ErrorReporter.showError(e);
      return false;
    }
  }

  Future<bool> updateTrackPlayCount(Map<String, dynamic> track) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      // 获取当前日期，格式化为 yyyy-MM-dd
      final now = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 构建请求体
      final requestBody = {
        'id': track['id'],
        'nId': track['nId'],
        'name': track['name'],
        'artist': track['artist'],
        'album': track['album'],
        'duration': track['duration'],
        'cover_url': track['cover_url'],
        'url': track['url'],
        'type': track['id'] == 0 ? 'netease' : 'potunes',
        'playlist_id': track['playlist_id'],
        'ar': track['ar'] ?? [],
        'original_album': track['original_album'] ?? '',
        'original_album_id': track['original_album_id'] ?? 0,
        'mv': track['mv'] ?? 0,
        'date': date, // 添加日期字段
      };
      final response = await _client.post<dynamic>(
        ApiConfig.updatePlayCount,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
          contentType: 'application/json',
        ),
      );

      if (response is Map && response['statusCode'] == 200) {
        return true;
      }
      return false;
    } catch (e) {
      ErrorReporter.showError(e);
      return false;
    }
  }

  Future<bool> updateAvatar(String base64Image) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.patch(
        ApiConfig.updateAvatar,
        data: {
          'avatar': base64Image,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
          contentType: 'application/json',
        ),
      );

      if (response is Map && response['statusCode'] == 200) {
        ErrorReporter.showSuccess('Avatar updated successfully');
        return true;
      }
      ErrorReporter.showBusinessError(message: 'Failed to update avatar');
      return false;
    } catch (e) {
      ErrorReporter.showError(e);
      return false;
    }
  }

  Future<bool> updateProfile({
    String? nickname,
    String? intro,
    String? gender,
  }) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.patch(
        ApiConfig.updateProfile,
        data: {
          if (nickname != null) 'nickname': nickname,
          if (intro != null) 'intro': intro,
          if (gender != null) 'gender': gender,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
          contentType: 'application/json',
        ),
      );

      if (response is Map && response['statusCode'] == 200) {
        return true;
      }
      return false;
    } catch (e) {
      ErrorReporter.showError(e);
      return false;
    }
  }

  Future<Map<String, dynamic>> getRadioTrack() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(ApiConfig.radio);

      if (response is Map && response['statusCode'] == 200 && response['data'] is Map<String, dynamic>) {
        final track = response['data'] as Map<String, dynamic>;
        return _processTrackData(track);
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPlaylist(String title) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.post<dynamic>(
        ApiConfig.userPlaylistAdd,
        data: {
          "title": title,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
          contentType: 'application/json',
        ),
      );

      if (response is Map && (response['statusCode'] == 200 || response['statusCode'] == 201)) {
        return response['data'] as Map<String, dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: response['message'] ?? '创建歌单失败',
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 201) {
        return (e.response?.data['data'] as Map<String, dynamic>?) ?? {};
      }
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserPlaylists() async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(
        ApiConfig.userPlaylist,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
        ),
      );

      if (response is Map && response['statusCode'] == 200 && response['data'] is List) {
        final List<dynamic> rawPlaylists = response['data'];
        return rawPlaylists.map((item) => item as Map<String, dynamic>).toList();
      }

      throw ApiException(
        statusCode: 500,
        message: '获取歌单失败',
      );
    } catch (e) {
      if (kDebugMode) {
        print('getUserPlaylists error: $e');
      }
      ErrorReporter.showError(e);
      rethrow;
    }
  }

  Future<bool> addTrackToPlaylist(int playlistId, Map<String, dynamic> track) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      if (kDebugMode) {
        print('addTrackToPlaylist request data: $track');
      }

      final response = await _client.post<dynamic>(
        ApiConfig.userPlaylistAddTrack.replaceAll(':id', playlistId.toString()),
        data: track,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
          contentType: 'application/json',
        ),
      );

      // 成功时返回的是正常的 statusCode
      if (response is Map && (response['statusCode'] == 200 || response['statusCode'] == 201)) {
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('addTrackToPlaylist error: $e');
        if (e is DioException) {
          print('DioException response data: ${e.response?.data}');
          // 错误时返回的是 code 和 message
          final responseData = e.response?.data;
          if (responseData is Map) {
            print('Error code: ${responseData['code']}');
            print('Error message: ${responseData['message']}');
          }
        }
      }
      if (e is DioException && e.response?.data != null) {
        final responseData = e.response?.data;
        if (responseData is Map) {
          final message = responseData['message'] ?? '添加失败';
          ErrorReporter.showBusinessError(message: message);
          return false;
        }
      }
      ErrorReporter.showError(e);
      return false;
    }
  }

  Future<Map<String, dynamic>> getPlaylistDetail(int playlistId) async {
    if (!_hasNetworkPermission) {
      await checkNetworkPermission();
    }
    try {
      final response = await _client.get<dynamic>(
        '${ApiConfig.userPlaylistDetail}/$playlistId',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
        ),
      );
      if (kDebugMode) {
        print('getPlaylistDetail response: $response');
      }
      if (response is Map && response['statusCode'] == 200 && response['data'] is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: '获取歌单详情失败',
      );
    } catch (e) {
      ErrorReporter.showError(e);
      rethrow;
    }
  }
}
