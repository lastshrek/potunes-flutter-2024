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
import 'package:dio/dio.dart';
import '../services/user_service.dart';
import 'package:flutter/material.dart';

// 修改循环模式枚举
enum RepeatMode {
  all, // 列表循环
  single // 单曲循环
}

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
  String? _currentLyricsNId;
  final _isLoadingLyrics = RxBool(false);

  // 添加随机播放状态
  final _isShuffleMode = RxBool(false);
  final _shuffledIndices = <int>[].obs;
  int _currentShuffleIndex = 0;

  // 添加随机播放列表
  final _shuffledPlaylist = Rxn<List<Map<String, dynamic>>>();

  // 修改循环模式状态，默认为列表循环
  final _repeatMode = Rx<RepeatMode>(RepeatMode.all);
  RepeatMode get repeatMode => _repeatMode.value;

  // 添加 rxPosition getter
  Rx<Duration> get rxPosition => _position;

  // 添加 currentPlaylist 的 getter 和 setter
  List<Map<String, dynamic>>? get currentPlaylist => _currentPlaylist.value;
  set currentPlaylist(List<Map<String, dynamic>>? value) {
    _currentPlaylist.value = value;
    _saveLastState();
  }

  // 添加 getter
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

  // 添加一个标志来防止重复触发
  bool _isHandlingCompletion = false;

  final _isLike = 0.obs;
  bool get isLike => _isLike.value == 1;

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

    // 初始化时设置为列表循环，并禁用自动循环
    _audioPlayer.setLoopMode(LoopMode.off);
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

        // 处理播放完成事件
        if (state.processingState == ProcessingState.completed && !_isHandlingCompletion) {
          _isHandlingCompletion = true; // 设置标志
          debugPrint('Track completed, current mode: ${_repeatMode.value}');

          if (_repeatMode.value == RepeatMode.single) {
            // 单曲循环时重新播放当前歌曲
            _audioPlayer.seek(Duration.zero).then((_) {
              _audioPlayer.play();
              _isHandlingCompletion = false; // 重置标志
            });
          } else {
            // 列表循环时播放下一首
            next().then((_) {
              _isHandlingCompletion = false; // 重置标志
            });
          }
        }
      });

      // 监听播放位置
      _audioPlayer.positionStream.listen((position) {
        _position.value = position;
      });

      // 监听音频时长
      _audioPlayer.durationStream.listen((duration) {
        _duration.value = duration ?? Duration.zero;
      });
    } catch (e) {
      debugPrint('Error setting up player listeners: $e');
      _isHandlingCompletion = false; // 确保在发生错误时重置标志
    }
  }

  Future<void> playPlaylist(List<Map<String, dynamic>> tracks, {int initialIndex = 0}) async {
    try {
      // 确保每个歌曲都有 type 字段
      final processedTracks = tracks.map((track) {
        if (track['type'] == null) {
          return {
            ...track,
            'type': 'potunes',
          };
        }
        return track;
      }).toList();

      // 转换播放列表为 AudioSource
      final audioSources = processedTracks.map((track) {
        return AudioSource.uri(
          Uri.parse(track['url']),
          tag: MediaItem(
            id: track['id'].toString(),
            title: track['name']?.toString() ?? '',
            artist: track['artist']?.toString() ?? '',
            album: track['album']?.toString() ?? '',
            duration: Duration(milliseconds: int.parse(track['duration'].toString())),
            artUri: Uri.parse(track['cover_url']?.toString() ?? ''),
            extras: {
              'type': track['type'], // 保存 type 字段
            },
          ),
        );
      }).toList();

      // 创建播放列表
      final playlistSource = ConcatenatingAudioSource(children: audioSources);

      // 保存当前播放列表
      _currentPlaylist.value = processedTracks;
      _currentIndex.value = initialIndex;
      _currentTrack.value = processedTracks[initialIndex];

      // 加载并播放
      await _audioPlayer.setAudioSource(playlistSource, initialIndex: initialIndex);
      await _audioPlayer.play();

      // 保存状态
      _saveLastState();
    } catch (e) {
      print('Error playing playlist: $e');
      if (tracks.isNotEmpty) {
        print('First track data: ${tracks[0]}');
      }
    }
  }

  Future<void> playTrack(Map<String, dynamic> track) async {
    try {
      // 确保有 type 字段
      final processedTrack = track['type'] == null ? {...track, 'type': 'potunes'} : track;
      _currentTrack.value = processedTrack;
      _updateCurrentIndex(processedTrack);

      final url = processedTrack['url'];
      if (url == null) return;

      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: processedTrack['id']?.toString() ?? '',
            title: processedTrack['name'] ?? '',
            artist: processedTrack['artist'] ?? '',
            artUri: Uri.parse(processedTrack['cover_url'] ?? ''),
            extras: {
              'type': processedTrack['type'], // 保存 type 字段
            },
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

      final playlist = currentPlaylist;
      if (playlist != null) {
        if (_repeatMode.value == RepeatMode.single) {
          // 单曲循环时重新播放当前歌曲
          await playTrack(playlist[_currentIndex.value]);
        } else {
          // 检查当前播放时间
          if (_position.value.inSeconds > 10) {
            // 如果播放超过10秒，重新播放当前歌曲
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.play();
          } else {
            // 播放上一首，如果是第一首则跳到最后一首
            final previousIndex = _currentIndex.value > 0 ? _currentIndex.value - 1 : playlist.length - 1;
            _currentIndex.value = previousIndex;
            await playTrack(playlist[previousIndex]);
          }
        }
        _saveLastState();
      }
    } catch (e) {
      debugPrint('Error playing previous track: $e');
    }
  }

  Future<void> next() async {
    try {
      if (_currentPlaylist.value == null) return;

      final playlist = currentPlaylist;
      if (playlist != null) {
        if (_repeatMode.value == RepeatMode.single) {
          // 单曲循环时重新播放当前歌曲
          await playTrack(playlist[_currentIndex.value]);
        } else {
          // 列表循环：如果是最后一首则回到第一首
          final nextIndex = _currentIndex.value < playlist.length - 1 ? _currentIndex.value + 1 : 0;
          _currentIndex.value = nextIndex;
          await playTrack(playlist[nextIndex]);
        }
        _saveLastState();
      }
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
          // 只设置播放列表和当前歌曲，但不开始播放
          _currentPlaylist.value = playlist;
          _currentIndex.value = index;
          _currentTrack.value = playlist[index];

          // 加载音频源但不播放
          final track = playlist[index];
          final url = track['url'];
          if (url != null) {
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
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading last state: $e');
    }
  }

  Future<void> _loadLyrics(Map<String, dynamic> track) async {
    print('=== Starting _loadLyrics ===');
    print('Track data: $track');

    final id = track['id']?.toString();
    final nId = track['nId']?.toString();

    if (id == null || nId == null) {
      print('Missing ID or NID, skipping lyrics load');
      return;
    }

    if (id == _currentLyricsId && nId == _currentLyricsNId) {
      print('Same lyrics as current, skipping load');
      return;
    }

    _isLoadingLyrics.value = true;
    _currentLyricsId = id;
    _currentLyricsNId = nId;

    try {
      print('Calling NetworkService.getLyrics');
      final response = await _networkService.getLyrics(id, nId);
      print('Lyrics response received: $response');

      // 更新 isLike 状态，直接保存数字
      _isLike.value = response['isLike'] ?? 0;

      if (response.containsKey('lrc') || response.containsKey('lrc_cn')) {
        _parsedLyrics.value = _formatLyrics(response);
        _currentLineIndex.value = 0;
        print('Lyrics loaded successfully');
      } else {
        print('No lyrics found in response');
        _parsedLyrics.value = null;
        _currentLineIndex.value = 0;
      }
    } catch (e) {
      print('Error loading lyrics: $e');
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

  // 修改切换随机播放的方法
  void toggleShuffle() {
    _isShuffleMode.value = !_isShuffleMode.value;

    if (_isShuffleMode.value) {
      // 启用随机播放时，生成随机顺序的播放列表
      if (_currentPlaylist.value != null) {
        final currentTrack = _currentTrack.value;
        final List<Map<String, dynamic>> shuffled = List.from(_currentPlaylist.value!);
        shuffled.remove(currentTrack); // 移除当前播放的歌曲
        shuffled.shuffle(); // 打乱顺序
        shuffled.insert(0, currentTrack!); // 将当前歌曲放在第一位
        _shuffledPlaylist.value = shuffled;
        _currentIndex.value = 0; // 重置当前索引
      }
    } else {
      // 关闭随机播放时，恢复原始顺序
      if (_currentTrack.value != null && _currentPlaylist.value != null) {
        // 找到当前歌曲在原始列表中的位置
        final index = _currentPlaylist.value!.indexWhere((t) => t['id'] == _currentTrack.value!['id']);
        if (index != -1) {
          _currentIndex.value = index;
        }
      }
      _shuffledPlaylist.value = null;
    }
  }

  // 修改 _updateCurrentIndex 方法
  void _updateCurrentIndex(Map<String, dynamic> track) {
    final playlist = currentPlaylist;
    if (playlist != null) {
      final index = playlist.indexWhere((t) => isSameSong(t, track));
      if (index != -1) {
        _currentIndex.value = index;
      }
    }
  }

  // 修改切换循环模式的方法
  void toggleRepeatMode() {
    switch (_repeatMode.value) {
      case RepeatMode.all:
        _repeatMode.value = RepeatMode.single;
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.single:
        _repeatMode.value = RepeatMode.all;
        _audioPlayer.setLoopMode(LoopMode.all);
        break;
    }
  }

  bool isSamePlaylist(List<Map<String, dynamic>>? list1, List<Map<String, dynamic>>? list2) {
    if (list1 == null || list2 == null) return false;
    if (list1.length != list2.length) return false;

    // 比较第一首歌的 id、nId 和 source
    if (list1.isNotEmpty && list2.isNotEmpty) {
      final song1 = list1[0];
      final song2 = list2[0];
      return song1['id'] == song2['id'] && song1['nId'] == song2['nId'] && song1['source'] == song2['source'];
    }

    return false;
  }

  // 添加一个方法来比较单个歌曲
  bool isSameSong(Map<String, dynamic>? song1, Map<String, dynamic>? song2) {
    if (song1 == null || song2 == null) return false;
    return song1['id'] == song2['id'] && song1['nId'] == song2['nId'];
  }

  // 修改 currentPlaylist 的 getter
  bool isCurrentPlaylist(List<Map<String, dynamic>> playlist) {
    return isSamePlaylist(_currentPlaylist.value?.cast<Map<String, dynamic>>(), playlist);
  }

  // 添加喜欢/取消喜欢的方法
  Future<void> toggleLike() async {
    if (_currentTrack.value == null) return;

    try {
      print('=== Toggle Like ===');
      print('Current track: ${_currentTrack.value}');
      print('Track type: ${_currentTrack.value!['type']}');

      final success = await _networkService.likeTrack(_currentTrack.value!);

      if (success) {
        // 更新本地状态
        _isLike.value = _isLike.value == 1 ? 0 : 1;

        // 显示提示
        Get.snackbar(
          'Success',
          _isLike.value == 1 ? '已添加到我喜欢的音乐' : '已取消喜欢',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      } else {
        Get.snackbar(
          'Error',
          '操作失败，请重试',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      print('Error toggling like: $e');
      Get.snackbar(
        'Error',
        '操作失败，请重试',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }
}
