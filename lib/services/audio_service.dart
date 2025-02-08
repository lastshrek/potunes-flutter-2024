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

    // 只监听播放位置以更新当前歌词行
    ever(_position, (position) {
      _updateCurrentLine(position);
    });

    // 初始化时设置播放模式
    _audioPlayer.setLoopMode(LoopMode.all);
    _audioPlayer.setShuffleModeEnabled(false);
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
          _isHandlingCompletion = true;
          print('Track completed, current mode: ${_repeatMode.value}');

          if (_repeatMode.value == RepeatMode.single) {
            _audioPlayer.seek(Duration.zero).then((_) {
              _audioPlayer.play();
              _isHandlingCompletion = false;
            });
          } else {
            _audioPlayer.seekToNext().then((_) {
              _isHandlingCompletion = false;
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

      // 监听序列状态变化
      _audioPlayer.sequenceStateStream.listen((sequenceState) {
        if (sequenceState != null && sequenceState.currentIndex != null) {
          final newIndex = sequenceState.currentIndex!;
          print('=== Sequence State Changed ===');
          print('New index: $newIndex');
          print('Current index: ${_currentIndex.value}');
          print('Playlist length: ${_currentPlaylist.value?.length}');

          // 检查播放列表和索引是否有效
          if (_currentPlaylist.value != null && newIndex >= 0 && newIndex < _currentPlaylist.value!.length && newIndex != _currentIndex.value) {
            // 添加这个条件

            final newTrack = _currentPlaylist.value![newIndex];
            print('Updating to track: ${newTrack['name']}');
            print('Current UI track: ${_currentTrack.value?['name']}');

            // 更新当前索引和曲目
            _currentIndex.value = newIndex;
            _currentTrack.value = newTrack; // 直接使用 newTrack

            // 加载新歌曲的歌词
            _loadLyrics(_currentTrack.value!);

            // 重置播放位置和歌词索引
            _position.value = Duration.zero;
            _currentLineIndex.value = 0;

            // 保存状态
            _saveLastState();

            print('=== After Update ===');
            print('Updated index: ${_currentIndex.value}');
            print('Updated UI track: ${_currentTrack.value?['name']}');
          } else {
            print('=== Skip Update ===');
            print('Skip reason: Same index or invalid state');
          }
        }
      });
    } catch (e) {
      print('Error setting up player listeners: $e');
      _isHandlingCompletion = false;
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
            playable: true,
            displayTitle: track['name']?.toString() ?? '',
            displaySubtitle: track['artist']?.toString() ?? '',
            extras: {
              'type': track['type'],
            },
          ),
        );
      }).toList();

      // 创建播放列表
      final playlistSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: audioSources,
      );

      // 保存当前播放列表
      _currentPlaylist.value = processedTracks;
      _currentIndex.value = initialIndex;
      _currentTrack.value = processedTracks[initialIndex];

      // 设置音频源
      await _audioPlayer.setAudioSource(
        playlistSource,
        initialIndex: initialIndex,
        preload: true,
      );

      // 设置循环模式
      if (_repeatMode.value == RepeatMode.single) {
        await _audioPlayer.setLoopMode(LoopMode.one);
      } else {
        await _audioPlayer.setLoopMode(LoopMode.all);
      }

      // 开始播放
      await _audioPlayer.play();

      // 保存状态
      _saveLastState();
    } catch (e) {
      print('Error playing playlist: $e');
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
            playable: true,
            displayTitle: processedTrack['name'] ?? '',
            displaySubtitle: processedTrack['artist'] ?? '',
            extras: {
              'type': processedTrack['type'],
            },
          ),
        ),
      );

      // 设置播放模式
      await _audioPlayer.setLoopMode(LoopMode.all);
      await _audioPlayer.setShuffleModeEnabled(false);
      await _audioPlayer.play();
    } catch (e) {
      print('Error playing track: $e');
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
      print('Error toggling play: $e');
    }
  }

  Future<void> previous() async {
    try {
      if (_currentPlaylist.value == null) return;

      if (_repeatMode.value == RepeatMode.single) {
        // 单曲循环时重新播放当前歌曲
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
      } else {
        // 检查当前播放时间
        if (_position.value.inSeconds > 3) {
          // 如果播放超过3秒，重新播放当前歌曲
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.play();
        } else {
          // 直接调用 seekToPrevious，索引变化会通过监听器处理
          await _audioPlayer.seekToPrevious();
        }
      }
    } catch (e) {
      print('Error playing previous track: $e');
    }
  }

  Future<void> next() async {
    try {
      if (_currentPlaylist.value == null) return;

      if (_repeatMode.value == RepeatMode.single) {
        // 单曲循环时重新播放当前歌曲
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
      } else {
        // 直接调用 seekToNext，索引变化会通过监听器处理
        await _audioPlayer.seekToNext();
      }
    } catch (e) {
      print('Error playing next track: $e');
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
      print('Error saving last state: $e');
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
      print('Error loading last state: $e');
    }
  }

  Future<void> _loadLyrics(Map<String, dynamic> track) async {
    try {
      final id = track['id']?.toString();
      final nId = track['nId']?.toString();

      if (id == null || nId == null) return;

      // 如果是同一首歌，不重复加载歌词
      if (id == _currentLyricsId && nId == _currentLyricsNId) return;

      _isLoadingLyrics.value = true;
      _currentLyricsId = id;
      _currentLyricsNId = nId;

      final response = await _networkService.getLyrics(id, nId);

      // 确保解析歌词返回正确的类型
      if (response.containsKey('lrc') || response.containsKey('lrc_cn')) {
        _parsedLyrics.value = _formatLyrics(response);
        _currentLineIndex.value = 0;
      } else {
        _parsedLyrics.value = null;
        _currentLineIndex.value = 0;
      }
    } catch (e) {
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

  // 修改 skipToQueueItem 方法
  Future<void> skipToQueueItem(int index) async {
    try {
      print('=== skipToQueueItem Called ===');
      print('Requested index: $index');
      print('Current playlist length: ${_currentPlaylist.value?.length}');
      print('Current index: ${_currentIndex.value}');

      if (_currentPlaylist.value == null || index < 0 || index >= _currentPlaylist.value!.length) {
        print('Invalid index or no playlist');
        return;
      }

      final targetTrack = _currentPlaylist.value![index];
      print('Target track: ${targetTrack['name']}');
      print('Current track: ${_currentTrack.value?['name']}');

      // 重新创建播放列表
      final audioSources = _currentPlaylist.value!.map((track) {
        return AudioSource.uri(
          Uri.parse(track['url']),
          tag: MediaItem(
            id: track['id'].toString(),
            title: track['name']?.toString() ?? '',
            artist: track['artist']?.toString() ?? '',
            album: track['album']?.toString() ?? '',
            duration: Duration(milliseconds: int.parse(track['duration'].toString())),
            artUri: Uri.parse(track['cover_url']?.toString() ?? ''),
            playable: true,
            displayTitle: track['name']?.toString() ?? '',
            displaySubtitle: track['artist']?.toString() ?? '',
            extras: {
              'type': track['type'],
            },
          ),
        );
      }).toList();

      final playlistSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: audioSources,
      );

      // 设置音频源并指定初始索引
      await _audioPlayer.setAudioSource(
        playlistSource,
        initialIndex: index,
        preload: true,
      );

      // 更新状态
      _currentIndex.value = index;
      _currentTrack.value = targetTrack;

      // 开始播放
      await _audioPlayer.play();

      // 加载歌词
      await _loadLyrics(targetTrack);

      // 保存状态
      await _saveLastState();

      print('=== Skip Complete ===');
      print('New index: ${_currentIndex.value}');
      print('New track: ${_currentTrack.value?['name']}');
    } catch (e) {
      print('Error in skipToQueueItem: $e');
    }
  }
}
