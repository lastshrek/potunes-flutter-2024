import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:potunes_flutter_2024/services/service_locator.dart';
import 'package:potunes_flutter_2024/theme/app_theme.dart';

import 'screens/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /**
   * @description: 初始化Hive数据库
   */
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await Hive.initFlutter('Potunes');
  } else {
    await Hive.initFlutter();
  }

  await openHiveBox('settings');
  // await openHiveBox('downloads');
  // await openHiveBox('Favorite Songs');
  await openHiveBox('cache', limit: true);

  /**
   * @description: 适配移动端设备的最佳显示模式
   */
  if (Platform.isAndroid || Platform.isIOS) {
    setOptimalDisplayMode();
  }
  /**
   * @description: 初始化服务定位器   
   */
  await setupServiceLocator();
  runApp(const MyApp());
  if (Platform.isAndroid) {
    /**
     * @description: 设置状态栏和导航栏的颜色
     */
    SystemUiOverlayStyle systemUiOverlayStyle = const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }
}

Future<void> openHiveBox(String boxName, {bool limit = false}) async {
  final box = await Hive.openBox(boxName).onError((error, stackTrace) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String dirPath = dir.path;
    File dbFile = File('$dirPath/$boxName.hive');
    File lockFile = File('$dirPath/$boxName.lock');
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      dbFile = File('$dirPath/BlackHole/$boxName.hive');
      lockFile = File('$dirPath/BlackHole/$boxName.lock');
    }
    await dbFile.delete();
    await lockFile.delete();
    await Hive.openBox(boxName);
    throw 'Failed to open $boxName Box\nError: $error';
  });
  // clear box if it grows large
  if (limit && box.length > 500) {
    box.clear();
  }
}

/// @description: 适配移动端设备的最佳显示模式
Future<void> setOptimalDisplayMode() async {
  final List<DisplayMode> supportedModes = await FlutterDisplayMode.supported;
  final DisplayMode activeMode = await FlutterDisplayMode.active;
  final DisplayMode optimalMode = supportedModes.firstWhere(
    (DisplayMode mode) =>
        mode.width == activeMode.width && mode.height == activeMode.height && mode.refreshRate > activeMode.refreshRate,
    orElse: () => supportedModes.first,
  );
  await FlutterDisplayMode.setPreferredMode(optimalMode);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    /**
     * @description: 初始化主题
     */
    AppTheme.currentTheme.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '破破',
      debugShowCheckedModeBanner: false,
      themeMode: AppTheme.themeMode,
      theme: AppTheme.lightTheme(
        context: context,
      ),
      darkTheme: AppTheme.darkTheme(
        context: context,
      ),
      getPages: [
        GetPage(name: '/', page: () => const Home()),
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
