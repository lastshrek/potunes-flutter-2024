/*
 * @Author       : lastshrek
 * @Date         : 2024-05-18 22:56:55
 * @LastEditors  : lastshrek
 * @LastEditTime : 2024-05-19 13:41:56
 * @FilePath     : /lib/services/service_locator.dart
 * @Description  : service locator
 * Copyright 2024 lastshrek, All Rights Reserved.
 * 2024-05-18 22:56:55
 */

import 'package:get_it/get_it.dart';
import 'package:potunes_flutter_2024/helpers/helpers.dart';

GetIt locator = GetIt.instance;

Future<void> setupServiceLocator() async {
  // TODO: Register audio services
  locator.registerSingleton<MyTheme>(MyTheme());
}
