import 'package:get/get.dart';
import 'package:pilipala/http/init.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/utils/cookie.dart';
import 'package:pilipala/utils/event_bus.dart';
import 'package:pilipala/utils/id_utils.dart';
import 'package:pilipala/utils/login.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewController extends GetxController {
  String url = '';
  RxString type = ''.obs;
  String pageTitle = '';
  final WebViewController controller = WebViewController();
  RxInt loadProgress = 0.obs;
  RxBool loadShow = true.obs;
  EventBus eventBus = EventBus();
  bool _syncingTvLogin = false;

  @override
  void onInit() {
    super.onInit();
    url = Get.parameters['url']!;
    type.value = Get.parameters['type']!;
    pageTitle = Get.parameters['pageTitle']!;

    if (_isLoginPage) {
      controller.clearCache();
      controller.clearLocalStorage();
      WebViewCookieManager().clearCookies();
    }
    webviewInit();
  }

  webviewInit() {
    controller
      ..setUserAgent(Request().headerUa())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          // 页面加载
          onProgress: (int progress) {
            // Update loading bar.
            loadProgress.value = progress;
          },
          onPageStarted: (String url) {
            final List pathSegments = Uri.parse(url).pathSegments;
            if (type.value != 'tvLogin' &&
                pathSegments.isNotEmpty &&
                url != 'https://passport.bilibili.com/h5-app/passport/login') {
              final String str = pathSegments[0];
              final Map matchRes = IdUtils.matchAvorBv(input: str);
              final List matchKeys = matchRes.keys.toList();
              if (matchKeys.isNotEmpty) {
                if (matchKeys.first == 'BV') {
                  Get.offAndToNamed(
                    '/searchResult',
                    parameters: {'keyword': matchRes['BV']},
                  );
                }
              }
            }
          },
          // 加载完成
          onUrlChange: (UrlChange urlChange) async {
            loadShow.value = false;
            String url = urlChange.url ?? '';
            if (type.value == 'login' &&
                (url.startsWith(
                        'https://passport.bilibili.com/web/sso/exchange_cookie') ||
                    url.startsWith('https://m.bilibili.com/'))) {
              LoginUtils.confirmLogin(url, controller);
            } else if (type.value == 'tvLogin' && _looksLikeLoginDone(url)) {
              confirmTvLogin();
            }
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('bilibili://')) {
              if (request.url.startsWith('bilibili://video/')) {
                String str = Uri.parse(request.url).pathSegments[0];
                Get.offAndToNamed(
                  '/searchResult',
                  parameters: {'keyword': str},
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url.startsWith('http') ? url : 'https://$url'));
  }

  bool get _isLoginPage => type.value == 'login' || type.value == 'tvLogin';

  bool _looksLikeLoginDone(String url) {
    return url.startsWith(
            'https://passport.bilibili.com/web/sso/exchange_cookie') ||
        url.startsWith('https://m.bilibili.com/') ||
        url.startsWith('https://www.bilibili.com/');
  }

  Future<void> confirmTvLogin() async {
    if (_syncingTvLogin) {
      return;
    }
    _syncingTvLogin = true;
    try {
      await SetCookie.onSet();
      if (!Get.isRegistered<TvSessionController>()) {
        SmartDialog.showToast('TV 登录状态控制器未初始化');
        return;
      }
      final bool success = await Get.find<TvSessionController>()
          .syncUserFromServer(silent: true, clearOnFailure: false);
      if (success) {
        SmartDialog.showToast('登录成功');
        Get.back();
      } else {
        SmartDialog.showToast('还没有检测到登录状态');
      }
    } catch (e) {
      SmartDialog.showToast('同步网页登录状态失败: $e');
    } finally {
      _syncingTvLogin = false;
    }
  }
}
