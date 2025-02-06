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

  Future<Map<String, dynamic>> getHomeData() async {
    try {
      return await _client.get<Map<String, dynamic>>(ApiConfig.home);
    } catch (e) {
      rethrow;
    }
  }
}
