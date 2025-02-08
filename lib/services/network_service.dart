import '../utils/http/http_client.dart';
import '../config/api_config.dart';
import 'package:dio/dio.dart';
import '../utils/http/api_exception.dart';
import 'package:flutter/foundation.dart';
import '../utils/http/response_handler.dart';
import 'dart:developer' as developer;
import 'dart:convert';

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
        return response['data'] as Map<String, dynamic>;
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
        return response['data'] as Map<String, dynamic>;
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
      final path = ApiConfig.getLyricsPath(id, nId);
      final fullUrl = '${ApiConfig.baseUrl}$path';
      print('=== Fetching Lyrics ===');
      print('Full URL: $fullUrl');
      print('ID: $id');
      print('NID: $nId');

      final response = await _client.get<dynamic>(path);

      print('Lyrics Response: $response');

      if (response is Map && response['statusCode'] == 200) {
        return response['data'] as Map<String, dynamic>;
      }

      throw ApiException(
        statusCode: 500,
        message: '无效的响应格式',
      );
    } catch (e) {
      print('=== Error getting lyrics: $e ===');
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
          // 将数据包装成期望的格式
          return {
            'charts': response['data'],
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
            // 确保所有必要字段都存在
            final processed = {
              'id': item['id'],
              'nId': item['nId'],
              'name': item['name'],
              'artist': item['artist'],
              'album': item['album'],
              'duration': item['duration'],
              'cover_url': item['cover_url'],
              'url': item['url'],
            };

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
}
