import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:potunes/services/audio_service.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.battery_charging_full, color: Color(0xFFDA5597)),
              title: const Text('优化后台播放', style: TextStyle(color: Colors.white)),
              subtitle: const Text('允许应用在后台持续播放音乐', style: TextStyle(color: Colors.grey)),
              onTap: () {
                Get.find<AudioService>().requestBatteryOptimization();
              },
            ),
          ],
        ),
      ),
    );
  }
}
