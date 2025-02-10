import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class VersionService extends GetxService {
  final Dio _dio;

  VersionService(this._dio);

  Future<void> initCheckVersion() async {
    await Future.delayed(const Duration(seconds: 1));
    await checkVersion();
  }

  Future<void> checkVersion() async {
    // 只在 Android 平台检查更新
    if (!Platform.isAndroid) {
      print('Skip version check: not Android platform');
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('Current app version: $currentVersion');

      final response = await _dio.get(
        ApiConfig.version,
        queryParameters: {'platform': 'android'},
      );

      print('Version check response: ${response.data}');

      if (response.statusCode == ApiConfig.successCode) {
        final responseData = response.data['data'] as Map<String, dynamic>;
        final newVersion = responseData['a_version'] as String;
        final downloadUrl = responseData['a_url'] as String;

        print('Server version: $newVersion');
        print('Download URL: $downloadUrl');

        // 验证 URL 格式
        if (downloadUrl.isEmpty) {
          print('Download URL is empty');
          return;
        }

        try {
          final uri = Uri.parse(downloadUrl);
          if (!uri.hasScheme || !uri.hasAuthority) {
            print('Invalid URL format: $downloadUrl');
            return;
          }
        } catch (e) {
          print('Error parsing URL: $e');
          return;
        }

        if (_shouldUpdate(currentVersion, newVersion)) {
          print('Update needed: $currentVersion -> $newVersion');
          await _showUpdateDialog(
            version: newVersion,
            url: downloadUrl,
          );
        } else {
          print('No update needed');
        }
      }
    } catch (err) {
      // 版本检查失败不影响应用使用
      print('Version check failed: $err');
    }
  }

  bool _shouldUpdate(String currentVersion, String newVersion) {
    try {
      // 分割版本号并转换为数字数组
      final List<int> current = currentVersion.split('.').map((e) => int.parse(e.trim())).toList();
      final List<int> latest = newVersion.split('.').map((e) => int.parse(e.trim())).toList();

      // 确保两个版本号都有相同的段数
      while (current.length < latest.length) current.add(0);
      while (latest.length < current.length) latest.add(0);

      // 从高位到低位比较每一段
      for (int i = 0; i < current.length; i++) {
        if (latest[i] > current[i]) return true; // 需要更新
        if (latest[i] < current[i]) return false; // 不需要更新
      }
      return false; // 版本相同，不需要更新
    } catch (e) {
      print('Version comparison error: $e');
      print('Current version: $currentVersion');
      print('New version: $newVersion');
      return false; // 出错时保守处理，返回不需要更新
    }
  }

  Future<void> _showUpdateDialog({
    required String version,
    required String url,
  }) async {
    try {
      if (!Get.isDialogOpen! && Get.context != null) {
        await Get.dialog(
          WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              backgroundColor: Colors.black87, // 设置背景色
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Text(
                '发现新版本',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                '有新版本 $version 可供下载，是否更新？',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text(
                    '稍后再说',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      Get.back();
                      print('Attempting to launch URL: $url');
                      final Uri uri = Uri.parse(url);

                      if (await canLaunchUrl(uri)) {
                        print('Launching URL: $uri');
                        final result = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        print('Launch result: $result');
                      } else {
                        print('Cannot launch URL: $uri');
                        if (Get.context != null) {
                          Get.snackbar(
                            '错误',
                            '无法打开下载链接',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      }
                    } catch (e) {
                      print('Error launching URL: $e');
                      if (Get.context != null) {
                        Get.snackbar(
                          '错误',
                          '打开下载链接失败',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFDA5597), // 粉色背景
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    '立即更新',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.5), // 设置遮罩层颜色
        );
      } else {
        print('Dialog cannot be shown: no valid context or dialog already open');
      }
    } catch (e) {
      print('Error showing dialog: $e');
    }
  }
}
