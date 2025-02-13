import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:get/get.dart';
import '../controllers/navigation_controller.dart';
import 'pages/home_page.dart';
import 'pages/top_charts_page.dart';
import 'pages/library_page.dart';
import '../widgets/mini_player.dart';
import 'pages/login_page.dart';
import '../services/user_service.dart';
import '../controllers/app_controller.dart';

class HomeScreen extends StatefulWidget {
  static final pageController = PageController();
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final NavigationController navigationController;

  final List<Widget> _pages = const [
    HomePage(),
    TopChartsPage(),
    LibraryPage(),
  ];

  @override
  void initState() {
    super.initState();
    navigationController = Get.put(NavigationController());
    // 将 State 注入到 Get 中，以便其他页面可以访问
    Get.put(this);

    // 监听 NavigationController 的变化
    ever(navigationController.currentPage.obs, (index) {
      if (mounted) {
        navigationController.pageController.jumpToPage(index);
      }
    });
  }

  @override
  void dispose() {
    navigationController.pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      final isLoggedIn = UserService.to.isLoggedIn;

      if (!isLoggedIn) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          enableDrag: true,
          isDismissible: true,
          useSafeArea: false,
          builder: (context) => const LoginPage(),
        ).then((value) {
          if (value == true) {
            setState(() {
              navigationController.changePage(index);
              navigationController.pageController.jumpToPage(index);
              // 同步更新 AppController
              Get.find<AppController>().currentIndex = index;
            });
          }
        });
        return;
      }
    }
    setState(() {
      navigationController.changePage(index);
      navigationController.pageController.jumpToPage(index);
      // 同步更新 AppController
      Get.find<AppController>().currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.black,
              ),
              child: Text(
                '破破',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                // TODO: 导航到设置页面
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('关于'),
              onTap: () {
                // TODO: 导航到关于页面
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: navigationController.pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  navigationController.changePage(index);
                },
                children: _pages,
              ),
            ),
            const MiniPlayer(isAboveBottomBar: true),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Obx(() => SalomonBottomBar(
              currentIndex: navigationController.currentPage,
              onTap: _onTabTapped,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withOpacity(0.5),
              selectedColorOpacity: 0.15,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                top: 12,
                left: 12,
                right: 12,
              ),
              items: [
                SalomonBottomBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  title: const Text('Home'),
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.trending_up_outlined),
                  activeIcon: const Icon(Icons.trending_up),
                  title: const Text('TopCharts'),
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.library_music_outlined),
                  activeIcon: const Icon(Icons.library_music),
                  title: const Text('Library'),
                ),
              ],
            )),
      ),
    );
  }
}
