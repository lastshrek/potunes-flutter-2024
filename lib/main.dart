import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:potunes_flutter/screens/favourites.dart';
// import 'package:potunes_flutter/screens/screen.dart';
// import 'package:potunes_flutter/theme/app_theme.dart';
// import 'services/service_locator.dart';
// import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 禁用所有系统日志
  if (Platform.isAndroid) {
    const MethodChannel('flutter/service_worker').setMethodCallHandler(null);
    const MethodChannel('flutter/platform').setMethodCallHandler(null);

    // 尝试禁用系统日志
    try {
      await const MethodChannel('flutter/platform').invokeMethod('systemLogger', false);
      await SystemChannels.platform.invokeMethod('SystemNavigator.setSystemUIOverlayStyle', {
        'systemNavigationBarColor': '#00000000',
        'systemNavigationBarDividerColor': '#00000000',
        'statusBarColor': '#00000000',
        'systemNavigationBarIconBrightness': Brightness.light.index,
        'statusBarIconBrightness': Brightness.light.index,
        'statusBarBrightness': Brightness.dark.index,
      });
    } catch (_) {}
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

  // 设置日志过滤器
  FlutterError.onError = (FlutterErrorDetails details) {
    // 只在调试模式下打印错误
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

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
    // setOptimalDisplayMode();
  }
  // await setupServiceLocator();
  runApp(const MyApp());
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

// Future<void> setOptimalDisplayMode() async {
//   final List<DisplayMode> supported = await FlutterDisplayMode.supported;
//   final DisplayMode active = await FlutterDisplayMode.active;

//   final List<DisplayMode> sameResolution = supported
//       .where(
//         (DisplayMode m) => m.width == active.width && m.height == active.height,
//       )
//       .toList()
//     ..sort(
//       (DisplayMode a, DisplayMode b) => b.refreshRate.compareTo(a.refreshRate),
//     );

//   final DisplayMode mostOptimalMode = sameResolution.isNotEmpty ? sameResolution.first : active;

//   await FlutterDisplayMode.setPreferredMode(mostOptimalMode);
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black38,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    return GetMaterialApp(
      title: 'PoTunes',
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
      ),
      getPages: [
        GetPage(name: '/', page: () => const HomeScreen()),
        // GetPage(name: '/', page: () => SettingScreen()),
        // GetPage(name: '/playlist', page: () => const PlaylistScreen(), transition: Transition.cupertinoDialog),
        // GetPage(name: '/nowplaying', page: () => const NowPlayingScreen(), transition: Transition.downToUp),
        // GetPage(name: '/albums', page: () => const AlbumsScreen(), transition: Transition.cupertinoDialog),
        // GetPage(name: '/about', page: () => const AboutScreen(), transition: Transition.rightToLeft),
        // GetPage(name: '/auth', page: () => const AuthScreen(), transition: Transition.downToUp),
        // GetPage(name: '/library', page: () => const LibraryPage(), transition: Transition.cupertinoDialog),
        // GetPage(
        //     name: '/favourite',
        //     page: () => const Favourites(
        //           playlistName: 'Favorite Songs',
        //         )),
        // GetPage(name: '/settings', page: () => SettingScreen(), transition: Transition.rightToLeft),
        // GetPage(name: '/album', page: () => const AlbumScreen(), transition: Transition.cupertinoDialog),
      ],
    );
  }
}
