# 需求文档：Android 后台播放稳定性

## 简介

本功能旨在解决音乐播放器服务在后台播放时被 Android 系统杀死的关键问题。解决方案包括实现正确的前台服务配置、WakeLock 管理、电池优化豁免以及健壮的服务生命周期管理，以确保即使应用在后台也能不间断地播放音乐。

## 术语表

- **前台服务 (Foreground_Service)**: 显示持久通知且优先级高于后台服务的 Android 服务
- **WakeLock**: 防止设备 CPU 进入睡眠模式的机制
- **电池优化 (Battery_Optimization)**: Android 系统限制后台活动以节省电量的功能
- **通知频道 (Notification_Channel)**: Android 8.0+ 用于组织通知的要求
- **服务生命周期 (Service_Lifecycle)**: 服务经历的状态序列（onCreate、onStartCommand、onDestroy）
- **MediaSession**: Android 管理媒体播放和控制的框架
- **音频焦点 (Audio_Focus)**: Android 管理应用间音频播放优先级的机制

## 需求

### 需求 1：实现健壮的前台服务

**用户故事：** 作为音乐应用用户，我希望应用能够保持后台播放而不被系统杀死，以便我可以持续收听音乐。

#### 验收标准

1. WHEN 用户开始播放音乐时，THE Foreground_Service SHALL 启动并显示持久通知
2. WHEN 前台服务运行时，THE Foreground_Service SHALL 显示用户无法关闭的通知
3. WHEN 用户停止播放音乐时，THE Foreground_Service SHALL 停止服务并移除通知
4. IF 应用被系统杀死，THEN THE Foreground_Service SHALL 在音乐播放恢复时自动重启
5. WHEN 通知显示时，THE Foreground_Service SHALL 显示当前曲目信息（标题、艺术家、封面）

### 需求 2：管理 WakeLock 以保持 CPU 可用

**用户故事：** 作为音乐应用用户，我希望设备 CPU 在后台播放期间保持活跃，以便音乐不会卡顿或意外停止。

#### 验收标准

1. WHEN 音乐播放开始时，THE WakeLock SHALL 获取部分唤醒锁以保持 CPU 活跃
2. WHEN 音乐播放停止时，THE WakeLock SHALL 释放唤醒锁以允许设备休眠
3. WHILE WakeLock 被持有时，THE WakeLock SHALL 防止设备进入深度睡眠模式
4. IF WakeLock 已被持有，THEN THE WakeLock SHALL 不获取重复的唤醒锁
5. WHEN 应用被销毁时，THE WakeLock SHALL 释放所有持有的唤醒锁

### 需求 3：请求电池优化豁免

**用户故事：** 作为音乐应用用户，我希望系统不限制我的应用后台活动，以便播放能够不间断地继续。

#### 验收标准

1. WHEN 应用首次运行时，THE Battery_Optimization SHALL 提示用户将应用从电池优化中豁免
2. WHEN 用户授予豁免时，THE Battery_Optimization SHALL 将应用添加到电池优化白名单
3. WHILE 应用在白名单中时，THE Battery_Optimization SHALL 不限制后台服务执行
4. IF 用户拒绝豁免，THEN THE Battery_Optimization SHALL 继续定期尝试请求
5. WHEN 检查豁免状态时，THE Battery_Optimization SHALL 验证应用确实在白名单中

### 需求 4：配置正确的通知频道

**用户故事：** 作为音乐应用用户，我希望通知能够正确配置用于音乐播放，以便它不会干扰其他通知。

#### 验收标准

1. WHEN 应用在 Android 8.0+ 上运行时，THE Notification_Channel SHALL 为音乐播放创建通知频道
2. WHEN 通知频道创建时，THE Notification_Channel SHALL 设置重要性为 LOW 以减少干扰
3. WHEN 通知显示时，THE Notification_Channel SHALL 包含播放控制（播放、暂停、下一首、上一首）
4. WHEN 用户点击通知时，THE Notification_Channel SHALL 打开应用到正在播放界面
5. WHEN 通知更新时，THE Notification_Channel SHALL 反映当前播放状态和曲目信息

### 需求 5：实现服务重启机制

**用户故事：** 作为音乐应用用户，我希望服务在被杀死后能够自动重启，以便播放能够无缝恢复。

#### 验收标准

1. WHEN 服务意外销毁时，THE Service_Lifecycle SHALL 返回 START_STICKY 以启用自动重启
2. WHEN 服务重启时，THE Service_Lifecycle SHALL 从持久存储恢复之前的播放状态
3. WHEN 服务重启时，THE Service_Lifecycle SHALL 从保存的位置恢复播放
4. IF 播放状态无法恢复，THEN THE Service_Lifecycle SHALL 记录错误并尝试恢复
5. WHEN 服务重启时，THE Service_Lifecycle SHALL 重新建立前台通知

### 需求 6：实现 MediaSession 以进行系统集成

**用户故事：** 作为音乐应用用户，我希望系统能够识别我的应用为媒体播放器，以便系统控制能够正常工作。

#### 验收标准

1. WHEN 音乐播放开始时，THE MediaSession SHALL 创建并激活 MediaSession
2. WHILE MediaSession 活跃时，THE MediaSession SHALL 响应系统媒体控制（耳机按钮、锁屏控制）
3. WHEN 用户使用系统控制时，THE MediaSession SHALL 执行相应的播放操作
4. WHILE MediaSession 活跃时，THE MediaSession SHALL 在锁屏上显示元数据
5. WHEN 音乐播放停止时，THE MediaSession SHALL 释放 MediaSession

### 需求 7：正确处理音频焦点

**用户故事：** 作为音乐应用用户，我希望应用能够正确处理音频焦点，以便播放能够与其他音频应用良好协调。

#### 验收标准

1. WHEN 应用请求音频焦点时，THE Audio_Focus SHALL 检查是否有其他应用正在播放音频
2. WHEN 音频焦点被授予时，THE Audio_Focus SHALL 开始或恢复播放
3. WHEN 音频焦点暂时丢失时，THE Audio_Focus SHALL 暂停播放
4. WHEN 音频焦点永久丢失时，THE Audio_Focus SHALL 停止播放并释放资源
5. WHEN 音频焦点恢复时，THE Audio_Focus SHALL 从保存的位置恢复播放

### 需求 8：声明所需权限

**用户故事：** 作为音乐应用开发者，我希望所有必要的权限都在清单中声明，以便应用能够在所有 Android 版本上正常运行。

#### 验收标准

1. THE AndroidManifest SHALL 声明 FOREGROUND_SERVICE 权限
2. THE AndroidManifest SHALL 为 Android 12+ 声明 FOREGROUND_SERVICE_MEDIA_PLAYBACK 权限
3. THE AndroidManifest SHALL 声明 WAKE_LOCK 权限以支持唤醒锁功能
4. THE AndroidManifest SHALL 声明 REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 权限
5. THE AndroidManifest SHALL 声明 RECEIVE_BOOT_COMPLETED 权限以支持开机启动

### 需求 9：实现优雅降级

**用户故事：** 作为音乐应用用户，我希望即使某些功能不可用，应用也能正常工作，以便播放是可靠的。

#### 验收标准

1. IF 电池优化豁免不可用，THEN THE System SHALL 继续以降低的可靠性运行
2. IF WakeLock 无法获取，THEN THE System SHALL 记录警告并继续播放
3. IF MediaSession 不可用，THEN THE System SHALL 继续使用基本播放控制
4. WHEN 服务管理发生错误时，THE System SHALL 记录错误并尝试恢复
5. WHEN 服务遇到不可恢复的错误时，THE System SHALL 通知用户并优雅停止
