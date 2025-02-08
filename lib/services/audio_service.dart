import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lyric_line.dart';
import '../services/network_service.dart';

class AudioService extends GetxService {
  static AudioService get to => Get.find<AudioService>();

  static const String _playlistKey = 'last_playlist';
  static const String _indexKey = 'last_index';

  final AudioPlayer _audioPlayer = AudioPlayer();
  final NetworkService _networkService = NetworkService();

  final _currentTrack = Rxn<Map<String, dynamic>>();
  final _currentPlaylist = Rxn<List<Map<String, dynamic>>>();
  final _currentIndex = RxInt(0);
  final _isPlaying = RxBool(false);
  final _position = Rx<Duration>(Duration.zero);
  final _duration = Rx<Duration>(Duration.zero);
  final _currentPageIndex = 0.obs;
  final _parsedLyrics = Rx<List<LyricLine>?>(null);
  final _currentLineIndex = RxInt(0);
  String? _currentLyricsId;
  final _isLoadingLyrics = RxBool(false);

  // 添加随机播放状态
  final _isShuffleMode = RxBool(false);
  final _shuffledIndices = <int>[].obs;
  int _currentShuffleIndex = 0;

  // 添加 rxPosition getter
  Rx<Duration> get rxPosition => _position;

  // 添加 getter
  List<Map<String, dynamic>>? get currentPlaylist => _currentPlaylist.value;
  int get currentIndex => _currentIndex.value;

  bool get isPlaying => _isPlaying.value;
  Map<String, dynamic>? get currentTrack => _currentTrack.value;
  Duration get position => _position.value;
  Duration get duration => _duration.value;
  AudioPlayer get player => _audioPlayer;
  int get currentPageIndex => _currentPageIndex.value;
  set currentPageIndex(int value) => _currentPageIndex.value = value;
  List<LyricLine>? get lyrics => _parsedLyrics.value;
  int get currentLineIndex => _currentLineIndex.value;
  bool get isLoadingLyrics => _isLoadingLyrics.value;
  bool get isShuffleMode => _isShuffleMode.value;

  @override
  void onInit() {
    super.onInit();
    _setupPlayerListeners();
    _loadLastState();

    // 监听播放位置以更新当前歌词行
    ever(_position, (position) {
      _updateCurrentLine(position);
    });

    // 监听当前歌曲变化以加载歌词
    ever(_currentTrack, (track) {
      if (track != null) {
        _loadLyrics(track);
      } else {
        _parsedLyrics.value = null;
        _currentLineIndex.value = 0;
      }
    });
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
      _updateCurrentIndex(track);
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
      if (_currentPlaylist.value == null) return;

      if (_isShuffleMode.value) {
        // 随机播放模式
        _currentShuffleIndex--;
        if (_currentShuffleIndex < 0) {
          _currentShuffleIndex = _shuffledIndices.length - 1;
        }
        _currentIndex.value = _shuffledIndices[_currentShuffleIndex];
      } else {
        // 顺序播放模式
        if (_currentIndex.value <= 0) return;
        _currentIndex.value--;
      }

      await playTrack(_currentPlaylist.value![_currentIndex.value]);
      _saveLastState();
    } catch (e) {
      debugPrint('Error playing previous track: $e');
    }
  }

  Future<void> next() async {
    try {
      if (_currentPlaylist.value == null) return;

      if (_isShuffleMode.value) {
        // 随机播放模式
        _currentShuffleIndex++;
        if (_currentShuffleIndex >= _shuffledIndices.length) {
          // 如果到达列表末尾，重新打乱
          final indices = List.generate(_currentPlaylist.value!.length, (i) => i);
          indices.shuffle();
          _shuffledIndices.value = indices;
          _currentShuffleIndex = 0;
        }
        _currentIndex.value = _shuffledIndices[_currentShuffleIndex];
      } else {
        // 顺序播放模式
        if (_currentIndex.value >= _currentPlaylist.value!.length - 1) return;
        _currentIndex.value++;
      }

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

  Future<void> _loadLyrics(Map<String, dynamic> track) async {
    final id = track['id']?.toString();
    final nId = track['nId']?.toString();

    if (id == null || nId == null || id == _currentLyricsId) return;

    _isLoadingLyrics.value = true;
    _currentLyricsId = id;

    try {
      final response = await _networkService.getLyrics(id, nId);

      if (response.containsKey('lrc') || response.containsKey('lrc_cn')) {
        _parsedLyrics.value = _formatLyrics(response);
        _currentLineIndex.value = 0;
      } else {
        _parsedLyrics.value = null;
        _currentLineIndex.value = 0;
      }
    } catch (e) {
      debugPrint('Error loading lyrics: $e');
      _parsedLyrics.value = null;
      _currentLineIndex.value = 0;
    } finally {
      _isLoadingLyrics.value = false;
    }
  }

  void _updateCurrentLine(Duration position) {
    if (_parsedLyrics.value == null) return;

    int index = _parsedLyrics.value!.indexWhere((line) => line.time > position);
    if (index == -1) {
      index = _parsedLyrics.value!.length;
    }
    index = (index - 1).clamp(0, _parsedLyrics.value!.length - 1);

    if (index != _currentLineIndex.value) {
      _currentLineIndex.value = index;
    }
  }

  List<LyricLine>? _formatLyrics(Map<String, dynamic> response) {
    final original = response['lrc'] as String?;
    final translated = response['lrc_cn'] as String?;

    if (original == null) return null;

    final List<LyricLine> lyrics = [];
    final Map<Duration, String> translationMap = {};

    // 解析翻译歌词
    if (translated != null) {
      final translatedLines = translated.split('\n');
      for (final line in translatedLines) {
        final match = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(line);
        if (match != null) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
          final text = match.group(4)!.trim();

          // 只添加非空的翻译
          if (text.isNotEmpty) {
            final time = Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            );
            translationMap[time] = text;
          }
        }
      }
    }

    // 解析原文歌词
    final originalLines = original.split('\n');
    for (final line in originalLines) {
      final match = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)!.trim();

        // 只添加非空的原文
        if (text.isNotEmpty) {
          final time = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );

          // 如果有对应的翻译，添加翻译；如果没有，只添加原文
          final translation = translationMap[time];
          if (translation?.isNotEmpty == true || text.isNotEmpty) {
            lyrics.add(LyricLine(
              time: time,
              original: text,
              translation: translation,
            ));
          }
        }
      }
    }

    // 按时间排序并过滤掉完全空白的行
    lyrics.sort((a, b) => a.time.compareTo(b.time));
    final filteredLyrics = lyrics.where((line) => line.original.isNotEmpty || (line.translation?.isNotEmpty ?? false)).toList();

    return filteredLyrics.isNotEmpty ? filteredLyrics : null;
  }

  // 添加切换随机播放的方法
  void toggleShuffle() {
    _isShuffleMode.value = !_isShuffleMode.value;

    if (_isShuffleMode.value) {
      // 启用随机播放时，生成随机顺序
      final indices = List.generate(_currentPlaylist.value?.length ?? 0, (i) => i);
      indices.remove(_currentIndex.value); // 移除当前播放的歌曲
      indices.shuffle(); // 打乱顺序
      indices.insert(0, _currentIndex.value); // 将当前歌曲放在第一位
      _shuffledIndices.value = indices;
      _currentShuffleIndex = 0;
    }
  }

  // 添加一个方法来更新当前索引
  void _updateCurrentIndex(Map<String, dynamic> track) {
    if (_currentPlaylist.value != null) {
      final index = _currentPlaylist.value!.indexWhere((t) => t['id'] == track['id']);
      if (index != -1) {
        _currentIndex.value = index;
      }
    }
  }
}
