import 'package:get/get.dart';
import 'package:live_activities/live_activities.dart';

class LiveActivitiesService extends GetxService {
  static LiveActivitiesService get to => Get.find<LiveActivitiesService>();

  final _liveActivities = LiveActivities();

  Future<void> startMusicActivity({
    required String title,
    required String artist,
    required String coverUrl,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'title': title,
        'artist': artist,
        'coverUrl': coverUrl,
        'isPlaying': true,
      };

      await _liveActivities.createActivity(params);
    } catch (e) {
      print('Error starting music activity: $e');
    }
  }

  Future<void> updateMusicActivity({required bool isPlaying}) async {
    try {
      final Map<String, dynamic> params = {
        'isPlaying': isPlaying,
      };

      await _liveActivities.updateActivity('music', params);
    } catch (e) {
      print('Error updating music activity: $e');
    }
  }

  Future<void> stopMusicActivity() async {
    try {
      await _liveActivities.endActivity('music');
    } catch (e) {
      print('Error stopping music activity: $e');
    }
  }
}
