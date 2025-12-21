# Implementation Plan: FM Mode Background Next Track Fix

## Overview

本实现计划将修复 FM 模式下后台切歌的问题。主要工作包括：移除 MediaSession 冲突、在 Flutter 端拦截播放事件、简化原生服务。

## Tasks

- [x] 1. 修改 Flutter AudioService 拦截播放事件
  - [x] 1.1 添加 processingStateStream 监听器处理 FM 模式播放完成
    - 在 `_setupPlayerListeners()` 中添加 `processingStateStream` 监听
    - 当状态为 `ProcessingState.completed` 且 FM 模式激活时，调用 `playFMTrack()`
    - _Requirements: 1.1, 2.4_
  - [x] 1.2 修改 onInit 中的 MethodChannel 控制事件处理器
    - 保留 `case 'next'` 处理逻辑（FM 模式下调用 playFMTrack）
    - 移除 `case 'previous'` 的处理逻辑（FM 模式不支持上一首）
    - 保留 `case 'play'`、`case 'pause'`、`case 'seek'` 的处理
    - _Requirements: 2.1, 2.2_
  - [x] 1.3 编写 FM 模式切歌行为的单元测试
    - 测试 FM 模式下 processingState 完成时触发 playFMTrack
    - **Property 5: FM Mode Skip Behavior Override**
    - **Validates: Requirements 2.4**

- [x] 2. 修改 playFMTrack 方法增强错误处理
  - [x] 2.1 改进 playFMTrack 的错误处理逻辑
    - 网络失败时不 rethrow，保持当前播放状态
    - 显示用户友好的错误提示
    - _Requirements: 1.4_
  - [x] 2.2 添加防重复调用保护
    - 添加 `_isLoadingFMTrack` 标志防止并发请求
    - _Requirements: 1.1_
  - [ ]* 2.3 编写错误处理的单元测试
    - 测试网络失败时当前播放状态保持不变
    - _Requirements: 1.4_

- [x] 3. 修改 Android MusicPlayerService 移除 MediaSession
  - [x] 3.1 移除 MusicPlayerService 中的 MediaSession 创建和回调
    - 删除 `createMediaSession()` 方法
    - 删除 `MediaSessionCompat` 相关代码
    - 保留通知更新和 WakeLock 管理
    - _Requirements: 2.1, 2.3_
  - [x] 3.2 简化 handleNext/handlePrevious 方法
    - 移除 `sendToFlutter` 调用（由 just_audio_background 处理）
    - 或完全移除这些方法
    - _Requirements: 2.2_
  - [x] 3.3 更新 NotificationController 移除 MediaSession 依赖
    - 修改 `buildNotification` 方法不再需要 MediaSession 参数
    - _Requirements: 2.1_

- [x] 4. 修改 iOS AppDelegate 移除远程控制处理
  - [x] 4.1 移除 setupRemoteControl 中的命令处理
    - 删除 `nextTrackCommand`、`previousTrackCommand` 的 target 处理
    - 保留 `updateNowPlayingInfo` 方法
    - _Requirements: 2.1, 2.3_
  - [x] 4.2 简化 MethodChannel 处理器
    - 移除 `controlCenterEvent` 的处理（由 just_audio_background 处理）
    - 保留 `updateNowPlaying` 的处理
    - _Requirements: 2.2_

- [x] 5. Checkpoint - 验证基本功能
  - 确保所有测试通过，在真机上测试后台切歌功能
  - 如有问题请告知

- [-] 6. 优化 FM 模式状态管理
  - [-] 6.1 确保 FM 模式状态在 _loadLastState 中正确恢复
    - 验证 `_isFMMode.value` 在应用重启后正确恢复
    - _Requirements: 4.1_
  - [ ] 6.2 编写 FM 模式状态持久化的属性测试
    - **Property 4: FM Mode State Persistence Round Trip**
    - **Validates: Requirements 4.1**

- [ ] 7. 添加 FM 模式下禁用上一首按钮的逻辑
  - [ ] 7.1 在 Android 通知中隐藏/禁用上一首按钮（FM 模式时）
    - 修改 NotificationController 根据 FM 模式状态显示/隐藏按钮
    - 需要从 Flutter 传递 FM 模式状态到原生端
    - _Requirements: 4.3_
  - [ ] 7.2 在 iOS 控制中心禁用上一首按钮（FM 模式时）
    - 修改 AppDelegate 根据 FM 模式状态设置 `previousTrackCommand.isEnabled`
    - _Requirements: 4.3_

- [ ] 8. Final Checkpoint - 完整功能验证
  - 确保所有测试通过
  - 在 Android 和 iOS 真机上测试完整功能
  - 如有问题请告知

## Notes

- All tasks are required for complete implementation
- 主要修改集中在 Flutter 端的 `audio_service.dart`
- Android 端需要修改 `MusicPlayerService.kt` 和 `NotificationController.kt`
- iOS 端需要修改 `AppDelegate.swift`
- 建议先完成 Task 1-4 进行基本功能验证，再进行 Task 6-7 的优化
