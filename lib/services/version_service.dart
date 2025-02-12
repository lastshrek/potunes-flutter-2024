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

        // 打印完整的 responseData
        print('Full response data: $responseData');

        final newVersion = responseData['a_version'] as String;
        final downloadUrl = responseData['a_url'] as String;
        // 使用正确的字段名 updateText
        final dynamic rawUpdateText = responseData['updateText'];
        print('Raw updateText: $rawUpdateText (type: ${rawUpdateText.runtimeType})');

        final updateText = rawUpdateText?.toString() ?? '暂无更新说明';

        print('Server version: $newVersion');
        print('Download URL: $downloadUrl');
        print('Processed update text: $updateText');

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
            updateText: updateText,
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
    required String updateText,
  }) async {
    try {
      if (!Get.isDialogOpen! && Get.context != null) {
        await Get.dialog(
          WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              backgroundColor: Colors.black87,
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '有新版本 $version 可供下载',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '更新内容：',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      updateText.replaceAll('\\n', '\n'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
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

                      if (Platform.isAndroid) {
                        final Uri uri = Uri.parse(url);
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalNonBrowserApplication,
                        ).then((bool result) {
                          if (!result) {
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        });
                      }
                    } catch (e) {
                      print('Error launching URL: $e');
                      if (Get.context != null) {
                        Get.snackbar(
                          '错误',
                          '打开下载链接失败',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.black87,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 2),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
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
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.5),
        );
      } else {
        print('Dialog cannot be shown: no valid context or dialog already open');
      }
    } catch (e) {
      print('Error showing dialog: $e');
    }
  }
}
