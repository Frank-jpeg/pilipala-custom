import 'package:get/get.dart';
import 'package:pilipala/pages/webview/index.dart';
import 'package:pilipala/tv/pages/library/tv_library_page.dart';
import 'package:pilipala/tv/pages/login/tv_login_page.dart';
import 'package:pilipala/tv/pages/player/tv_player_page.dart';
import 'package:pilipala/tv/pages/search/tv_search_page.dart';
import 'package:pilipala/tv/pages/settings/tv_settings_page.dart';
import 'package:pilipala/tv/pages/shell/tv_shell_page.dart';
import 'package:pilipala/tv/pages/video/tv_video_page.dart';

class TvRoutes {
  static const String shell = '/';
  static const String search = '/search';
  static const String library = '/library';
  static const String login = '/login';
  static const String video = '/video';
  static const String player = '/player';
  static const String settings = '/settings';
  static const String webview = '/webview';

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(name: shell, page: () => const TvShellPage()),
    GetPage<dynamic>(name: search, page: () => const TvSearchPage()),
    GetPage<dynamic>(name: library, page: () => const TvLibraryPage()),
    GetPage<dynamic>(name: login, page: () => const TvLoginPage()),
    GetPage<dynamic>(name: video, page: () => const TvVideoPage()),
    GetPage<dynamic>(name: player, page: () => const TvPlayerPage()),
    GetPage<dynamic>(name: settings, page: () => const TvSettingsPage()),
    GetPage<dynamic>(name: webview, page: () => const WebviewPage()),
  ];
}
