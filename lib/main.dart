import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'screens/home_screen.dart';

import 'routes/app_pages.dart';
import 'bindings/initial_binding.dart';
import 'services/user_service.dart';
import 'controllers/app_controller.dart';
import 'services/version_service.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 just_audio_background
  await JustAudioBackground.init(
    androidNotificationChannelId: !Platform.isAndroid ? 'im.coinchat.treehole/audio_control' : 'pink.poche.potunes/audio_control',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
    androidStopForegroundOnPause: true,
    fastForwardInterval: const Duration(seconds: 10),
    rewindInterval: const Duration(seconds: 10),
    preloadArtwork: true,
    androidNotificationClickStartsActivity: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  // 初始化服务
  await initServices();

  // 只在 Android 上应用特定的系统 UI 配置
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    // 设置沉浸式导航栏
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge, // 启用边缘到边缘模式
    );
  }

  if (Platform.isAndroid) {
    setOptimalDisplayMode();
  }

  // 初始化版本检查服务
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
    receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
  ));

  final versionService = Get.put(VersionService(dio));

  // 设置图片缓存
  PaintingBinding.instance.imageCache.maximumSize = 100; // 限制缓存数量
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 限制缓存大小为50MB

  Get.put<RouteObserver<Route<dynamic>>>(RouteObserver<Route<dynamic>>());

  runApp(GetMaterialApp(
    title: '破破',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.dark(
        primary: Colors.deepPurple,
        secondary: const Color(0xFFDA5597),
        background: Colors.black,
        surface: Colors.black87,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      primaryColor: Colors.black,
      cardColor: Colors.black87,
      iconTheme: const IconThemeData(
        color: Color(0xFFDA5597), // Custom Pink
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFFDA5597), // Custom Pink
        circularTrackColor: Color(0x40DA5597), // Custom Pink with opacity
      ),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    ),
    builder: (context, child) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          body: child ?? const SizedBox.shrink(),
        ),
      );
    },
    home: FutureBuilder(
      future: Future.wait([
        Future.delayed(const Duration(milliseconds: 500)),
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const HomeScreen();
        }
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    ),
    defaultTransition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 300),
    initialBinding: InitialBinding(),
    getPages: AppPages.pages,
    onInit: () async {
      // 在 GetMaterialApp 初始化完成后检查版本
      await versionService.initCheckVersion();
    },
    navigatorObservers: [
      Get.find<RouteObserver<Route<dynamic>>>(),
    ],
  ));
  if (Platform.isAndroid) {
    //覆盖状态栏，写在渲染之前MaterialApp组件会覆盖掉这个值。
    SystemUiOverlayStyle systemUiOverlayStyle = const SystemUiOverlayStyle(statusBarColor: Colors.transparent);
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }
}

Future<void> initServices() async {
  // 初始化 AppController
  Get.put(AppController());

  // 初始化 UserService
  await Get.putAsync(() => UserService().init());
}

Future<void> setOptimalDisplayMode() async {
  final List<DisplayMode> supported = await FlutterDisplayMode.supported;
  final DisplayMode active = await FlutterDisplayMode.active;

  final List<DisplayMode> sameResolution = supported
      .where(
        (DisplayMode m) => m.width == active.width && m.height == active.height,
      )
      .toList()
    ..sort(
      (DisplayMode a, DisplayMode b) => b.refreshRate.compareTo(a.refreshRate),
    );

  final DisplayMode mostOptimalMode = sameResolution.isNotEmpty ? sameResolution.first : active;

  await FlutterDisplayMode.setPreferredMode(mostOptimalMode);
}
