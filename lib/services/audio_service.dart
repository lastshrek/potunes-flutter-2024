import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends GetxService {
  static AudioService get to => Get.find<AudioService>();

  static const String _playlistKey = 'last_playlist';
  static const String _indexKey = 'last_index';

  final AudioPlayer _audioPlayer = AudioPlayer();
  final _currentTrack = Rxn<Map<String, dynamic>>();
  final _currentPlaylist = Rxn<List<Map<String, dynamic>>>();
  final _currentIndex = RxInt(0);
  final _isPlaying = RxBool(false);
  final _position = Rx<Duration>(Duration.zero);
  final _duration = Rx<Duration>(Duration.zero);

  bool get isPlaying => _isPlaying.value;
  Map<String, dynamic>? get currentTrack => _currentTrack.value;
  Duration get position => _position.value;
  Duration get duration => _duration.value;
  AudioPlayer get player => _audioPlayer;

  @override
  void onInit() {
    super.onInit();
    _setupPlayerListeners();
    _loadLastState();
  }

  @override
  void onClose() {
    _audioPlayer.dispose();
    super.onClose();
  }

  Future<void> _setupPlayerListeners() async {
    try {
      // 监听播放状态
      _audioPlayer.playerStateStream.listen((state) {
        _isPlaying.value = state.playing;
      });

      // 监听播放位置
      _audioPlayer.positionStream.listen((position) {
        _position.value = position;
      });

      // 监听音频时长
      _audioPlayer.durationStream.listen((duration) {
        _duration.value = duration ?? Duration.zero;
      });

      // 监听序列结束
      _audioPlayer.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          next();
        }
      });
    } catch (e) {
      debugPrint('Error setting up player listeners: $e');
    }
  }

  Future<void> playPlaylist(List<Map<String, dynamic>> playlist, int index) async {
    try {
      _currentPlaylist.value = playlist;
      _currentIndex.value = index;
      await playTrack(playlist[index]);
      _saveLastState();
    } catch (e) {
      debugPrint('Error playing playlist: $e');
    }
  }

  Future<void> playTrack(Map<String, dynamic> track) async {
    try {
      _currentTrack.value = track;
      final url = track['url'];
      if (url == null) return;

      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: track['id']?.toString() ?? '',
            title: track['name'] ?? '',
            artist: track['artist'] ?? '',
            artUri: Uri.parse(track['cover_url'] ?? ''),
          ),
        ),
      );
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
  }

  Future<void> togglePlay() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Error toggling play: $e');
    }
  }

  Future<void> previous() async {
    try {
      if (_currentPlaylist.value == null || _currentIndex.value <= 0) return;
      _currentIndex.value--;
      await playTrack(_currentPlaylist.value![_currentIndex.value]);
      _saveLastState();
    } catch (e) {
      debugPrint('Error playing previous track: $e');
    }
  }

  Future<void> next() async {
    try {
      if (_currentPlaylist.value == null || _currentIndex.value >= _currentPlaylist.value!.length - 1) return;
      _currentIndex.value++;
      await playTrack(_currentPlaylist.value![_currentIndex.value]);
      _saveLastState();
    } catch (e) {
      debugPrint('Error playing next track: $e');
    }
  }

  Future<void> _saveLastState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentPlaylist.value != null) {
        await prefs.setString(_playlistKey, jsonEncode(_currentPlaylist.value));
        await prefs.setInt(_indexKey, _currentIndex.value);
      }
    } catch (e) {
      debugPrint('Error saving last state: $e');
    }
  }

  Future<void> _loadLastState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistJson = prefs.getString(_playlistKey);
      final index = prefs.getInt(_indexKey);

      if (playlistJson != null && index != null) {
        final playlist = List<Map<String, dynamic>>.from(jsonDecode(playlistJson).map((x) => Map<String, dynamic>.from(x)));
        if (playlist.isNotEmpty && index < playlist.length) {
          await playPlaylist(playlist, index);
        }
      }
    } catch (e) {
      debugPrint('Error loading last state: $e');
    }
  }
}
