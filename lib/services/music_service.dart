import '../utils/http/http_client.dart';
import '../config/api_config.dart';

class MusicService {
  final _client = HttpClient.instance;

  Future<List<dynamic>> getLatestCollections() async {
    try {
      return await _client.get<List<dynamic>>(ApiConfig.latestCollection);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTopCharts() async {
    try {
      return await _client.get(ApiConfig.topCharts);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> searchMusic(String keyword) async {
    try {
      return await _client.get(
        ApiConfig.search,
        queryParameters: {'keyword': keyword},
      );
    } catch (e) {
      rethrow;
    }
  }
}
