import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/navigation_controller.dart';
import 'pages/home_page.dart';
import 'pages/top_charts_page.dart';
import 'pages/library_page.dart';
import '../widgets/mini_player.dart';
import 'pages/login_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final NavigationController navigationController;
  final PageController _pageController = PageController();

  final List<Widget> _pages = const [
    HomePage(),
    TopChartsPage(),
    LibraryPage(),
  ];

  @override
  void initState() {
    super.initState();
    navigationController = Get.put(NavigationController());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                'PoTunes',
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
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: navigationController.changePage,
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
        child: GetX<NavigationController>(
          builder: (controller) => SalomonBottomBar(
            currentIndex: controller.currentPage,
            onTap: _onTabTapped,
            selectedItemColor: Theme.of(context).colorScheme.secondary,
            unselectedItemColor: Colors.white54,
            margin: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            items: [
              SalomonBottomBarItem(
                icon: const Icon(Icons.home_rounded),
                title: const Text("Home"),
                selectedColor: Theme.of(context).colorScheme.secondary,
              ),
              SalomonBottomBarItem(
                icon: const Icon(Icons.trending_up_rounded),
                title: const Text(
                  "TopCharts",
                ),
                selectedColor: Theme.of(context).colorScheme.secondary,
              ),
              SalomonBottomBarItem(
                icon: const Icon(Icons.my_library_music_rounded),
                title: const Text("Library"),
                selectedColor: Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Library tab
      // TODO: 检查登录状态
      final isLoggedIn = false; // 从本地存储或状态管理中获取登录状态
      if (!isLoggedIn) {
        Navigator.of(context)
            .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(
                  opacity: animation,
                  child: const LoginPage(),
                ),
              );
            },
            opaque: false,
            barrierDismissible: true,
            barrierColor: Colors.black.withOpacity(0.5),
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 200),
          ),
        )
            .then((value) {
          if (value == true) {
            setState(() {
              navigationController.changePage(index);
              _pageController.jumpToPage(index);
            });
          }
        });
        return;
      }
    }
    setState(() {
      navigationController.changePage(index);
      _pageController.jumpToPage(index);
    });
  }
}
