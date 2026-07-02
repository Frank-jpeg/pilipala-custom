import 'dart:io';

import 'package:catcher_2/catcher_2.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pilipala/http/init.dart';
import 'package:pilipala/services/service_locator.dart';
import 'package:pilipala/tv/controllers/tv_anti_addiction_controller.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/tv_app.dart';
import 'package:pilipala/utils/app_scheme.dart';
import 'package:pilipala/utils/data.dart';
import 'package:pilipala/utils/global_data_cache.dart';
import 'package:pilipala/utils/recommend_filter.dart';
import 'package:pilipala/utils/storage.dart';

import 'services/loggeer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await GStrorage.init();
  clearLogs();
  Request();
  await Request.setCookie();

  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 29) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ));
  }

  PiliSchame.init();
  await GlobalDataCache().initialize();
  await setupServiceLocator();
  await Data.init();
  RecommendFilter();
  Get.put<TvSessionController>(TvSessionController(), permanent: true);
  Get.put<TvAntiAddictionController>(
    TvAntiAddictionController(),
    permanent: true,
  );

  final Catcher2Options releaseConfig = Catcher2Options(
    SilentReportMode(),
    [FileHandler(await getLogsPath())],
  );

  Catcher2(
    releaseConfig: releaseConfig,
    runAppFunction: () {
      runApp(const TvApp());
    },
  );
}
