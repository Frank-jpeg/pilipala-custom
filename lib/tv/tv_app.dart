import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/custom_toast.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/pages/anti_addiction/tv_anti_addiction_lock_page.dart';
import 'package:pilipala/tv/tv_routes.dart';

class TvApp extends StatelessWidget {
  const TvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'PiliPala TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFB7299),
          secondary: Color(0xFF4EC3FF),
          surface: Color(0xFF121A2B),
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      fallbackLocale: const Locale('zh', 'CN'),
      initialRoute: TvRoutes.shell,
      getPages: TvRoutes.pages,
      builder: (BuildContext context, Widget? child) {
        return FlutterSmartDialog(
          toastBuilder: (String msg) => CustomToast(msg: msg),
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: child ?? const SizedBox.shrink()),
              const TvAntiAddictionLockOverlay(),
            ],
          ),
        );
      },
      onReady: () {
        Get.find<TvSessionController>().restoreUser();
      },
    );
  }
}
