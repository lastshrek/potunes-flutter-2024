import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'screens/home_screen.dart';
import 'services/audio_service.dart';
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
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
    // iOS 配置
    androidStopForegroundOnPause: true,
    fastForwardInterval: const Duration(seconds: 10),
    rewindInterval: const Duration(seconds: 10),
    preloadArtwork: true,
  );

  // 初始化 GetX 服务
  Get.put(AudioService(), permanent: true);

  // 修改日志处理逻辑
  if (kDebugMode) {
    // 在调试模式下启用所有日志
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };
  } else {
    // 在发布模式下只显示关键错误
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };
  }

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

    // 只在 Android 调试模式下禁用日志
    if (!kDebugMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }

    // 设置沉浸式状态栏
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 状态栏透明
        statusBarIconBrightness: Brightness.light, // 状态栏图标为亮色
        systemNavigationBarColor: Colors.transparent, // 导航栏透明
        systemNavigationBarIconBrightness: Brightness.light, // 导航栏图标为亮色
        systemNavigationBarDividerColor: Colors.transparent, // 导航栏分割线透明
      ),
    );

    // 设置沉浸式导航栏
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge, // 启用边缘到边缘模式
      overlays: [SystemUiOverlay.top], // 只显示顶部状态栏
    );
  }

  // 完全禁用调试打印
  if (!kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) return;

      // 只打印特定前缀的日志，比如你自己添加的标记
      if (message.startsWith('[APP]')) {
        print(message);
      }
    };
  }

  // if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
  //   await Hive.initFlutter('Potunes');
  // } else {
  //   await Hive.initFlutter();
  // }
  // await openHiveBox('settings');
  // await openHiveBox('downloads');
  // await openHiveBox('Favorite Songs');
  // await openHiveBox('cache', limit: true);

  if (Platform.isAndroid) {
    setOptimalDisplayMode();
  }
  // await setupServiceLocator();
  if (kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) return;
      // 强制输出日志，不受 iOS 限制
      developer.log(message);
    };
  }

  await Get.putAsync(() => UserService().init());

  // 初始化 AppController
  Get.put(AppController());

  // 设置状态栏样式为亮色（白色）
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.dark, // iOS: 暗色背景，白色前景
    statusBarIconBrightness: Brightness.light, // Android: 白色图标
    statusBarColor: Colors.transparent, // Android: 透明背景
  ));

  // 初始化版本检查服务
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
    receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
  ));

  final versionService = Get.put(VersionService(dio));

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
      fontFamily: 'bahnschrift',
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: 'bahnschrift'),
        bodyMedium: TextStyle(fontFamily: 'bahnschrift'),
        titleLarge: TextStyle(fontFamily: 'bahnschrift'),
        titleMedium: TextStyle(fontFamily: 'bahnschrift'),
        titleSmall: TextStyle(fontFamily: 'bahnschrift'),
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
  ));
  if (Platform.isAndroid) {
    //覆盖状态栏，写在渲染之前MaterialApp组件会覆盖掉这个值。
    SystemUiOverlayStyle systemUiOverlayStyle = const SystemUiOverlayStyle(statusBarColor: Colors.transparent);
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }
}

// Future<void> openHiveBox(String boxName, {bool limit = false}) async {
//   final box = await Hive.openBox(boxName).onError((error, stackTrace) async {
//     final Directory dir = await getApplicationDocumentsDirectory();
//     final String dirPath = dir.path;
//     File dbFile = File('$dirPath/$boxName.hive');
//     File lockFile = File('$dirPath/$boxName.lock');
//     if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//       dbFile = File('$dirPath/BlackHole/$boxName.hive');
//       lockFile = File('$dirPath/BlackHole/$boxName.lock');
//     }
//     await dbFile.delete();
//     await lockFile.delete();
//     await Hive.openBox(boxName);
//     throw 'Failed to open $boxName Box\nError: $error';
//   });
//   // clear box if it grows large
//   if (limit && box.length > 500) {
//     box.clear();
//   }
// }

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
