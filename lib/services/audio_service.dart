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

  // 添加重试计数器
  int _retryCount = 0;
  static const int _maxRetries = 3;

  AudioPlayer get player => _audioPlayer;
  Map<String, dynamic>? get currentTrack => _currentTrack.value;
  List<Map<String, dynamic>> get playlist => _playlist;
  bool get isPlaying => _isPlaying.value;
  int get currentIndex => _currentIndex.value;
  Duration get position => _position.value;
  Duration get duration => _duration.value;

  @override
  void onInit() {
    super.onInit();
    _setupPlayerListeners();
    _loadLastState();
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

    // 修改播放完成监听
    _audioPlayer.playbackEventStream.distinct().listen(
      (event) {
        if (event.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero, index: 0);
          _retryCount = 0;
          print('[DEBUG] Playback completed');
        } else if (event.processingState == ProcessingState.idle) {
          if (_retryCount >= _maxRetries) {
            print('[ERROR] Max retries reached, stopping retry attempts');
            _retryCount = 0;
            return;
          }

          final currentTrack = _currentTrack.value;
          if (currentTrack != null) {
            print('[DEBUG] Idle state detected, retry ${_retryCount + 1}/$_maxRetries');
            _retryCurrentTrack();
          }
        }
      },
      onError: (Object e, StackTrace st) {
        print('[ERROR] Error in playbackEventStream: $e');
        if (_retryCount < _maxRetries) {
          _handlePlaybackError(e);
        } else {
          print('[ERROR] Max retries reached, stopping error handling');
          _retryCount = 0;
        }
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

  Future<void> _loadLastState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistJson = prefs.getString(_playlistKey);
      final currentTrackJson = prefs.getString(_currentTrackKey);
      final lastPosition = prefs.getInt(_positionKey);

      if (playlistJson != null && currentTrackJson != null) {
        final List<dynamic> savedPlaylist = jsonDecode(playlistJson);
        final Map<String, dynamic> savedTrack = jsonDecode(currentTrackJson);

        _playlist.value = savedPlaylist.cast<Map<String, dynamic>>();
        _currentTrack.value = savedTrack;
        _currentIndex.value = _playlist.indexWhere((track) => track['id'] == savedTrack['id']);

        if (lastPosition != null) {
          _position.value = Duration(milliseconds: lastPosition);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading last state: $e');
      }
    }
  }

  Future<void> _setAudioSource({bool autoPlay = true}) async {
    if (_playlist.isEmpty) return;

    try {
      final audioSource = ConcatenatingAudioSource(
        children: _playlist.map((track) {
          return AudioSource.uri(
            Uri.parse(track['url'] ?? ''),
            tag: MediaItem(
              id: '${track['id']}',
              title: track['name'] ?? '',
              artist: track['artist'] ?? '',
              artUri: Uri.parse(track['cover_url'] ?? ''),
            ),
          );
        }).toList(),
      );

      await _audioPlayer.setAudioSource(
        audioSource,
        initialIndex: _currentIndex.value,
        initialPosition: _position.value,
      );

      if (autoPlay) {
        await _audioPlayer.play();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting audio source: $e');
      }
    }
  }

  Future<void> playPlaylist(List<Map<String, dynamic>> tracks, int initialIndex) async {
    try {
      // 验证输入参数
      if (tracks.isEmpty) {
        print('[ERROR] Cannot play empty playlist');
        return;
      }

      if (initialIndex < 0 || initialIndex >= tracks.length) {
        print('[ERROR] Invalid initial index: $initialIndex (playlist length: ${tracks.length})');
        initialIndex = 0;
      }

      print('[DEBUG] Starting playPlaylist with ${tracks.length} tracks');
      print('[DEBUG] Initial track: ${tracks[initialIndex]['name']}');
      print('[DEBUG] URL: ${tracks[initialIndex]['url']}');

      // 停止当前播放
      await _audioPlayer.stop();

      // 更新播放列表
      _playlist.clear();
      _playlist.addAll(tracks);
      _currentIndex.value = initialIndex;
      _currentTrack.value = tracks[initialIndex];

      // 创建音频源
      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: tracks.map((track) {
          final url = track['url'] as String?;
          if (url == null || url.isEmpty) {
            print('[WARNING] Track "${track['name']}" has no URL');
            return AudioSource.uri(
              Uri.parse('https://example.com/dummy.mp3'),
              tag: MediaItem(
                id: 'dummy',
                title: 'Invalid Track',
                artist: 'Unknown',
              ),
            );
          }

          print('[DEBUG] Adding track: ${track['name']} - $url');
          return AudioSource.uri(
            Uri.parse(url),
            tag: MediaItem(
              id: track['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              title: track['name'] ?? '',
              artist: track['artist'] ?? '',
              artUri: Uri.tryParse(track['cover_url'] ?? ''),
            ),
          );
        }).toList(),
      );

      print('[DEBUG] Setting audio source...');
      await _audioPlayer
          .setAudioSource(
        playlist,
        initialIndex: initialIndex,
        initialPosition: Duration.zero,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[ERROR] Timeout setting audio source');
          throw TimeoutException('Failed to set audio source');
        },
      );

      // 设置播放器状态
      print('[DEBUG] Configuring player...');
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setSpeed(1.0);
      await _audioPlayer.setSkipSilenceEnabled(false);
      await _audioPlayer.setLoopMode(LoopMode.all);

      // 开始播放
      print('[DEBUG] Starting playback...');
      await _audioPlayer.play();

      // 保存状态
      await _savePlaybackState();
      print('[DEBUG] Playback started successfully');
    } catch (e) {
      print('[ERROR] Error playing playlist: $e');
      if (e is TimeoutException) {
        print('[ERROR] Playback timeout - retrying...');
        _retryCurrentTrack();
      } else if (e is PlayerException) {
        print('[ERROR] Player error code: ${e.code}');
        print('[ERROR] Player error message: ${e.message}');
        _handlePlaybackError(e);
      } else {
        print('[ERROR] Unknown error: $e');
        _handlePlaybackError(e);
      }
    }
  }

  void _handlePlaybackError(dynamic error) {
    print('[ERROR] Handling playback error: $error');

    if (_retryCount >= _maxRetries) {
      print('[ERROR] Max retries reached, stopping error handling');
      _retryCount = 0;
      return;
    }

    if (error is PlatformException) {
      print('[ERROR] Platform Exception: ${error.code} - ${error.message}');
      _retryCurrentTrack();
    } else if (error is PlayerException) {
      print('[ERROR] Player Exception: ${error.code} - ${error.message}');
      _retryCurrentTrack();
    } else {
      print('[ERROR] Unknown error: $error');
      _retryCurrentTrack();
    }
  }

  Future<void> _retryCurrentTrack() async {
    print('[DEBUG] Retrying current track...');
    try {
      final currentTrack = _currentTrack.value;
      if (currentTrack == null) {
        print('[DEBUG] No current track to retry');
        return;
      }

      _retryCount++;
      if (_retryCount > _maxRetries) {
        print('[ERROR] Max retries reached, stopping retry attempts');
        _retryCount = 0;
        return; // 直接返回，不再继续重试
      }

      print('[DEBUG] Retrying track: ${currentTrack['name']} (Attempt $_retryCount/$_maxRetries)');

      // 尝试重新加载音频源
      final url = currentTrack['url'] as String?;
      if (url == null || url.isEmpty) {
        print('[ERROR] Invalid URL for track: ${currentTrack['name']}');
        return;
      }

      final audioSource = AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(
          id: currentTrack['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: currentTrack['name'] ?? '',
          artist: currentTrack['artist'] ?? '',
          artUri: Uri.tryParse(currentTrack['cover_url'] ?? ''),
        ),
      );

      await _audioPlayer.stop();
      await Future.delayed(const Duration(milliseconds: 500));

      // 尝试直接设置单个音频源
      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
    } catch (e) {
      print('[ERROR] Error retrying current track: $e');
      if (_retryCount >= _maxRetries) {
        print('[ERROR] Max retries reached, stopping retry attempts');
        _retryCount = 0;
      }
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
    try {
      if (_playlist.isEmpty) return;

      final nextIndex = (_currentIndex.value + 1) % _playlist.length;
      print('[DEBUG] Switching to next track: ${_playlist[nextIndex]['name']}');

      await _audioPlayer.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      // 使用单个音频源
      final nextTrack = _playlist[nextIndex];
      final audioSource = AudioSource.uri(
        Uri.parse(nextTrack['url'] ?? ''),
        tag: MediaItem(
          id: nextTrack['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: nextTrack['name'] ?? '',
          artist: nextTrack['artist'] ?? '',
          artUri: Uri.tryParse(nextTrack['cover_url'] ?? ''),
        ),
      );

      await _audioPlayer.setAudioSource(audioSource);
      _currentIndex.value = nextIndex;
      _currentTrack.value = nextTrack;

      await _audioPlayer.play();
    } catch (e) {
      print('[ERROR] Error switching to next track: $e');
    }
  }

  Future<void> previous() async {
    try {
      if (_playlist.isEmpty) return;

      final previousIndex = _currentIndex.value > 0 ? _currentIndex.value - 1 : _playlist.length - 1;

      print('[DEBUG] Switching to previous track: ${_playlist[previousIndex]['name']}');

      await _audioPlayer.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      // 使用单个音频源
      final previousTrack = _playlist[previousIndex];
      final audioSource = AudioSource.uri(
        Uri.parse(previousTrack['url'] ?? ''),
        tag: MediaItem(
          id: previousTrack['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: previousTrack['name'] ?? '',
          artist: previousTrack['artist'] ?? '',
          artUri: Uri.tryParse(previousTrack['cover_url'] ?? ''),
        ),
      );

      await _audioPlayer.setAudioSource(audioSource);
      _currentIndex.value = previousIndex;
      _currentTrack.value = previousTrack;

      await _audioPlayer.play();
    } catch (e) {
      print('[ERROR] Error switching to previous track: $e');
    }
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
