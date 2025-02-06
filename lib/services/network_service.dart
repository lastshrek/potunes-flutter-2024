import '../utils/http/http_client.dart';
import '../config/api_config.dart';

class NetworkService {
  // 改名为 NetworkService
  final _client = HttpClient.instance;

  Future<List<dynamic>> getLatestCollections() async {
    try {
      final response = await _client.get<List<dynamic>>(ApiConfig.latestCollection);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getLatestFinal() async {
    try {
      final response = await _client.get<List<dynamic>>(ApiConfig.latestFinal);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getHomeData() async {
    try {
      return await _client.get<Map<String, dynamic>>(ApiConfig.home);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPlaylistById(int id) async {
    try {
      return await _client.get<Map<String, dynamic>>(
        '${ApiConfig.playlist}/$id', // 将 ID 添加到路径中
      );
    } catch (e) {
      rethrow;
    }
  }
}
