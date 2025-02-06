import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'dart:async';
import 'package:flutter/services.dart';

class AudioService extends GetxService {
  static AudioService get to => Get.find();
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;
  AudioService._internal();

  // 使用 late 确保只初始化一次
  late final AudioPlayer _audioPlayer = AudioPlayer(
    handleInterruptions: true,
    androidApplyAudioAttributes: true,
    handleAudioSessionActivation: true,
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 10),
        maxBufferDuration: Duration(seconds: 30),
        bufferForPlaybackDuration: Duration(seconds: 2),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 4),
        targetBufferBytes: 8 * 1024 * 1024,
        prioritizeTimeOverSizeThresholds: false,
      ),
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration: Duration(seconds: 10),
      ),
    ),
  );

  final _currentTrack = Rx<Map<String, dynamic>?>(null);
  final _playlist = RxList<Map<String, dynamic>>([]);
  final _isPlaying = false.obs;
  final _currentIndex = 0.obs;

  AudioPlayer get player => _audioPlayer;
  Map<String, dynamic>? get currentTrack => _currentTrack.value;
  List<Map<String, dynamic>> get playlist => _playlist;
  bool get isPlaying => _isPlaying.value;
  int get currentIndex => _currentIndex.value;

  @override
  void onInit() {
    super.onInit();
    _setupPlayerListeners();
  }

  void _setupPlayerListeners() {
    _audioPlayer.playbackEventStream.throttleTime(const Duration(milliseconds: 300)).listen(
      (event) {
        if (event.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero, index: 0);
        } else if (event.processingState == ProcessingState.idle) {
          // 尝试重新加载当前曲目
          final currentTrack = _currentTrack.value;
          if (currentTrack != null) {
            print('Current track URL: ${currentTrack['url']}');
            _retryCurrentTrack();
          }
        }
      },
      onError: (Object e, StackTrace st) {
        print('Error in playbackEventStream: $e');
        _handlePlaybackError(e);
      },
    );

    _audioPlayer.playerStateStream.throttleTime(const Duration(milliseconds: 100)).listen(
      (state) {
        _isPlaying.value = state.playing;
      },
      onError: (Object e, StackTrace st) {
        print('Error in playerStateStream: $e');
      },
    );

    _audioPlayer.currentIndexStream.throttleTime(const Duration(milliseconds: 100)).listen(
      (index) {
        if (index != null && index < _playlist.length) {
          _currentIndex.value = index;
          _currentTrack.value = _playlist[index];
        }
      },
      onError: (Object e, StackTrace st) {
        print('Error in currentIndexStream: $e');
      },
    );
  }

  void _handlePlayerError(PlayerException e) {
    if (e.code == 'failed') {
      // 尝试重新加载当前曲目
      final currentIndex = _currentIndex.value;
      if (currentIndex < _playlist.length) {
        _retryPlayback(currentIndex);
      }
    }
  }

  @override
  void onClose() {
    _audioPlayer.stop();
    super.onClose();
  }

  Future<void> playPlaylist(List<Map<String, dynamic>> tracks, int initialIndex) async {
    try {
      print('Playing playlist:');
      print('Initial track: ${tracks[initialIndex]['name']}');
      print('URL: ${tracks[initialIndex]['url']}');

      await _audioPlayer.stop();

      _playlist.clear();
      _playlist.addAll(tracks);

      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: tracks.map((track) {
          final uri = Uri.parse(track['url'] ?? '');
          return AudioSource.uri(
            uri,
            tag: MediaItem(
              id: track['id'].toString(),
              album: track['album'] ?? '',
              title: track['name'] ?? '',
              artist: track['artist'] ?? '',
              artUri: Uri.parse(track['cover_url'] ?? ''),
            ),
            headers: const {
              'Accept': 'audio/mpeg, audio/mp3, audio/aac, audio/x-m4a, audio/*',
              'Range': 'bytes=0-',
              'User-Agent': 'PoTunes/1.0',
            },
          );
        }).toList(),
      );

      await _audioPlayer.setAudioSource(
        playlist,
        initialIndex: initialIndex,
        preload: true,
        initialPosition: Duration.zero,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setSpeed(1.0);
      await _audioPlayer.setSkipSilenceEnabled(false);
      await _audioPlayer.setLoopMode(LoopMode.all);

      if (!_audioPlayer.playing) {
        await _audioPlayer.play();
      }
    } catch (e) {
      print('Error playing playlist: $e');
      _handlePlaybackError(e);
    }
  }

  void _handlePlaybackError(dynamic error) {
    if (error is PlatformException) {
      print('Platform Exception: ${error.code} - ${error.message}');
      if (error.code == '0' || error.code == 'abort') {
        // 处理连接错误
        _retryWithHttps();
      }
    } else if (error is PlayerException) {
      print('Error code: ${error.code}');
      print('Error message: ${error.message}');
      _handlePlayerError(error);
    } else {
      print('An error occurred: $error');
    }
  }

  Future<void> _retryCurrentTrack() async {
    try {
      final currentTrack = _currentTrack.value;
      if (currentTrack == null) return;

      final index = _currentIndex.value;
      await _audioPlayer.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      // 尝试直接跳转到当前曲目
      await _audioPlayer.seek(Duration.zero, index: index);
      await _audioPlayer.play();
    } catch (e) {
      print('Error retrying current track: $e');
      // 如果简单重试失败，再尝试完整重载
      _retryWithFullReload();
    }
  }

  Future<void> _retryWithFullReload() async {
    try {
      final currentTrack = _currentTrack.value;
      if (currentTrack == null) return;

      final index = _playlist.indexOf(currentTrack);
      if (index != -1) {
        await playPlaylist(_playlist, index);
      }
    } catch (e) {
      print('Error retrying with full reload: $e');
      _retryWithHttps();
    }
  }

  Future<void> _retryWithHttps() async {
    try {
      final currentTrack = _currentTrack.value;
      if (currentTrack != null) {
        final url = currentTrack['url'] as String?;
        print('Retrying with HTTPS. Original URL: $url');
        if (url != null) {
          String newUrl;
          if (url.startsWith('http://')) {
            newUrl = url.replaceFirst('http://', 'https://');
          } else if (url.startsWith('https://')) {
            newUrl = url.replaceFirst('https://', 'http://');
          } else {
            return;
          }
          print('New URL: $newUrl');

          final index = _playlist.indexOf(currentTrack);
          if (index != -1) {
            _playlist[index] = Map<String, dynamic>.from(currentTrack)..['url'] = newUrl;
            await _retryPlayback(index);
          }
        }
      }
    } catch (e) {
      print('Error retrying with HTTPS: $e');
    }
  }

  Future<void> playTrack(Map<String, dynamic> track) async {
    print('Playing track: ${track['name']}');
    print('URL: ${track['url']}');

    final index = _playlist.indexWhere((t) => t['id'] == track['id']);
    if (index != -1) {
      await _audioPlayer.seek(Duration.zero, index: index);
      await _audioPlayer.play();
    }
  }

  Future<void> togglePlay() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> next() async {
    await _audioPlayer.seekToNext();
  }

  Future<void> previous() async {
    await _audioPlayer.seekToPrevious();
  }

  Future<void> _retryPlayback(int index) async {
    try {
      await _audioPlayer.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      await _audioPlayer.seek(Duration.zero, index: index);
      await _audioPlayer.play();
    } catch (e) {
      print('Error retrying playback: $e');
    }
  }
}
