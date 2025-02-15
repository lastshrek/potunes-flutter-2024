import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:potunes_flutter_2025/utils/error_reporter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lyric_line.dart';
import '../services/network_service.dart';
import 'package:audio_session/audio_session.dart';
import 'live_activities_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// 修改循环模式枚举
enum RepeatMode {
  all, // 列表循环
  single // 单曲循环
}

class AudioService extends GetxService {
  static AudioService get to => Get.find<AudioService>();

  static const String _playlistKey = 'last_playlist';
  static const String _indexKey = 'last_index';
  static const String _isFMModeKey = 'is_fm_mode';

  // 修改 channel 名称以匹配实际的 Bundle ID
  static String channelName = !Platform.isAndroid ? 'im.coinchat.treehole/audio_control' : 'pink.poche.potunes/audio_control';

  final AudioPlayer _audioPlayer = AudioPlayer();
  final NetworkService _networkService = NetworkService.instance;

  final _currentTrack = Rxn<Map<String, dynamic>>();
  final _nextTrack = Rxn<Map<String, dynamic>>();
  final _currentPlaylist = Rxn<List<Map<String, dynamic>>>();
  final _currentIndex = RxInt(0);
  final _isPlaying = false.obs;
  final _isBuffering = false.obs;
  final _position = Duration.zero.obs;
  final _duration = Duration.zero.obs;
  final _currentPageIndex = 0.obs;
  final _parsedLyrics = Rx<List<LyricLine>?>(null);
  final _currentLineIndex = RxInt(0);
  String? _currentLyricsId;
  String? _currentLyricsNId;
  final _isLoadingLyrics = RxBool(false);

  // 修改循环模式状态，默认为列表循环
  final _repeatMode = Rx<RepeatMode>(RepeatMode.all);
  RepeatMode get repeatMode => _repeatMode.value;

  // 添加 rxPosition getter
  Rx<Duration> get rxPosition => _position;

  // 添加 currentPlaylist 的 getter 和 setter
  List<Map<String, dynamic>> get currentPlaylist => _currentPlaylist.value ?? [];
  set currentPlaylist(List<Map<String, dynamic>> value) {
    _currentPlaylist.value = value;
    _saveLastState();
  }

  // 添加 getter
  int get currentIndex => _currentIndex.value;

  bool get isPlaying => _isPlaying.value;
  bool get isBuffering => _isBuffering.value;
  Map<String, dynamic>? get currentTrack => _currentTrack.value;
  Map<String, dynamic>? get nextTrack => _nextTrack.value;
  Duration get position => _position.value;
  Duration get duration => _duration.value;
  AudioPlayer get player => _audioPlayer;
  int get currentPageIndex => _currentPageIndex.value;
  set currentPageIndex(int value) => _currentPageIndex.value = value;
  List<LyricLine>? get lyrics => _parsedLyrics.value;
  int get currentLineIndex => _currentLineIndex.value;
  bool get isLoadingLyrics => _isLoadingLyrics.value;

  // 添加一个标志来防止重复触发
  bool _isHandlingCompletion = false;

  final _isLike = 0.obs;
  bool get isLike => _isLike.value == 1;

  // 保留随机播放状态
  final _isShuffleMode = RxBool(false);
  bool get isShuffleMode => _isShuffleMode.value;

  // 添加原始播放列表存储
  final _originalPlaylist = Rxn<List<Map<String, dynamic>>>();

  // 修改 displayPlaylist getter，根据模式返回对应列表
  List<Map<String, dynamic>>? get displayPlaylist => _currentPlaylist.value;

  // 移除 _hasRecordedPlay 变量，改用一个标记
  bool _hasRecordedPlay = false;

  // 添加 FM 模式标志
  final _isFMMode = false.obs;
  bool get isFMMode => _isFMMode.value;

  @override
  void onInit() {
    super.onInit();

    // 监听播放器状态
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying.value = state.playing;
      _isBuffering.value = state.processingState == ProcessingState.buffering;
    });

    // 修改 platform 声明，移除 const
    final platform = MethodChannel(channelName);
    platform.setMethodCallHandler((call) async {
      if (call.method == 'controlCenterEvent') {
        try {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final action = args['action'] as String;

          switch (action) {
            case 'play':
              await _audioPlayer.play();
              break;
            case 'pause':
              await _audioPlayer.pause();
              break;
            case 'next':
              if (_currentPlaylist.value != null) {
                if (_isFMMode.value) {
                  await playFMTrack();
                } else {
                  await skipToNext();
                }
              }
              break;
            case 'previous':
              if (_currentPlaylist.value != null && !_isFMMode.value) {
                await previous();
              }
              break;
            case 'seek':
              final position = args['position'] as double;
              await _audioPlayer.seek(Duration(milliseconds: (position * 1000).round()));
              break;
          }

          // 更新通知中心状态
          await _updateNowPlaying();
        } catch (e, stack) {
          ErrorReporter.showError('❌ Error executing control center event: $e\n$stack');
        }
      }
      return null;
    });

    // 设置音频会话
    AudioSession.instance.then((session) async {
      await session.configure(const AudioSessionConfiguration.music());
    });

    // 添加这些配置
    _audioPlayer.setLoopMode(LoopMode.all);
    _audioPlayer.setShuffleModeEnabled(false);

    _setupPlayerListeners();
    _loadLastState();

    // 添加播放器状态监听
    _audioPlayer.playbackEventStream.listen((event) {});

    // 修改位置监听部分
    _audioPlayer.positionStream.listen((position) {
      _position.value = position;
      _updateCurrentLine(position);

      // 检查播放进度
      if (_audioPlayer.duration != null) {
        final duration = _audioPlayer.duration!;

        // 当播放时间达到30秒且未记录时记录一次
        if (!_hasRecordedPlay && position.inSeconds >= 30 && _currentTrack.value != null) {
          _updatePlayCount();
          _hasRecordedPlay = true;
        }

        // 检查是否接近结束
        if (duration - position <= const Duration(milliseconds: 500)) {
          if (_isFMMode.value && !_isHandlingCompletion) {
            _isHandlingCompletion = true;

            // 先停止播放
            _audioPlayer.stop().then((_) async {
              try {
                await playFMTrack();
              } finally {
                _isHandlingCompletion = false;
              }
            });
          }
        }
      }
    });

    // 在播放新歌时重置计时器
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && _currentPlaylist.value != null && _currentPlaylist.value!.isNotEmpty) {
        // 确保索引在有效范围内
        final safeIndex = index.clamp(0, _currentPlaylist.value!.length - 1);
        _currentIndex.value = safeIndex;
        final currentTrack = _currentPlaylist.value![safeIndex];
        _currentTrack.value = currentTrack;

        // 更新歌词（同时会更新喜欢状态）
        _loadLyrics(currentTrack);

        // 查找下一首歌
        final nextIndex = (safeIndex + 1) % _currentPlaylist.value!.length;
        _nextTrack.value = _currentPlaylist.value![nextIndex];
      }
    });
  }

  @override
  void onClose() {
    _audioPlayer.dispose();
    super.onClose();
  }

  void _setupPlayerListeners() {
    // 监听当前索引变化
    _audioPlayer.currentIndexStream.listen((index) async {
      if (index != null && _currentPlaylist.value != null && _currentPlaylist.value!.isNotEmpty) {
        // 确保索引在有效范围内
        final safeIndex = index.clamp(0, _currentPlaylist.value!.length - 1);
        _currentIndex.value = safeIndex;
        final currentTrack = _currentPlaylist.value![safeIndex];
        _currentTrack.value = currentTrack;

        // 更新歌词（同时会更新喜欢状态）
        _loadLyrics(currentTrack);

        // 查找下一首歌
        final nextIndex = (safeIndex + 1) % _currentPlaylist.value!.length;
        _nextTrack.value = _currentPlaylist.value![nextIndex];
      }
      _updateNowPlaying();
    });

    // 监听播放状态
    _audioPlayer.playingStream.listen((isPlaying) {
      _isPlaying.value = isPlaying;
      _updateNowPlaying();
    });

    // 监听缓冲状态
    _audioPlayer.processingStateStream.listen((state) {
      _isBuffering.value = state == ProcessingState.loading || state == ProcessingState.buffering;
    });

    // 监听播放进度
    _audioPlayer.positionStream.listen((position) {
      _position.value = position;
      _updateNowPlaying();
    });

    // 监听音频时长
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _duration.value = duration;
      }
    });
  }

  Future<void> playPlaylist(List<Map<String, dynamic>> tracks, {int initialIndex = 0}) async {
    try {
      _hasRecordedPlay = false;

      // 退出 FM 模式
      _isFMMode.value = false;

      // 如果是随机播放模式，先关闭随机播放
      if (_isShuffleMode.value) {
        _isShuffleMode.value = false;
        _originalPlaylist.value = null;
      }

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
            id: '${track['id']}_${track['nId']}', // 使用组合 ID
            title: track['name']?.toString() ?? '',
            artist: track['artist']?.toString() ?? '',
            album: track['album']?.toString() ?? '',
            duration: Duration(milliseconds: int.parse(track['duration'].toString())),
            artUri: Uri.parse(track['cover_url']?.toString() ?? ''),
            playable: true,
            displayTitle: track['name']?.toString() ?? '',
            displaySubtitle: track['artist']?.toString() ?? '',
            genre: track['genre']?.toString(),
            artHeaders: const {},
            extras: {
              'type': track['type'],
              'url': track['url'],
              'isLive': false,
              'hasLyrics': true,
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

      // 先加载第一首歌的歌词
      await _loadLyrics(processedTracks[initialIndex]);

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
      await _saveLastState();
    } catch (e) {
      ErrorReporter.showError('Error playing playlist: $e');
    }
  }

  Future<void> playTrack(Map<String, dynamic> track, {bool autoPlay = true}) async {
    try {
      _currentTrack.value = track;

      // 声明 audioSource 变量
      late final AudioSource audioSource;

      if (Platform.isIOS) {
        // iOS 使用 MediaItem
        final mediaItem = MediaItem(
          id: '${track['id']}_${track['nId']}',
          title: track['name']?.toString() ?? '',
          artist: track['artist']?.toString() ?? '',
          album: track['album']?.toString() ?? '',
          duration: Duration(milliseconds: int.parse(track['duration'].toString())),
          artUri: Uri.parse(track['cover_url']?.toString() ?? ''),
          playable: true,
          displayTitle: track['name']?.toString() ?? '',
          displaySubtitle: track['artist']?.toString() ?? '',
          extras: {
            'type': track['type'] ?? 'potunes',
            'url': track['url'],
            'isLive': false,
            'hasLyrics': true,
          },
        );

        audioSource = AudioSource.uri(
          Uri.parse(track['url']),
          tag: mediaItem,
        );
      } else {
        // Android 使用普通 AudioSource
        audioSource = AudioSource.uri(Uri.parse(track['url']));
      }

      await _audioPlayer.setAudioSource(audioSource);
      if (autoPlay) {
        await _audioPlayer.play();
      }

      // 更新控制中心信息
      await _updateNowPlaying();

      // 更新灵动岛（仅 iOS）
      if (Platform.isIOS) {
        try {
          await LiveActivitiesService.to.startMusicActivity(
            title: track['name'] ?? '',
            artist: track['artist'] ?? '',
            coverUrl: track['cover_url'] ?? '',
          );
        } catch (e) {
          ErrorReporter.showError('LiveActivitiesService error (non-critical): $e');
        }
      }

      await _saveLastState();
    } catch (e) {
      ErrorReporter.showError('Error playing track: $e');
      rethrow;
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
        // 更新灵动岛状态
        // await LiveActivitiesService.to.updateMusicActivity(isPlaying: false);
      } else {
        await _audioPlayer.play();
        // 更新灵动岛状态
        // await LiveActivitiesService.to.updateMusicActivity(isPlaying: true);
      }
    } catch (e) {
      ErrorReporter.showError('Error toggling play/pause: $e');
    }
  }

  Future<void> previous() async {
    if (_isFMMode.value) {
      return; // FM 模式下禁用上一首
    }
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
          // 计算上一首歌的索引
          final currentIndex = _currentIndex.value;
          final previousIndex = currentIndex > 0 ? currentIndex - 1 : _currentPlaylist.value!.length - 1;

          // 直接调用 skipToQueueItem，而不是 seekToPrevious
          await skipToQueueItem(previousIndex);
        }
      }
    } catch (e) {
      ErrorReporter.showError('Error playing previous track: $e');
    }
  }

  Future<void> next() async {
    try {
      // 检查是否为 FM 模式
      if (_isFMMode.value) {
        await playFMTrack(); // 直接播放新的 FM 歌曲
        return;
      }

      // 非 FM 模式的原有逻辑
      if (_currentPlaylist.value == null || _currentPlaylist.value!.isEmpty) {
        return;
      }

      final nextIndex = (_currentIndex.value + 1) % _currentPlaylist.value!.length;
      await skipToQueueItem(nextIndex);
    } catch (e) {
      ErrorReporter.showError('Error in next: $e');
    }
  }

  Future<void> _saveLastState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 保存 FM 模式状态
      await prefs.setBool(_isFMModeKey, _isFMMode.value);

      if (_currentTrack.value != null) {
        // 保存当前歌曲
        await prefs.setString('current_track', jsonEncode(_currentTrack.value));
      }

      if (_currentPlaylist.value != null) {
        await prefs.setString(_playlistKey, jsonEncode(_currentPlaylist.value));
        if (_originalPlaylist.value != null) {
          await prefs.setString('original_playlist', jsonEncode(_originalPlaylist.value));
        }
        await prefs.setInt(_indexKey, _currentIndex.value);
        await prefs.setBool('shuffle_mode', _isShuffleMode.value);
      }
    } catch (e) {
      ErrorReporter.showError('Error saving last state: $e');
    }
  }

  Future<void> _loadLastState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载 FM 模式状态
      _isFMMode.value = prefs.getBool(_isFMModeKey) ?? false;

      // 加载当前歌曲
      final currentTrackJson = prefs.getString('current_track');
      if (currentTrackJson != null) {
        _currentTrack.value = Map<String, dynamic>.from(jsonDecode(currentTrackJson));
      }

      // 如果是 FM 模式，只加载当前歌曲并开始播放
      if (_isFMMode.value && _currentTrack.value != null) {
        // 设置播放列表为单曲
        _currentPlaylist.value = [_currentTrack.value!];
        _currentIndex.value = 0;
        _nextTrack.value = null;

        // 创建 MediaItem
        final mediaItem = MediaItem(
          id: '${_currentTrack.value!['id']}_${_currentTrack.value!['nId']}',
          title: _currentTrack.value!['name']?.toString() ?? '',
          artist: _currentTrack.value!['artist']?.toString() ?? '',
          album: _currentTrack.value!['album']?.toString() ?? '',
          duration: Duration(milliseconds: int.parse(_currentTrack.value!['duration'].toString())),
          artUri: Uri.parse(_currentTrack.value!['cover_url']?.toString() ?? ''),
          playable: true,
          displayTitle: _currentTrack.value!['name']?.toString() ?? '',
          displaySubtitle: _currentTrack.value!['artist']?.toString() ?? '',
          extras: {
            'type': _currentTrack.value!['type'] ?? 'potunes',
            'url': _currentTrack.value!['url'],
            'isLive': false,
            'hasLyrics': true,
          },
        );

        // 创建 AudioSource
        final audioSource = AudioSource.uri(
          Uri.parse(_currentTrack.value!['url']),
          tag: mediaItem,
        );

        // 设置音频源
        await _audioPlayer.setAudioSource(audioSource);

        // 加载歌词
        await _loadLyrics(_currentTrack.value!);
        return;
      }

      // 非 FM 模式的正常加载逻辑
      final playlistJson = prefs.getString(_playlistKey);
      final originalPlaylistJson = prefs.getString('original_playlist');
      final index = prefs.getInt(_indexKey);
      final isShuffleMode = prefs.getBool('shuffle_mode') ?? false;

      if (playlistJson != null && index != null) {
        final playlist = List<Map<String, dynamic>>.from(jsonDecode(playlistJson).map((x) => Map<String, dynamic>.from(x)));

        if (playlist.isNotEmpty && index < playlist.length) {
          // 设置随机播放状态
          _isShuffleMode.value = isShuffleMode;

          // 加载播放列表
          _currentPlaylist.value = playlist;
          if (isShuffleMode && originalPlaylistJson != null) {
            _originalPlaylist.value = List<Map<String, dynamic>>.from(jsonDecode(originalPlaylistJson).map((x) => Map<String, dynamic>.from(x)));
          }

          // 设置当前索引和曲目
          _currentIndex.value = index;
          _currentTrack.value = playlist[index];

          // 加载歌词
          await _loadLyrics(playlist[index]);

          // 创建音频源
          final audioSources = playlist.map((track) {
            return AudioSource.uri(
              Uri.parse(track['url']),
              tag: MediaItem(
                id: '${track['id']}_${track['nId']}', // 使用组合 ID
                title: track['name']?.toString() ?? '',
                artist: track['artist']?.toString() ?? '',
                album: track['album']?.toString() ?? '',
                duration: Duration(milliseconds: int.parse(track['duration'].toString())),
                artUri: Uri.parse(track['cover_url']?.toString() ?? ''),
                playable: true,
                displayTitle: track['name']?.toString() ?? '',
                displaySubtitle: track['artist']?.toString() ?? '',
                genre: track['genre']?.toString(),
                artHeaders: const {},
                extras: {
                  'type': track['type'],
                  'url': track['url'],
                  'isLive': false,
                  'hasLyrics': true,
                },
              ),
            );
          }).toList();

          final playlistSource = ConcatenatingAudioSource(
            useLazyPreparation: true,
            shuffleOrder: DefaultShuffleOrder(),
            children: audioSources,
          );

          // 设置音频源
          await _audioPlayer.setAudioSource(
            playlistSource,
            initialIndex: index,
            preload: true,
          );
        }
      }

      // 如果是 FM 模式，直接播放当前歌曲
      if (_isFMMode.value && _currentTrack.value != null) {
        await playTrack(_currentTrack.value!, autoPlay: false);
      }
    } catch (e) {
      ErrorReporter.showError('Error loading last state: $e');
      _currentPlaylist.value = null;
      _currentTrack.value = null;
      _currentIndex.value = 0;
      _isFMMode.value = false; // 重置 FM 模式
    }
  }

  Future<void> _loadLyrics(Map<String, dynamic> track) async {
    try {
      _isLoadingLyrics.value = true;

      // 避免重复加载相同的歌词
      if (_currentLyricsId == track['id']?.toString() && _currentLyricsNId == track['nId']?.toString()) {
        return;
      }

      _currentLyricsId = track['id']?.toString();
      _currentLyricsNId = track['nId']?.toString();

      final response = await _networkService.getLyrics(
        _currentLyricsId ?? '',
        _currentLyricsNId ?? '',
      );

      // 更新喜欢状态
      if (response['isLike'] != null) {
        _isLike.value = response['isLike'] as int;
      }

      // 格式化歌词
      _parsedLyrics.value = _formatLyrics(response);
    } catch (e) {
      ErrorReporter.showError('Error loading lyrics: $e');
      _parsedLyrics.value = null;
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
    try {
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
    } catch (e) {
      ErrorReporter.showError('Error formatting lyrics: $e');
      return null;
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
      // 确保所有必要字段都存在
      final track = {
        'id': _currentTrack.value!['id'],
        'nId': _currentTrack.value!['nId'],
        'name': _currentTrack.value!['name'],
        'artist': _currentTrack.value!['artist'],
        'album': _currentTrack.value!['album'],
        'duration': _currentTrack.value!['duration'],
        'cover_url': _currentTrack.value!['cover_url'],
        'url': _currentTrack.value!['url'],
        'type': _currentTrack.value!['type'] ?? 'potunes',
        'playlist_id': _currentTrack.value!['playlist_id'] ?? 0,
        'ar': _currentTrack.value!['ar'] ?? [],
        'original_album': _currentTrack.value!['original_album'] ?? '',
        'original_album_id': _currentTrack.value!['original_album_id'] ?? 0,
        'mv': _currentTrack.value!['mv'] ?? 0,
      };

      final success = await _networkService.likeTrack(track);

      if (success) {
        // 更新本地状态
        _isLike.value = _isLike.value == 1 ? 0 : 1;
      }
    } catch (e) {
      ErrorReporter.showError('Error toggling like: $e');
    }
  }

  // 修改 skipToQueueItem 方法
  Future<void> skipToQueueItem(int index) async {
    try {
      _hasRecordedPlay = false; // 重置记录状态
      if (_currentPlaylist.value == null || index < 0 || index >= _currentPlaylist.value!.length) {
        return;
      }

      // 获取目标歌曲
      final targetTrack = _currentPlaylist.value![index];

      // 重新创建播放列表
      final audioSources = _currentPlaylist.value!.map((track) {
        return AudioSource.uri(
          Uri.parse(track['url']),
          tag: MediaItem(
            id: '${track['id']}_${track['nId']}', // 使用组合 ID
            title: track['name']?.toString() ?? '',
            artist: track['artist']?.toString() ?? '',
            album: track['album']?.toString() ?? '',
            duration: Duration(milliseconds: int.parse(track['duration'].toString())),
            artUri: Uri.parse(track['cover_url']?.toString() ?? ''),
            playable: true,
            displayTitle: track['name']?.toString() ?? '',
            displaySubtitle: track['artist']?.toString() ?? '',
            genre: track['genre']?.toString(),
            artHeaders: const {},
            extras: {
              'type': track['type'],
              'url': track['url'],
              'isLive': false,
              'hasLyrics': true,
            },
          ),
        );
      }).toList();

      final playlistSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: audioSources,
      );

      // 更新状态
      _currentIndex.value = index;
      _currentTrack.value = targetTrack;

      // 先加载歌词
      await _loadLyrics(targetTrack);

      // 设置音频源并指定初始索引
      await _audioPlayer.setAudioSource(
        playlistSource,
        initialIndex: index,
        preload: true,
      );

      // 开始播放
      await _audioPlayer.play();

      // 保存状态
      await _saveLastState();
    } catch (e) {
      ErrorReporter.showError('Error in skipToQueueItem: $e');
    }
  }

  // 修改 toggleShuffle 方法
  Future<void> toggleShuffle() async {
    try {
      _isShuffleMode.value = !_isShuffleMode.value;

      if (_isShuffleMode.value) {
        // 启用随机播放时
        if (_currentPlaylist.value != null) {
          // 保存原始播放列表
          _originalPlaylist.value ??= List.from(_currentPlaylist.value!);

          // 保存当前播放的歌曲
          final currentTrack = _currentTrack.value;

          // 创建随机播放列表
          final List<Map<String, dynamic>> shuffled = List.from(_currentPlaylist.value!);
          shuffled.remove(currentTrack);
          shuffled.shuffle();
          shuffled.insert(0, currentTrack!);

          // 更新当前播放列表和索引
          _currentPlaylist.value = shuffled;
          _currentIndex.value = 0;
        }
      } else {
        // 关闭随机播放时，恢复原始列表
        if (_originalPlaylist.value != null) {
          // 找到当前歌曲在原始列表中的位置
          final currentTrack = _currentTrack.value;

          final originalIndex = _originalPlaylist.value!.indexWhere((t) => t['id'] == currentTrack!['id'] && t['nId'] == currentTrack['nId']);

          if (originalIndex != -1) {
            // 恢复原始播放列表和正确的索引
            _currentPlaylist.value = _originalPlaylist.value;
            _currentIndex.value = originalIndex;
          }
        }
      }

      // 保存状态
      await _saveLastState();
    } catch (e) {
      ErrorReporter.showError('Error toggling shuffle: $e');
    }
  }

  // 停止播放
  Future<void> stop() async {
    try {
      _hasRecordedPlay = false; // 重置记录状态
      await _audioPlayer.stop();
      _isPlaying.value = false;

      // 停止灵动岛显示
      if (Platform.isIOS) {
        await LiveActivitiesService.to.stopMusicActivity();
      }
    } catch (e) {
      ErrorReporter.showError('Error stopping playback: $e');
    }
  }

  // 修改 skipToNext 方法
  Future<void> skipToNext() async {
    if (_isFMMode.value) {
      await playFMTrack();
      return;
    }

    try {
      if (_currentPlaylist.value == null || _currentPlaylist.value!.isEmpty) {
        return;
      }

      final nextIndex = (_currentIndex.value + 1) % _currentPlaylist.value!.length;
      await skipToQueueItem(nextIndex);
    } catch (e) {
      ErrorReporter.showError('AudioService: Error skipping to next: $e');
    }
  }

  // 修改播放次数更新方法
  Future<void> _updatePlayCount() async {
    try {
      if (_currentTrack.value == null) return;

      await NetworkService.instance.updateTrackPlayCount(_currentTrack.value!);
    } catch (e) {
      ErrorReporter.showError('Error updating play count: $e');
    }
  }

  bool isCurrentTrack(Map<String, dynamic> track) {
    final currentTrack = _currentTrack.value;
    if (currentTrack == null) return false;

    // 同时检查 id 和 nId 是否相等
    return currentTrack['id']?.toString() == track['id']?.toString() && currentTrack['nId']?.toString() == track['nId']?.toString();
  }

  // 修改 playFMTrack 方法，使用公开的 playTrack 方法
  Future<void> playFMTrack() async {
    try {
      _isFMMode.value = true;
      final track = await NetworkService.instance.getRadioTrack(); // 添加调试日志

      // 清除当前播放列表并设置当前歌曲
      _currentPlaylist.value = [track];
      _currentIndex.value = 0;
      _currentTrack.value = track;
      _nextTrack.value = null;

      // 加载歌词
      await _loadLyrics(track);

      // 创建 MediaItem
      final mediaItem = MediaItem(
        id: '${track['id']}_${track['nId']}',
        title: track['name']?.toString() ?? '',
        artist: track['artist']?.toString() ?? '',
        album: track['album']?.toString() ?? '',
        duration: Duration(milliseconds: int.parse(track['duration'].toString())),
        artUri: Uri.parse(track['cover_url']?.toString() ?? ''),
        playable: true,
        displayTitle: track['name']?.toString() ?? '',
        displaySubtitle: track['artist']?.toString() ?? '',
        extras: {
          'type': track['type'] ?? 'potunes',
          'url': track['url'],
          'isLive': false,
          'hasLyrics': true,
        },
      );

      // 创建 AudioSource
      final audioSource = AudioSource.uri(
        Uri.parse(track['url']),
        tag: mediaItem,
      );

      // 设置并播放音频
      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();

      if (Platform.isIOS) {
        // 更新灵动岛
        try {
          await LiveActivitiesService.to.startMusicActivity(
            title: track['name'] ?? '',
            artist: track['artist'] ?? '',
            coverUrl: track['cover_url'] ?? '',
          );
        } catch (e) {
          ErrorReporter.showError('LiveActivitiesService error (non-critical): $e');
        }
      }
      // 保存状态
      await _saveLastState();
    } catch (e) {
      ErrorReporter.showError('Error playing FM track: $e');
      rethrow;
    }
  }

  // 退出 FM 模式
  void exitFMMode() {
    _isFMMode.value = false;
    _saveLastState();
  }

  // 更新控制中心信息
  Future<void> _updateNowPlaying() async {
    if (_currentTrack.value == null) return;

    try {
      var platform = MethodChannel(channelName);
      if (Platform.isAndroid) {
        // Android 发送完整信息
        await platform.invokeMethod('updateNowPlaying', {
          'title': _currentTrack.value!['name'] ?? '',
          'artist': _currentTrack.value!['artist'] ?? '',
          'duration': _duration.value.inSeconds.toDouble(),
          'currentTime': _position.value.inSeconds.toDouble(),
          'isPlaying': _isPlaying.value,
          'coverUrl': _currentTrack.value!['cover_url'] ?? '',
        });
      } else {
        // iOS 发送完整信息
        await platform.invokeMethod('updateNowPlaying', {
          'title': _currentTrack.value!['name'] ?? '',
          'artist': _currentTrack.value!['artist'] ?? '',
          'duration': _duration.value.inSeconds.toDouble(),
          'currentTime': _position.value.inSeconds.toDouble(),
          'isPlaying': _isPlaying.value,
          'coverUrl': _currentTrack.value!['cover_url'] ?? '',
        });
      }
    } catch (e) {
      ErrorReporter.showError('Error updating now playing info: $e');
    }
  }

  Future<void> play() async {
    await _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }
}
