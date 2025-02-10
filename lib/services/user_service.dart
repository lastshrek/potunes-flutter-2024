import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

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
        _token.value = token;
        _userData.value = json.decode(userDataStr);
        _isLoggedIn.value = true;
      }
    } catch (e) {
      print('Error loading user data: $e');
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
      _userData.value = userData;

      _isLoggedIn.value = true;

      print('=== Login Data Saved ===');
      print('Token: $token');
      print('User Data: $userData');
      print('Is Logged In: ${_isLoggedIn.value}');
    } catch (e) {
      print('Error saving user data: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    print('=== UserService.logout() called ===');
    try {
      final prefs = await SharedPreferences.getInstance();
      // 清除存储的用户数据
      await prefs.remove(_tokenKey);
      await prefs.remove(_userDataKey);

      // 重置状态
      _token.value = '';
      _userData.value = null;
      _isLoggedIn.value = false;

      print('=== Logout Successful ===');
      print('Token cleared: ${_token.value}');
      print('User data cleared: ${_userData.value}');
      print('Login status: ${_isLoggedIn.value}');
    } catch (e) {
      print('Error during logout: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> updateAvatar(String base64Image) async {
    try {
      // 直接更新本地数据
      final prefs = await SharedPreferences.getInstance();
      final currentData = _userData.value ?? {};
      currentData['avatar'] = base64Image;
      _userData.value = currentData;

      // 保存到本地存储
      await prefs.setString(_userDataKey, json.encode(currentData));
    } catch (e) {
      print('Error updating avatar: $e');
      rethrow;
    }
  }
}
