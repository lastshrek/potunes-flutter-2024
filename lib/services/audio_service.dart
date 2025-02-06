import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends GetxService {
  static AudioService get to => Get.find<AudioService>();

  static const String _playlistKey = 'last_playlist';
  static const String _currentTrackKey = 'current_track';
  static const String _positionKey = 'last_position';

  // 使用普通构造函数
  AudioService();

  // 使用 late 确保只初始化一次
  late final AudioPlayer _audioPlayer = AudioPlayer();

  final _currentTrack = Rx<Map<String, dynamic>?>(null);
  final _playlist = RxList<Map<String, dynamic>>([]);
  final _isPlaying = false.obs;
  final _currentIndex = 0.obs;
  final _position = Duration.zero.obs;
  final _duration = Duration.zero.obs;

  AudioPlayer get player => _audioPlayer;
  Map<String, dynamic>? get currentTrack => _currentTrack.value;
  List<Map<String, dynamic>> get playlist => _playlist;
  bool get isPlaying => _isPlaying.value;
  int get currentIndex => _currentIndex.value;
  Duration get position => _position.value;
  Duration get duration => _duration.value;

  @override
  void onInit() async {
    super.onInit();
    _setupPlayerListeners();
    await _loadLastPlaybackState();
  }

  void _setupPlayerListeners() {
    // 播放状态监听
    _audioPlayer.playerStateStream.distinct().listen(
      (state) {
        _isPlaying.value = state.playing;
        print('[DEBUG] Playing state: ${state.playing}');
        print('[DEBUG] Processing state: ${state.processingState}');
      },
      onError: (Object e, StackTrace st) {
        print('Error in playerStateStream: $e');
      },
    );

    // 当前索引监听
    _audioPlayer.currentIndexStream.distinct().listen(
      (index) {
        if (index != null && index < _playlist.length) {
          _currentIndex.value = index;
          _currentTrack.value = _playlist[index];
          print('[DEBUG] Current track changed: ${_currentTrack.value?['name']}');
        }
      },
      onError: (Object e, StackTrace st) {
        print('Error in currentIndexStream: $e');
      },
    );

    // 时长监听
    _audioPlayer.durationStream.distinct().listen(
      (duration) {
        if (duration != null) {
          _duration.value = duration;
          print('[DEBUG] Duration updated: ${duration.inSeconds}s');
        }
      },
      onError: (Object e, StackTrace st) {
        print('Error in durationStream: $e');
      },
    );

    // 位置监听
    _audioPlayer.positionStream.throttleTime(const Duration(milliseconds: 200)).listen(
      (position) {
        _position.value = position;
        if (_isPlaying.value) {
          final duration = _duration.value;
          print('[DEBUG] Position: ${position.inSeconds}s / ${duration.inSeconds}s');
          if (duration.inMilliseconds > 0) {
            final progress = position.inMilliseconds / duration.inMilliseconds;
            print('[DEBUG] Progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        }
      },
      onError: (Object e, StackTrace st) {
        print('Error in positionStream: $e');
      },
    );

    // 播放完成监听
    _audioPlayer.playbackEventStream.distinct().listen(
      (event) {
        if (event.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero, index: 0);
          print('[DEBUG] Playback completed');
        } else if (event.processingState == ProcessingState.idle) {
          final currentTrack = _currentTrack.value;
          if (currentTrack != null) {
            print('[DEBUG] Idle state detected, retrying track: ${currentTrack['name']}');
            _retryCurrentTrack();
          }
        }
      },
      onError: (Object e, StackTrace st) {
        print('Error in playbackEventStream: $e');
        _handlePlaybackError(e);
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
  void onClose() async {
    await _savePlaybackState();
    await _audioPlayer.stop();
    super.onClose();
  }

  Future<void> _savePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 保存播放列表
      if (_playlist.isNotEmpty) {
        final playlistJson = jsonEncode(_playlist.toList());
        await prefs.setString(_playlistKey, playlistJson);
      }

      // 保存当前歌曲
      if (_currentTrack.value != null) {
        final trackJson = jsonEncode(_currentTrack.value);
        await prefs.setString(_currentTrackKey, trackJson);

        // 保存播放位置
        final position = _position.value.inMilliseconds;
        await prefs.setInt(_positionKey, position);
      }

      print('[DEBUG] Playback state saved');
    } catch (e) {
      print('Error saving playback state: $e');
    }
  }

  Future<void> _loadLastPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载播放列表
      final playlistJson = prefs.getString(_playlistKey);
      if (playlistJson != null) {
        final List<dynamic> decodedList = jsonDecode(playlistJson);
        final List<Map<String, dynamic>> playlist = decodedList.map((item) => Map<String, dynamic>.from(item)).toList();

        // 加载当前歌曲
        final trackJson = prefs.getString(_currentTrackKey);
        if (trackJson != null) {
          final currentTrack = Map<String, dynamic>.from(jsonDecode(trackJson));
          final position = Duration(milliseconds: prefs.getInt(_positionKey) ?? 0);

          // 先更新状态
          _playlist.clear();
          _playlist.addAll(playlist);
          _currentTrack.value = currentTrack;
          _position.value = position;

          // 恢复播放
          final index = playlist.indexWhere((track) => track['id'] == currentTrack['id']);
          if (index != -1) {
            _currentIndex.value = index;

            try {
              // 创建播放列表
              final audioSource = ConcatenatingAudioSource(
                useLazyPreparation: true,
                shuffleOrder: DefaultShuffleOrder(),
                children: playlist.map((track) {
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
                  );
                }).toList(),
              );

              // 设置音频源
              await _audioPlayer
                  .setAudioSource(
                audioSource,
                initialIndex: index,
                initialPosition: position,
              )
                  .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  print('[DEBUG] Timeout setting audio source');
                  throw TimeoutException('Failed to set audio source');
                },
              );

              // 设置播放器状态
              await _audioPlayer.setVolume(1.0);
              await _audioPlayer.setSpeed(1.0);
              await _audioPlayer.setSkipSilenceEnabled(false);
              await _audioPlayer.setLoopMode(LoopMode.all);

              print('[DEBUG] Last playback state restored');
              print('[DEBUG] Current track: ${currentTrack['name']}');
              print('[DEBUG] Position: ${position.inSeconds}s');
            } catch (e) {
              print('Error restoring playback: $e');
              // 清除存储的状态
              await prefs.remove(_playlistKey);
              await prefs.remove(_currentTrackKey);
              await prefs.remove(_positionKey);

              // 重置状态
              _playlist.clear();
              _currentTrack.value = null;
              _position.value = Duration.zero;
              _currentIndex.value = 0;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading playback state: $e');
    }
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

      // 保存新的播放状态
      await _savePlaybackState();
    } catch (e) {
      print('Error playing playlist: $e');
      _handlePlaybackError(e);
    }
  }

  void _handlePlaybackError(dynamic error) {
    if (error is PlatformException) {
      print('Platform Exception: ${error.code} - ${error.message}');
      if (error.code == '-16044' || error.code == '0' || error.code == 'abort') {
        // 处理 iOS 媒体错误
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
