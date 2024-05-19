/*
 * @Author       : lastshrek
 * @Date         : 2024-05-18 22:52:55
 * @LastEditors  : lastshrek
 * @LastEditTime : 2024-05-19 14:23:46
 * @FilePath     : /lib/screens/home.dart
 * @Description  : Home Page
 * Copyright 2024 lastshrek, All Rights Reserved.
 * 2024-05-18 22:52:55
 */

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:potunes_flutter_2024/widgets/widgets.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with AutomaticKeepAliveClientMixin<Home> {
  String? appVersion;

  @override
  Widget build(BuildContext context) {
    const updateInfos = [
      '近期更新内容:',
      '修改了歌曲的收藏问题',
      '网易云歌曲接入并可以添加收藏',
      '修复了个人收藏页面点击列表从第一首播放的bug',
      '\n\n',
      '♥ By Purchas ♥'
    ];

    super.build(context);
    return GradientContainer(
      child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          /**
         * @description: 左侧抽屉
         */
          drawer: Drawer(
              child: GradientContainer(
            child: CustomScrollView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  elevation: 0,
                  stretch: true,
                  expandedHeight: MediaQuery.of(context).size.height * 0.3,
                  flexibleSpace: FlexibleSpaceBar(
                    title: RichText(
                      text: TextSpan(
                          text: '破破',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: appVersion == null ? '' : '\nv$appVersion',
                              style: const TextStyle(
                                fontSize: 7,
                              ),
                            )
                          ]),
                      textAlign: TextAlign.end,
                    ),
                    titlePadding: const EdgeInsets.only(
                      bottom: 40,
                    ),
                    centerTitle: true,
                    background: ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.1),
                        ]).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image(
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        image: AssetImage(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'assets/header-dark.jpg'
                              : 'assets/header.jpg',
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    ListTile(
                      title: Text(
                        'Home',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      leading: Icon(
                        Icons.home_rounded,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      selected: true,
                      onTap: () {
                        // Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: const Text("设置"),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
                      leading: Icon(
                        Icons.settings_rounded, // miscellaneous_services_rounded,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      onTap: () {
                        Get.toNamed('/settings');
                      },
                    ),
                    ListTile(
                      title: const Text("关于"),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
                      leading: Icon(
                        Icons.info_outline_rounded,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      onTap: () async {
                        Get.back();
                        var user = await Get.toNamed('/about');
                        if (user) {
                          // _onItemTapped(2);
                        }
                        // Navigator.pop(context);
                        // Navigator.pushNamed(context, '/about');
                      },
                    ),
                  ]),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: <Widget>[
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(5, 30, 5, 20),
                        child: Center(
                          child: Text(
                            updateInfos.join('\n'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
          body: const PopScope(
            child: GradientContainer(
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 10,
                  ),
                  SearchBar(),
                  SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),
          )),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
