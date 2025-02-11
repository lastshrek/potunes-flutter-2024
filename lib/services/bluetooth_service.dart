import 'package:get/get.dart';
import 'package:flutter/services.dart';
import './audio_service.dart';

class BluetoothService extends GetxService {
  static BluetoothService get to => Get.find();

  // 用于接收蓝牙媒体按钮事件的通道
  static const platform = MethodChannel('pink.poche.potunes/media_button');

  // 音频服务实例
  final AudioService _audioService = AudioService.to;

  // 标记服务是否已初始化
  final _isInitialized = false.obs;
  bool get isInitialized => _isInitialized.value;

  @override
  void onInit() {
    super.onInit();
    _initializeBluetoothControls();
  }

  Future<void> _initializeBluetoothControls() async {
    try {
      // 设置方法调用处理器
      platform.setMethodCallHandler(_handleMediaButton);
      _isInitialized.value = true;
    } catch (e) {
      print('Error initializing bluetooth controls: $e');
    }
  }

  // 处理从原生平台接收到的媒体按钮事件
  Future<void> _handleMediaButton(MethodCall call) async {
    switch (call.method) {
      case 'mediaButtonPlay':
        await _audioService.togglePlayPause();
        break;
      case 'mediaButtonPause':
        await _audioService.togglePlayPause();
        break;
      case 'mediaButtonPlayPause':
        await _audioService.togglePlayPause();
        break;
      case 'mediaButtonNext':
        await _audioService.next();
        break;
      case 'mediaButtonPrevious':
        await _audioService.previous();
        break;
      default:
        print('Unknown media button event: ${call.method}');
    }
  }

  // 清理资源
  @override
  void onClose() {
    platform.setMethodCallHandler(null);
    super.onClose();
  }
}
