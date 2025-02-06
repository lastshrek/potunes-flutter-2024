import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'pages/home_page.dart';
import 'pages/top_charts_page.dart';
import 'pages/library_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    TopChartsPage(),
    LibraryPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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
    );
  }
}
