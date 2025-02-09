import 'package:get/get.dart';
import '../services/network_service.dart';
import '../utils/http/api_exception.dart';
import '../controllers/app_controller.dart';

abstract class BaseController extends GetxController {
  final NetworkService _networkService = NetworkService.instance;
  final _isNetworkReady = false.obs;
  final _error = RxnString();

  bool get isNetworkReady => _isNetworkReady.value;
  RxnString get error => _error;

  @override
  void onInit() {
    super.onInit();
    // 监听网络状态变化
    ever(Get.find<AppController>().isNetworkReady, _onNetworkStatusChanged);
    // 初始化时获取当前网络状态
    _isNetworkReady.value = NetworkService.hasNetworkPermission;
  }

  void _onNetworkStatusChanged(bool isReady) {
    print('Network status changed: $isReady');
    _isNetworkReady.value = isReady;
    if (isReady) {
      onNetworkReady();
    }
  }

  // 子类可以重写这个方法来处理网络就绪事件
  void onNetworkReady() {
    // 默认实现为空
  }

  Future<void> _checkNetworkPermission() async {
    try {
      final hasPermission = await _networkService.checkNetworkPermission();
      _isNetworkReady.value = hasPermission;
    } catch (e) {
      _error.value = e is ApiException ? e.message : e.toString();
    }
  }

  Future<void> retryConnection() async {
    try {
      await _networkService.resetNetworkPermission();
      await _checkNetworkPermission();
    } catch (e) {
      _error.value = e is ApiException ? e.message : e.toString();
    }
  }
}
