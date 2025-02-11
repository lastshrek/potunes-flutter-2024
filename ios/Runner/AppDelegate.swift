import Flutter
import UIKit
import AVFoundation
import ActivityKit
import SwiftUI

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
}
