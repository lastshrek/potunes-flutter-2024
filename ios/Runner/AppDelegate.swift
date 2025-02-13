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
          
        case "controlCenterEvent":
          // 处理控制中心事件
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
    
    // 设置远程控制
    setupRemoteControl()
    
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
    
    // 启用所有命令
    commandCenter.playCommand.isEnabled = true
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.isEnabled = true
    
    // 播放命令
    commandCenter.playCommand.addTarget { [weak self] event in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "play"]) { result in
        if let error = result as? FlutterError {
          print("Error handling play command: \(error.message ?? "unknown error")")
        }
      }
      return .success
    }
    
    // 暂停命令
    commandCenter.pauseCommand.addTarget { [weak self] event in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "pause"]) { result in
        if let error = result as? FlutterError {
          print("Error handling pause command: \(error.message ?? "unknown error")")
        }
      }
      return .success
    }
    
    // 下一首命令
    commandCenter.nextTrackCommand.addTarget { [weak self] event in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "next"]) { result in
        if let error = result as? FlutterError {
          print("Error handling next command: \(error.message ?? "unknown error")")
        }
      }
      return .success
    }
    
    // 上一首命令
    commandCenter.previousTrackCommand.addTarget { [weak self] event in
      self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: ["action": "previous"]) { result in
        if let error = result as? FlutterError {
          print("Error handling previous command: \(error.message ?? "unknown error")")
        }
      }
      return .success
    }
    
    // 进度控制
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      if let event = event as? MPChangePlaybackPositionCommandEvent {
        self?.methodChannel?.invokeMethod("controlCenterEvent", arguments: [
          "action": "seek",
          "position": event.positionTime
        ]) { result in
          if let error = result as? FlutterError {
            print("Error handling seek command: \(error.message ?? "unknown error")")
          }
        }
      }
      return .success
    }
  }
  
  private func updateNowPlayingInfo(
    title: String,
    artist: String,
    duration: Double,
    currentTime: Double,
    isPlaying: Bool,
    coverUrl: String? = nil
  ) {
    print("Updating now playing info - Title: \(title), Artist: \(artist)")
    
    // 更新基本信息
    nowPlayingInfo[MPMediaItemPropertyTitle] = title
    nowPlayingInfo[MPMediaItemPropertyArtist] = artist
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    
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
    print("Updated now playing info without artwork")
  }
}
