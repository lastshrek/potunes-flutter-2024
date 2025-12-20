# 实现计划：Android 后台播放稳定性

## 概述

本实现计划将设计文档中的方案转化为具体的编码任务，按照增量开发的方式逐步实现 Android 后台播放稳定性功能。

## 任务

- [x] 1. 更新 AndroidManifest.xml 权限配置
  - 添加 REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 权限
  - 添加 RECEIVE_BOOT_COMPLETED 权限
  - 验证现有权限配置完整性
  - _需求: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 2. 实现 WakeLockManager 组件
  - [x] 2.1 创建 WakeLockManager.kt 文件
    - 实现 acquire() 方法获取部分唤醒锁
    - 实现 release() 方法释放唤醒锁
    - 实现 isHeld() 方法检查状态
    - 添加幂等性保护，防止重复获取
    - _需求: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ]* 2.2 编写 WakeLockManager 属性测试
    - **Property 2: WakeLock 与播放状态同步**
    - **Property 3: WakeLock 获取幂等性**
    - **验证: 需求 2.1, 2.2, 2.4**

- [x] 3. 实现 NotificationController 组件
  - [x] 3.1 创建 NotificationController.kt 文件
    - 实现 createNotificationChannel() 创建通知频道
    - 实现 buildNotification() 构建媒体通知
    - 添加播放控制按钮（播放/暂停、上一首、下一首）
    - 配置通知点击打开应用
    - _需求: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [ ]* 3.2 编写 NotificationController 属性测试
    - **Property 4: 通知内容与曲目信息一致**
    - **Property 5: 通知包含完整播放控制**
    - **验证: 需求 1.5, 4.3, 4.5**

- [x] 4. 实现 BatteryOptimizationHelper 组件
  - [x] 4.1 创建 BatteryOptimizationHelper.kt 文件
    - 实现 isIgnoringBatteryOptimizations() 检查豁免状态
    - 实现 requestIgnoreBatteryOptimizations() 请求豁免
    - _需求: 3.1, 3.2, 3.5_

- [x] 5. 增强 MusicPlayerService
  - [x] 5.1 添加 MediaSession 支持
    - 创建和配置 MediaSessionCompat
    - 实现 MediaSession.Callback 处理系统控制
    - 设置元数据更新逻辑
    - _需求: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 5.2 集成 WakeLockManager
    - 在服务启动时获取 WakeLock
    - 在服务停止时释放 WakeLock
    - _需求: 2.1, 2.2, 2.5_

  - [x] 5.3 集成 NotificationController
    - 使用 NotificationController 创建通知
    - 实现通知更新逻辑
    - _需求: 1.1, 1.2, 1.5_

  - [x] 5.4 实现音频焦点管理
    - 实现 requestAudioFocus() 请求音频焦点
    - 实现 abandonAudioFocus() 放弃音频焦点
    - 实现 OnAudioFocusChangeListener 处理焦点变化
    - _需求: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 5.5 实现服务重启机制
    - 确保 onStartCommand 返回 START_STICKY
    - 实现状态恢复逻辑
    - _需求: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ]* 5.6 编写 MusicPlayerService 属性测试
    - **Property 1: 服务状态与播放状态同步**
    - **Property 7: MediaSession 正确响应系统控制**
    - **Property 8: MediaSession 元数据与曲目同步**
    - **Property 9: 音频焦点变化时播放状态正确响应**
    - **验证: 需求 1.1, 1.3, 6.2, 6.3, 6.4, 7.2, 7.3, 7.4, 7.5**

- [x] 6. 检查点 - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户。

- [x] 7. 更新 MainActivity
  - [x] 7.1 添加电池优化请求逻辑
    - 在应用启动时检查电池优化状态
    - 如未豁免则请求用户授权
    - _需求: 3.1, 3.2, 3.4_

  - [x] 7.2 更新 MethodChannel 处理
    - 添加 updateNowPlaying 方法处理
    - 添加 checkBatteryOptimization 方法处理
    - _需求: 1.5, 3.5_

- [x] 8. 更新 Flutter 端 AudioService
  - [x] 8.1 更新前台服务管理方法
    - 增强 _startForegroundService() 传递曲目信息
    - 增强 _updateNowPlaying() 更新通知内容
    - _需求: 1.1, 1.5, 4.5_

  - [x] 8.2 添加电池优化相关方法
    - 实现 requestBatteryOptimization() 请求豁免
    - 实现 checkBatteryOptimization() 检查状态
    - _需求: 3.1, 3.5_

  - [x] 8.3 实现优雅降级逻辑
    - 添加错误处理和日志记录
    - 确保功能不可用时不影响基本播放
    - _需求: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [ ]* 8.4 编写 Flutter 端单元测试
    - 测试 MethodChannel 调用逻辑
    - 测试错误处理逻辑
    - **Property 10: 优雅降级保持基本功能**
    - **验证: 需求 9.1, 9.2, 9.3**

- [x] 9. 集成和连接
  - [x] 9.1 连接所有组件
    - 确保 Flutter 端和原生端正确通信
    - 验证播放状态同步
    - _需求: 1.1, 1.3, 1.5_

  - [x] 9.2 实现状态持久化
    - 保存播放状态到 SharedPreferences
    - 实现服务重启时的状态恢复
    - _需求: 5.2, 5.3_

  - [ ]* 9.3 编写集成测试
    - 测试完整的播放流程
    - 测试服务生命周期
    - **Property 6: 服务重启时状态完整恢复**
    - **验证: 需求 5.2, 5.3**

- [x] 10. 最终检查点 - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户。

## 备注

- 标记 `*` 的任务为可选任务，可跳过以加快 MVP 开发
- 每个任务都引用了具体的需求以便追溯
- 检查点确保增量验证
- 属性测试验证通用正确性属性
- 单元测试验证具体示例和边界情况
