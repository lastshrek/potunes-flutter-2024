import '../utils/http/http_client.dart';
import '../config/api_config.dart';
import 'package:dio/dio.dart';
import '../utils/http/api_exception.dart';
import 'package:flutter/foundation.dart';
import '../utils/http/response_handler.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import '../services/user_service.dart';

class NetworkService {
  // 改名为 NetworkService
  final _client = HttpClient.instance;

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
      print('=== Getting home data ===');
      final response = await _client.get<dynamic>(ApiConfig.home);
      print('=== Home data response: $response ===');

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

          // 打印第一首歌的 type
          if (tracks.isNotEmpty && tracks[0] is Map<String, dynamic>) {
            print('=== First Track Type ===');
            print('Track: ${tracks[0]}');
            print('Type: ${tracks[0]['type']}');
          }
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
      if (response.data is Map && response.data['statusCode'] == 200) {
        final data = response.data['data'];
        if (data is Map) {
          final result = {
            'lrc': data['lrc'],
            'lrc_cn': data['lrc_cn'],
            'isLike': data['isLike'],
          };
          return result;
        }
      }
      throw Exception('Invalid response format');
    } catch (e) {
      rethrow;
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      debugPrint('Making GET request to: ${ApiConfig.baseUrl}$path');
      debugPrint('Query parameters: $queryParameters');
      debugPrint('Expected return type: $T');

      final Response response = await _client.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');
      debugPrint('Response data type: ${response.data.runtimeType}');

      // 处理不同的响应类型
      if (T == Map<String, dynamic>) {
        debugPrint('Expecting Map<String, dynamic>');
        if (response.data is Map<String, dynamic>) {
          debugPrint('Response data is Map<String, dynamic>');
          return response.data as T;
        }
        debugPrint('Response data is not Map<String, dynamic>');
        // 尝试转换
        if (response.data is Map) {
          debugPrint('Attempting to convert Map to Map<String, dynamic>');
          final Map<String, dynamic> convertedData = Map<String, dynamic>.from(response.data);
          return convertedData as T;
        }
        throw ApiException(
          statusCode: response.statusCode ?? 500,
          message: 'Response type mismatch: expected Map<String, dynamic>, got ${response.data.runtimeType}',
        );
      }

      if (T == List<dynamic>) {
        debugPrint('Expecting List<dynamic>');
        if (response.data is List<dynamic>) {
          debugPrint('Response data is List<dynamic>');
          return response.data as T;
        }
        debugPrint('Response data is not List<dynamic>');
        throw ApiException(
          statusCode: response.statusCode ?? 500,
          message: 'Response type mismatch: expected List<dynamic>, got ${response.data.runtimeType}',
        );
      }

      debugPrint('Attempting direct type cast to $T');
      return response.data as T;
    } catch (e) {
      debugPrint('Error in GET request: $e');
      debugPrint('Error type: ${e.runtimeType}');
      if (e is TypeError) {
        debugPrint('Type error details: ${e.toString()}');
      }
      _handleError(e);
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

      print('=== Favourites Response ===');
      print('Full Response: $response');

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
      print('=== Like Track Request ===');
      print('Track data: $track');

      // 根据 id 确定 type
      final trackType = track['id'] == 0 ? 'netease' : 'potunes';
      print('Track type determined: $trackType');

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
}
