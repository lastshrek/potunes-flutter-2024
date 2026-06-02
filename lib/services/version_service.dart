import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/api_config.dart';
import '../utils/error_reporter.dart';
import 'download_service.dart';

class VersionService extends GetxService {
  final Dio _dio;
  final DownloadService _downloadService;

  VersionService(this._dio, this._downloadService);

  Future<void> initCheckVersion() async {
    await Future.delayed(const Duration(seconds: 1));
    await checkVersion();
  }

  Future<void> checkVersion() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(
        ApiConfig.version,
        queryParameters: {'platform': 'android'},
      );

      if (response.statusCode == ApiConfig.successCode) {
        final responseData = response.data['data'] as Map<String, dynamic>;
        final newVersion = responseData['a_version'] as String;
        final downloadUrl = responseData['a_url'] as String;
        final dynamic rawUpdateText = responseData['updateText'];
        final updateText = rawUpdateText?.toString() ?? '暂无更新说明';

        if (downloadUrl.isEmpty) {
          return;
        }

        try {
          final uri = Uri.parse(downloadUrl);
          if (!uri.hasScheme || !uri.hasAuthority) {
            return;
          }
        } catch (e) {
          ErrorReporter.showError(e);
          return;
        }

        if (_shouldUpdate(currentVersion, newVersion)) {
          await _showUpdateDialog(
            version: newVersion,
            url: downloadUrl,
            updateText: updateText,
          );
        }
      }
    } catch (e) {
      ErrorReporter.showError(e);
    }
  }

  bool _shouldUpdate(String currentVersion, String newVersion) {
    try {
      final List<int> current = currentVersion.split('.').map((e) => int.parse(e.trim())).toList();
      final List<int> latest = newVersion.split('.').map((e) => int.parse(e.trim())).toList();

      while (current.length < latest.length) current.add(0);
      while (latest.length < current.length) latest.add(0);

      for (int i = 0; i < current.length; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      return false;
    } catch (e) {
      ErrorReporter.showError(e);
      return false;
    }
  }

  Future<void> _startDownloadAndInstall(String url) async {
    try {
      await Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: _DownloadProgressDialog(),
        ),
        barrierDismissible: false,
      );

      final controller = Get.find<_DownloadProgressController>();
      controller.state.value = _DownloadState.downloading;

      final filePath = await _downloadService.downloadApk(
        url: url,
        onProgress: (progress) {
          controller.progress.value = progress;
        },
      );

      controller.state.value = _DownloadState.installing;
      await _downloadService.installApk(filePath);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }
      ErrorReporter.showError(e);
      if (Get.context != null) {
        Get.snackbar(
          '更新失败',
          '下载或安装过程中发生错误',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.black87,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (Get.isDialogOpen!) {
        Get.back();
      }
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
                  onPressed: () {
                    Get.back();
                    _startDownloadAndInstall(url);
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
        ErrorReporter.showError('Dialog cannot be shown: no valid context or dialog already open');
      }
    } catch (e) {
      ErrorReporter.showError(e);
    }
  }
}

enum _DownloadState { downloading, installing }

class _DownloadProgressController extends GetxController {
  final progress = 0.0.obs;
  final state = _DownloadState.downloading.obs;
}

class _DownloadProgressDialog extends StatelessWidget {
  _DownloadProgressDialog() {
    Get.put(_DownloadProgressController(), permanent: false);
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_DownloadProgressController>(
      builder: (controller) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  if (controller.state.value == _DownloadState.installing) {
                    return const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 48,
                    );
                  }
                  return const Icon(
                    Icons.file_download_outlined,
                    color: Colors.white,
                    size: 48,
                  );
                }),
                const SizedBox(height: 16),
                Obx(() => Text(
                  controller.state.value == _DownloadState.downloading
                      ? '正在下载更新...'
                      : '正在安装...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                )),
                const SizedBox(height: 8),
                Obx(() {
                  if (controller.state.value == _DownloadState.installing) {
                    return const Text(
                      '请等待安装完成',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    );
                  }
                  final pct = (controller.progress.value * 100).toStringAsFixed(1);
                  return Text(
                    '$pct%',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  );
                }),
                const SizedBox(height: 16),
                Obx(() {
                  if (controller.state.value == _DownloadState.installing) {
                    return const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: controller.progress.value,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
