import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'live_activities_stub.dart';

class LiveActivitiesService extends GetxService {
  static LiveActivitiesService get to => Get.find<LiveActivitiesService>();

  final _liveActivities = LiveActivities();

  Future<void> startMusicActivity({
    required String title,
    required String artist,
    required String coverUrl,
  }) async {
    if (!Platform.isIOS || kIsWeb) return;

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
    if (!Platform.isIOS || kIsWeb) return;

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
    if (!Platform.isIOS || kIsWeb) return;

    try {
      await _liveActivities.endActivity('music');
    } catch (e) {
      print('Error stopping music activity: $e');
    }
  }
}
