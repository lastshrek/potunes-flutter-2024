import 'dart:async';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/network_service.dart';
import '../utils/http/api_exception.dart';

abstract class BaseController extends GetxController {
  final NetworkService _networkService = NetworkService.instance;
  final _isNetworkReady = false.obs;
  final _error = RxnString();
  final _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool get isNetworkReady => _isNetworkReady.value;
  RxnString get error => _error;

  @override
  void onInit() {
    super.onInit();
    print('${runtimeType.toString()} onInit');
    // 加载缓存数据
    loadCachedData();
    // 初始化网络状态监听
    _initNetworkMonitoring();
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  Future<void> _initNetworkMonitoring() async {
    // 获取初始网络状态
    final connectivityResult = await _connectivity.checkConnectivity();
    _handleConnectivityChange(connectivityResult);

    // 监听网络状态变化
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _handleConnectivityChange(result);
    });
  }

  void _handleConnectivityChange(ConnectivityResult result) async {
    print('${runtimeType.toString()} connectivity changed: $result');
    if (result == ConnectivityResult.none) {
      _isNetworkReady.value = false;
      _error.value = '网络连接已断开';
    } else {
      try {
        // 检查网络权限和连接性
        final hasPermission = await _networkService.checkNetworkPermission();
        _isNetworkReady.value = hasPermission;
        if (hasPermission) {
          _error.value = null;
          refreshData();
        }
      } catch (e) {
        _error.value = e is ApiException ? e.message : e.toString();
      }
    }
  }

  // 检查网络权限
  Future<void> checkNetworkPermission() async {
    try {
      final hasPermission = await _networkService.checkNetworkPermission();
      _isNetworkReady.value = hasPermission;
      if (hasPermission) {
        _error.value = null;
        refreshData();
      }
    } catch (e) {
      _error.value = e is ApiException ? e.message : e.toString();
    }
  }

  // 重试连接
  Future<void> retryConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _error.value = '请检查网络连接';
        return;
      }
      await _networkService.resetNetworkPermission();
      await checkNetworkPermission();
    } catch (e) {
      _error.value = e is ApiException ? e.message : e.toString();
    }
  }

  // 刷新数据的抽象方法
  Future<void> refreshData();

  // 加载缓存数据的抽象方法
  Future<void> loadCachedData();
}
