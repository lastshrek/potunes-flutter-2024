# Design Document: FM Mode Background Next Track Fix

## Overview

本设计文档描述了修复 FM 模式下后台切歌功能的技术方案。核心问题是 `just_audio_background` 插件的 MediaSession 与自定义 `MusicPlayerService` 的 MediaSession 存在冲突，导致后台切歌时播放列表机制覆盖了 FM 模式的行为。

### 问题根因分析

1. **MediaSession 冲突**: `just_audio_background` 自动创建 MediaSession 处理媒体控制，同时 Android 端的 `MusicPlayerService` 也创建了 MediaSession，导致控制事件被错误处理
2. **播放列表机制**: FM 模式下播放列表被设置为 `[currentTrack]`，当 `just_audio_background` 处理 "next" 命令时，它会在播放列表内循环，导致重复播放当前歌曲
3. **通信链路不可靠**: Android 端通过广播发送控制事件，但 `MainActivity` 被销毁后广播接收器失效

### 解决方案概述

1. 移除自定义 `MusicPlayerService` 的 MediaSession，完全依赖 `just_audio_background`
2. 在 Flutter 端拦截 `just_audio` 的播放完成和切歌事件，在 FM 模式下执行自定义逻辑
3. 使用 `audio_service` 的 `AudioHandler` 自定义切歌行为

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        System Media Controls                      │
│              (Notification / Lock Screen / Headset)               │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    just_audio_background                          │
│                      (MediaSession)                               │
│  - Handles system media button events                            │
│  - Manages notification                                          │
│  - Delegates to AudioHandler                                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Custom AudioHandler                           │
│  - Overrides skipToNext() for FM mode                            │
│  - Overrides skipToPrevious() to disable in FM mode              │
│  - Calls playFMTrack() when FM mode is active                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       AudioService                                │
│  - Manages playback state                                        │
│  - Handles FM mode logic                                         │
│  - Network requests for new tracks                               │
└─────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. AudioService 修改

#### 1.1 移除自定义 MethodChannel 处理

当前的 `MethodChannel` 处理器与 `just_audio_background` 冲突，需要移除或简化：

```dart
// 移除 onInit 中的 MethodChannel 控制事件处理
// 保留 updateNowPlaying 用于更新通知信息
```

#### 1.2 监听 just_audio 的 processingState

利用 `just_audio` 的 `processingStateStream` 来检测播放完成，在 FM 模式下自动获取下一首：

```dart
_audioPlayer.processingStateStream.listen((state) {
  if (state == ProcessingState.completed && _isFMMode.value) {
    playFMTrack();
  }
});
```

#### 1.3 拦截 sequenceStateStream

监听播放序列变化，防止 `just_audio` 在 FM 模式下自动切换到播放列表中的下一首：

```dart
_audioPlayer.sequenceStateStream.listen((sequenceState) {
  if (_isFMMode.value && sequenceState?.currentIndex != 0) {
    // 在 FM 模式下，强制保持在索引 0
    _audioPlayer.seek(Duration.zero, index: 0);
  }
});
```

### 2. Android MusicPlayerService 修改

#### 2.1 移除 MediaSession

由于 `just_audio_background` 已经管理 MediaSession，移除 `MusicPlayerService` 中的 MediaSession 创建：

```kotlin
// 移除 createMediaSession() 调用
// 移除 MediaSessionCompat 相关代码
// 保留通知更新和 WakeLock 管理
```

#### 2.2 简化为通知更新服务

`MusicPlayerService` 仅负责：
- 维护前台服务状态
- 更新通知信息（从 Flutter 接收）
- 管理 WakeLock

### 3. iOS AppDelegate 修改

#### 3.1 移除 MPRemoteCommandCenter 处理

`just_audio_background` 已经处理 iOS 的远程控制命令，移除自定义处理：

```swift
// 移除 setupRemoteControl() 中的命令处理
// 保留 updateNowPlayingInfo 用于更新控制中心信息
```

### 4. 使用 audio_service 的 AudioHandler（可选方案）

如果需要更精细的控制，可以实现自定义 `AudioHandler`：

```dart
class FMAwareAudioHandler extends BaseAudioHandler {
  final AudioService _audioService;
  
  @override
  Future<void> skipToNext() async {
    if (_audioService.isFMMode) {
      await _audioService.playFMTrack();
    } else {
      await _audioService.skipToNext();
    }
  }
  
  @override
  Future<void> skipToPrevious() async {
    if (_audioService.isFMMode) {
      // FM 模式下禁用上一首
      return;
    }
    await _audioService.previous();
  }
}
```

## Data Models

### FM Mode State

```dart
class FMModeState {
  final bool isActive;
  final String? currentTrackId;
  final DateTime? lastFetchTime;
  
  FMModeState({
    required this.isActive,
    this.currentTrackId,
    this.lastFetchTime,
  });
  
  Map<String, dynamic> toJson() => {
    'isActive': isActive,
    'currentTrackId': currentTrackId,
    'lastFetchTime': lastFetchTime?.toIso8601String(),
  };
  
  factory FMModeState.fromJson(Map<String, dynamic> json) => FMModeState(
    isActive: json['isActive'] ?? false,
    currentTrackId: json['currentTrackId'],
    lastFetchTime: json['lastFetchTime'] != null 
      ? DateTime.parse(json['lastFetchTime']) 
      : null,
  );
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: FM Mode Next Track Fetches New Song

*For any* FM mode session, when the next track command is triggered, the AudioService shall request a new track from the server and the resulting current track shall have a different ID than the previous track.

**Validates: Requirements 1.1, 1.2**

### Property 2: FM Mode Uses Single Track Audio Source

*For any* track played in FM mode, the audio source shall be a single URI source (not a ConcatenatingAudioSource), and skip commands shall trigger a new network request rather than playlist navigation.

**Validates: Requirements 5.1, 5.2, 5.3**

### Property 3: Control Event Delegation

*For any* media control event received by the native service (MusicPlayerService on Android), the event shall be forwarded to Flutter AudioService via the established communication channel.

**Validates: Requirements 2.1, 2.2**

### Property 4: FM Mode State Persistence Round Trip

*For any* FM mode state, saving the state to SharedPreferences and then loading it shall produce an equivalent state object.

**Validates: Requirements 4.1**

### Property 5: FM Mode Skip Behavior Override

*For any* skip-to-next command when FM mode is active, the AudioService shall call playFMTrack() instead of the default playlist-based skipToQueueItem().

**Validates: Requirements 2.4**

### Property 6: Playlist Restoration on FM Mode Exit

*For any* session where FM mode is exited after being active, if a previous playlist existed, the AudioService shall restore that playlist.

**Validates: Requirements 5.4**

## Error Handling

### Network Failure During FM Track Fetch

```dart
Future<void> playFMTrack() async {
  try {
    _isFMMode.value = true;
    final track = await NetworkService.instance.getRadioTrack();
    // ... play track
  } catch (e) {
    // 保持当前播放状态，不中断用户体验
    ErrorReporter.showError('无法获取新歌曲，请检查网络连接');
    // 不 rethrow，让当前歌曲继续播放
  }
}
```

### Communication Channel Failure

如果 Flutter 端无法接收控制事件：
1. 原生端记录错误日志
2. 用户可以通过打开应用恢复控制
3. 播放不会中断

## Testing Strategy

### Unit Tests

1. **FM Mode State Tests**
   - 测试 FM 模式状态的保存和恢复
   - 测试 FM 模式下的切歌逻辑分支

2. **Audio Source Tests**
   - 测试 FM 模式下使用单曲源
   - 测试普通模式下使用播放列表源

### Property-Based Tests

使用 `fast_check` 或类似库进行属性测试：

1. **Property 1**: 生成随机的 FM 模式会话，验证每次切歌都获取新歌曲
2. **Property 4**: 生成随机的 FM 模式状态，验证序列化/反序列化的一致性
3. **Property 5**: 生成随机的播放状态，验证 FM 模式下切歌行为正确

### Integration Tests

1. **后台播放测试**
   - 在真机上测试后台切歌功能
   - 验证通知栏控制正常工作

2. **跨平台测试**
   - Android 和 iOS 分别测试
   - 验证 MediaSession 行为一致

### Manual Testing Checklist

- [ ] FM 模式下前台点击下一首
- [ ] FM 模式下后台点击下一首（通知栏）
- [ ] FM 模式下锁屏点击下一首
- [ ] FM 模式下耳机按钮切歌
- [ ] 网络断开时切歌的错误处理
- [ ] 应用重启后 FM 模式状态恢复
- [ ] 退出 FM 模式后播放列表恢复
