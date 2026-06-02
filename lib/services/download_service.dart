import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/error_reporter.dart';

class DownloadService extends GetxService {
  CancelToken? _cancelToken;

  Future<String> downloadApk({
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    _cancelToken = CancelToken();
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/poTunes-${DateTime.now().millisecondsSinceEpoch}.apk';

    final dio = Dio();
    await dio.download(
      url,
      filePath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress(received / total);
        }
      },
    );

    _cancelToken = null;
    return filePath;
  }

  void cancelDownload() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  Future<void> installApk(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('打开 APK 失败: ${result.message}');
    }
  }
}
