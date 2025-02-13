import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/network_service.dart';

class UserService extends GetxService {
  static UserService get to => Get.find();

  static const String _tokenKey = 'user_token';
  static const String _userDataKey = 'user_data';

  final _isLoggedIn = false.obs;
  final _token = ''.obs;
  final _userId = 0.obs;
  final _userData = Rxn<Map<String, dynamic>>();

  bool get isLoggedIn => _isLoggedIn.value;
  String get token => _token.value;
  int get userId => _userId.value;
  Map<String, dynamic>? get userData => _userData.value;

  final _dio = Dio();

  Future<UserService> init() async {
    await _loadUserData();
    return this;
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userDataStr = prefs.getString(_userDataKey);

      if (token != null && userDataStr != null) {
        try {
          final userData = json.decode(userDataStr) as Map<String, dynamic>;

          // 设置所有状态
          _token.value = token;
          _userData.value = userData;
          _userId.value = userData['id'] ?? 0;
          _isLoggedIn.value = true;
        } catch (parseError) {
          await _clearUserData();
        }
      }
    } catch (e) {
      await _clearUserData();
    }
  }

  Future<void> saveLoginData(Map<String, dynamic> loginResponse) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = loginResponse['data'] as Map<String, dynamic>;

      // 保存 token
      final token = data['token'] as String;
      await prefs.setString(_tokenKey, token);
      _token.value = token;

      // 保存用户数据
      final userData = data['user'] as Map<String, dynamic>;
      await prefs.setString(_userDataKey, json.encode(userData));

      // 更新所有状态
      _userData.value = userData;
      _userId.value = userData['id'] ?? 0;
      _isLoggedIn.value = true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userDataKey);

      // 重置所有状态
      _token.value = '';
      _userData.value = null;
      _userId.value = 0;
      _isLoggedIn.value = false;
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  Future<void> logout() async {
    await _clearUserData();
  }

  Future<void> updateAvatar(String base64Image) async {
    try {
      // 调用接口更新头像
      final networkService = NetworkService.instance;
      final success = await networkService.updateAvatar(base64Image);

      if (success) {
        // 更新本地数据
        final prefs = await SharedPreferences.getInstance();
        final currentData = _userData.value ?? {};
        currentData['avatar'] = base64Image;
        _userData.value = currentData;

        // 保存到本地存储
        await prefs.setString(_userDataKey, json.encode(currentData));
      } else {
        throw '更新头像失败';
      }
    } catch (e) {
      print('Error updating avatar: $e');
      rethrow;
    }
  }

  void updateUserData(Map<String, dynamic> newData) {
    _userData.value = newData;
    // 保存到本地存储
    _saveUserData();
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userData.value != null) {
      await prefs.setString('user_data', jsonEncode(_userData.value));
    }
  }
}
