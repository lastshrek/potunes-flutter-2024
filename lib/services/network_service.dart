import '../utils/http/http_client.dart';
import '../config/api_config.dart';
import 'package:dio/dio.dart';
import '../utils/http/api_exception.dart';
import '../services/user_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class NetworkService {
  static const platform = MethodChannel('com.potunes.app/network');
  // 改名为 NetworkService
  final _client = HttpClient.instance;
  bool _hasCheckedPermission = false;

  Future<List<dynamic>> getLatestCollections() async {
    try {
      final response = await _client.get<dynamic>(ApiConfig.latestCollection);

      if (response is Map && response['statusCode'] == 200 && response['data'] is List) {
        return response['data'] as List<dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      print('=== Error getting collections: $e ===');
      rethrow;
    }
  }

  Future<List<dynamic>> getLatestFinal() async {
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
      print('=== Error getting final: $e ===');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getHomeData() async {
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
    } catch (e) {
      print('=== Error getting home data: $e ===');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPlaylistById(int id) async {
    try {
      final response = await _client.get<dynamic>('${ApiConfig.playlist}/$id');

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
      print('=== Error getting playlist: $e ===');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLyrics(String id, String nId) async {
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
      print('Error getting lyrics: $e');
      rethrow;
    }
  }

  Future<dynamic> get(String path) async {
    try {
      await checkNetworkPermission();
      print('Making GET request to: ${ApiConfig.baseUrl}$path'); // 添加请求日志

      final response = await _client.get(
        path,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${UserService.to.token}',
          },
        ),
      );

      print('Response received: $response'); // 添加响应日志

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
      print('Error in GET request: $e'); // 添加错误日志
      rethrow;
    }
  }

  void _handleError(dynamic error) {
    if (error is DioException) {
      throw ApiException.fromDioError(error);
    } else if (error is ApiException) {
      throw error;
    } else {
      throw ApiException(
        statusCode: 500,
        message: error.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> getTopCharts() async {
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
      print('=== Error getting top charts: $e ===');
      rethrow;
    }
  }

  Future<List<dynamic>> getAllCollections() async {
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
      print('=== Error getting all collections: $e ===');
      rethrow;
    }
  }

  Future<List<dynamic>> getAllFinals() async {
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
      print('=== Error getting all finals: $e ===');
      rethrow;
    }
  }

  Future<List<dynamic>> getAllAlbums() async {
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
      print('=== Error getting all albums: $e ===');
      rethrow;
    }
  }

  Future<void> sendCaptcha(String phone) async {
    try {
      final response = await _client.post<dynamic>(
        ApiConfig.captcha,
        data: {
          "phone": phone,
        },
      );

      if (response is Map && (response['statusCode'] == 200 || response['statusCode'] == 201)) {
        return;
      }

      throw ApiException(
        statusCode: 500,
        message: response['message'] ?? '发送验证码失败',
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 201) {
        return;
      }
      print('=== Error sending captcha: $e ===');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyCaptcha(String phone, String captcha) async {
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
      print('=== Error verifying captcha: $e ===');
      rethrow;
    }
  }

  Future<List<dynamic>> getFavourites() async {
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

            print('Processed favourite item: $processed');
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
      print('=== Error getting favourites: $e ===');
      rethrow;
    }
  }

  Future<bool> likeTrack(Map<String, dynamic> track) async {
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

      print('Request body: $requestBody');

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

      print('Like track response: $response');

      if (response is Map && response['statusCode'] == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('Error liking track: $e');
      print('Error details: ${e.toString()}');
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
    try {
      final response = await _client.get(
        '${ApiConfig.baseUrl}${ApiConfig.topListDetail}/$id',
      );
      print('netease top list detail: ${ApiConfig.baseUrl}${ApiConfig.topListDetail}/$id');
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
      print('Error getting toplist detail: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getNewAlbumDetail(int id) async {
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
      rethrow;
    }
  }

  // 修改网络状态检查方法
  Future<bool> checkNetworkPermission() async {
    if (_hasCheckedPermission) return true;

    try {
      if (Platform.isIOS) {
        // 尝试发起一个测试请求
        try {
          await _client.get(ApiConfig.home);
          _hasCheckedPermission = true;
          return true;
        } catch (e) {
          // 如果请求失败，可能是因为需要网络权限
          throw const ApiException(
            statusCode: -1,
            message: '需要网络权限才能使用应用',
          );
        }
      }
      _hasCheckedPermission = true;
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
