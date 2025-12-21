import Flutter
import UIKit
import AVFoundation
import ActivityKit
import SwiftUI
import MediaPlayer

// 使用正确的 Bundle ID
private let channelName = "im.coinchat.treehole/audio_control"

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?
  private var nowPlayingInfo = [String: Any]()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      // 使用正确的 channel 名称
      methodChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )
      
      // 处理来自 Flutter 的更新请求
      methodChannel?.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else { return }
        
        switch call.method {
        case "updateNowPlaying":
          if let args = call.arguments as? [String: Any],
             let title = args["title"] as? String,
             let artist = args["artist"] as? String,
             let duration = args["duration"] as? Double,
             let currentTime = args["currentTime"] as? Double,
             let isPlaying = args["isPlaying"] as? Bool,
             let coverUrl = args["coverUrl"] as? String {
            
            self.updateNowPlayingInfo(
              title: title,
              artist: artist,
              duration: duration,
              currentTime: currentTime,
              isPlaying: isPlaying,
              coverUrl: coverUrl
            )
            result(nil)
          } else {
            result(FlutterError(code: "INVALID_ARGUMENTS", 
                              message: "Invalid arguments for updateNowPlaying", 
                              details: nil))
          }
          
        case "setupRemoteControl":
          // 不再需要手动设置远程控制，让 just_audio_background 完全管理
          result(nil)
          
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    // 配置音频会话
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .default,
        policy: .longFormAudio,
        options: [.allowAirPlay, .allowBluetooth]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to set audio session category. Error: \(error)")
    }
    
    // 设置初始播放信息
    setupInitialNowPlaying()
    
    if #available(iOS 16.2, *) {
      // 注册活动类型
      do {
        let initialState = MusicAttributes.MusicState(
          title: "",
          artist: "",
          coverUrl: "",
          isPlaying: false
        )
        
        if let activity = try? Activity<MusicAttributes>.request(
          attributes: MusicAttributes(),
          contentState: initialState,
          pushType: nil
        ) {
          print("Requested Live Activity with ID: \(activity.id)")
        }
      } catch {
        print("Error requesting Live Activity: \(error.localizedDescription)")
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    
    // 设置远程控制命令
    setupRemoteControl()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupInitialNowPlaying() {
    // 设置初始播放信息
    nowPlayingInfo[MPMediaItemPropertyTitle] = "未在播放"
    nowPlayingInfo[MPMediaItemPropertyArtist] = "PO Tunes"
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
    
    // 更新控制中心
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }
  
  private func setupRemoteControl() {
    let commandCenter = MPRemoteCommandCenter.shared()
    
    // 启用所有命令并添加处理器
    // 这是 iOS 控制中心显示按钮的必要条件
    
    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { [weak self] _ in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "play"])
      return .success
    }
    
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "pause"])
      return .success
    }
    
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "togglePlayPause"])
      return .success
    }
    
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "next"])
      return .success
    }
    
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "previous"])
      return .success
    }
    
    commandCenter.changePlaybackPositionCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: [
        "action": "seek",
        "position": positionEvent.positionTime
      ])
      return .success
    }
    
    print("Remote control commands configured")
  }
  
  private var remoteControlConfigured = false
  
  private func updateNowPlayingInfo(
    title: String,
    artist: String,
    duration: Double,
    currentTime: Double,
    isPlaying: Bool,
    coverUrl: String? = nil
  ) {
    print("Updating now playing info - Title: \(title), Artist: \(artist)")
    
    // 只在第一次时配置远程控制命令
    if !remoteControlConfigured {
      configureRemoteCommands()
      remoteControlConfigured = true
    }
    
    // 更新基本信息
    nowPlayingInfo[MPMediaItemPropertyTitle] = title
    nowPlayingInfo[MPMediaItemPropertyArtist] = artist
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    
    // 设置媒体类型为音频
    nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    
    // 设置是否支持实时播放（非直播）
    nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
    
    // 设置播放队列信息，告诉系统有多首歌曲
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = 0
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = 2
    
    // 如果有封面URL，异步加载封面图
    if let coverUrlString = coverUrl, let url = URL(string: coverUrlString) {
      URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
        guard let self = self,
              let imageData = data,
              let image = UIImage(data: imageData) else {
          print("Failed to load cover image")
          return
        }
        
        // 在主线程更新控制中心
        DispatchQueue.main.async {
          let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
          self.nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
          MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
          print("Updated now playing info with artwork")
        }
      }.resume()
    }
    
    // 立即更新控制中心（不等待封面加载）
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    
    let commandCenter = MPRemoteCommandCenter.shared()
    print("Now playing updated - nextTrackCommand.isEnabled: \(commandCenter.nextTrackCommand.isEnabled)")
  }
  
  private func configureRemoteCommands() {
    let commandCenter = MPRemoteCommandCenter.shared()
    
    // 先移除所有现有的 target
    commandCenter.playCommand.removeTarget(nil)
    commandCenter.pauseCommand.removeTarget(nil)
    commandCenter.togglePlayPauseCommand.removeTarget(nil)
    commandCenter.nextTrackCommand.removeTarget(nil)
    commandCenter.previousTrackCommand.removeTarget(nil)
    commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    
    // 启用并添加 target
    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { [weak self] _ in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "play"])
      return .success
    }
    
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "pause"])
      return .success
    }
    
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "togglePlayPause"])
      return .success
    }
    
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      print("Next track command received")
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "next"])
      return .success
    }
    
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      print("Previous track command received")
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "previous"])
      return .success
    }
    
    commandCenter.changePlaybackPositionCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: [
        "action": "seek",
        "position": positionEvent.positionTime
      ])
      return .success
    }
    
    print("Remote commands configured - nextTrackCommand.isEnabled: \(commandCenter.nextTrackCommand.isEnabled)")
  }
}
