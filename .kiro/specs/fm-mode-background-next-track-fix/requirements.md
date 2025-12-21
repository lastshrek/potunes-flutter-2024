# Requirements Document

## Introduction

本文档定义了修复 FM 模式下后台切歌功能的需求。当前问题是：在 FM 模式下，当应用进入后台时，用户点击通知栏或锁屏界面的"下一首"按钮，播放的仍然是当前歌曲，而不是从服务器获取新的随机歌曲。

## Glossary

- **FM_Mode**: 电台模式，一种特殊的播放模式，每次切歌都从服务器获取新的随机歌曲，不支持上一首功能
- **AudioService**: Flutter 端的音频服务，负责管理播放状态和控制逻辑
- **MusicPlayerService**: Android 原生端的前台服务，负责后台播放和媒体通知
- **MediaSession**: 系统媒体会话，用于处理系统级媒体控制（锁屏、通知栏、耳机按钮等）
- **just_audio_background**: Flutter 插件，提供后台播放和媒体通知功能
- **MethodChannel**: Flutter 与原生平台通信的桥梁
- **Control_Center**: iOS 控制中心或 Android 通知栏的媒体控制界面

## Requirements

### Requirement 1: FM 模式后台切歌

**User Story:** As a user, I want to skip to the next FM track when the app is in background, so that I can discover new music without opening the app.

#### Acceptance Criteria

1. WHEN the user taps the next button in Control_Center while in FM_Mode, THE AudioService SHALL request a new track from the server and play it
2. WHEN the user taps the next button in Control_Center while in FM_Mode, THE AudioService SHALL NOT replay the current track
3. WHEN the app is in background and FM_Mode is active, THE system SHALL maintain the ability to receive and process next track commands
4. IF the network request for a new FM track fails, THEN THE AudioService SHALL display an error notification and maintain the current playback state

### Requirement 2: MediaSession 冲突解决

**User Story:** As a developer, I want to resolve the conflict between just_audio_background and custom MediaSession, so that media controls work correctly in all scenarios.

#### Acceptance Criteria

1. THE MusicPlayerService SHALL delegate media control events to Flutter AudioService instead of handling them independently
2. WHEN a media control event is received by MusicPlayerService, THE system SHALL forward it to Flutter via a reliable communication channel
3. THE just_audio_background plugin SHALL NOT intercept next/previous commands when FM_Mode is active
4. WHEN FM_Mode is active, THE AudioService SHALL override the default playlist-based skip behavior

### Requirement 3: 后台通信可靠性

**User Story:** As a user, I want media controls to work reliably when the app is in background, so that I have a seamless listening experience.

#### Acceptance Criteria

1. WHEN the app enters background on Android, THE MusicPlayerService SHALL maintain a reliable communication channel with Flutter
2. WHEN the app enters background on iOS, THE AppDelegate SHALL ensure MethodChannel remains functional for control events
3. IF the MainActivity is destroyed on Android, THEN THE MusicPlayerService SHALL still be able to trigger Flutter callbacks
4. WHEN a control event fails to reach Flutter, THE system SHALL retry or queue the event for later delivery

### Requirement 4: FM 模式状态同步

**User Story:** As a user, I want the system to remember my FM mode state, so that background controls behave correctly after app restart.

#### Acceptance Criteria

1. WHEN the app restarts in FM_Mode, THE AudioService SHALL restore the FM_Mode state before processing any media control events
2. THE MusicPlayerService SHALL be aware of the current FM_Mode state to provide appropriate UI feedback
3. WHEN FM_Mode is active, THE Control_Center SHALL disable or hide the previous track button on supported platforms

### Requirement 5: 播放列表隔离

**User Story:** As a developer, I want FM mode to be isolated from the regular playlist mechanism, so that skip commands don't trigger playlist-based behavior.

#### Acceptance Criteria

1. WHEN FM_Mode is active, THE AudioService SHALL use a single-track audio source instead of a playlist
2. WHEN the user skips to next in FM_Mode, THE AudioService SHALL replace the current audio source with a new one from the server
3. THE just_audio player SHALL NOT attempt to skip within a playlist when FM_Mode is active
4. WHEN exiting FM_Mode, THE AudioService SHALL restore the previous playlist if available
