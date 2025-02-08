import 'package:get/get.dart';
import '../services/network_service.dart';
import '../services/audio_service.dart';

class TopChartsController extends GetxController {
  final NetworkService _networkService = NetworkService();
  final AudioService _audioService = Get.find<AudioService>();
  final _charts = <Map<String, dynamic>>[].obs;
  final _isLoading = RxBool(true);
  final _error = Rxn<String>();

  List<Map<String, dynamic>> get charts => _charts;
  RxBool get isLoading => _isLoading;
  Rxn<String> get error => _error;

  @override
  void onInit() {
    super.onInit();
    _loadCharts();
  }

  Future<void> _loadCharts() async {
    try {
      _isLoading.value = true;
      _error.value = null;
      final response = await _networkService.getTopCharts();

      if (response['charts'] is List) {
        final chartsList = response['charts'] as List;
        _charts.value = chartsList.map((item) => item as Map<String, dynamic>).toList();
      } else {
        _charts.value = [];
        _error.value = 'Invalid data format';
      }
    } catch (e) {
      _error.value = e.toString();
      _charts.value = [];
    } finally {
      _isLoading.value = false;
    }
  }

  void openChart(Map<String, dynamic> chart) async {
    try {
      // 直接设置当前播放列表
      _audioService.currentPlaylist = _charts.toList();

      // 找到当前歌曲在播放列表中的索引
      final index = _charts.indexWhere((item) => item['id'] == chart['id']);
      if (index != -1) {
        // 播放选中的歌曲
        await _audioService.playTrack(chart);
      }
    } catch (e) {
      print('Error playing track: $e');
    }
  }
}
