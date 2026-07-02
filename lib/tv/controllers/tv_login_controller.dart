import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/index.dart';
import 'package:pilipala/http/login.dart';
import 'package:pilipala/tv/tv_routes.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';

class TvLoginController extends GetxController {
  final RxBool loading = false.obs;
  final RxBool submitting = false.obs;
  final RxInt validSeconds = 180.obs;
  final RxString qrUrl = ''.obs;
  final RxnString error = RxnString();
  final RxInt loginMode = 0.obs;
  Timer? pollTimer;
  String? qrcodeKey;
  bool _polling = false;

  void setLoginMode(int mode) {
    loginMode.value = mode.clamp(0, 1);
    if (loginMode.value != 0) {
      pollTimer?.cancel();
    } else if (qrUrl.value.isEmpty) {
      startLogin();
    }
    error.value = null;
  }

  Future<void> startLogin() async {
    loading.value = true;
    error.value = null;
    pollTimer?.cancel();
    validSeconds.value = 180;
    try {
      final dynamic res = await LoginHttp.getWebQrcode();
      if (res['status'] == true) {
        qrUrl.value = res['data']['url'] as String;
        qrcodeKey = res['data']['qrcode_key']?.toString();
        pollTimer =
            Timer.periodic(const Duration(seconds: 1), (Timer timer) async {
          if (validSeconds.value <= 0) {
            timer.cancel();
            await startLogin();
            return;
          }
          validSeconds.value--;
          await queryStatus();
        });
      } else {
        error.value = res['msg']?.toString() ?? '生成二维码失败';
      }
    } catch (e) {
      error.value = '生成二维码失败: $e';
    } finally {
      loading.value = false;
    }
  }

  Future<void> queryStatus() async {
    final String? key = qrcodeKey;
    if (_polling || key == null || key.isEmpty) {
      return;
    }
    _polling = true;
    try {
      final dynamic res = await LoginHttp.queryWebQrcodeStatus(key);
      if (res['status'] == true) {
        await _saveCookiesFromResponseHeaders(res['headers']);
        final String url = res['data']['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          await _saveCookiesFromUrl(url);
        }
        final bool success = await Get.find<TvSessionController>()
            .syncUserFromServer(silent: true, clearOnFailure: false);
        if (success) {
          SmartDialog.showToast('登录成功');
          pollTimer?.cancel();
        }
      }
    } catch (e) {
      error.value = '轮询登录状态失败: $e';
    } finally {
      _polling = false;
    }
  }

  void openWebLogin() {
    pollTimer?.cancel();
    Get.toNamed(
      TvRoutes.webview,
      parameters: <String, String>{
        'url': 'https://passport.bilibili.com/h5-app/passport/login',
        'type': 'tvLogin',
        'pageTitle': '登录 bilibili',
      },
    );
  }

  Future<void> refreshLoginStatus() async {
    submitting.value = true;
    error.value = null;
    try {
      final bool success = await Get.find<TvSessionController>()
          .syncUserFromServer(silent: true, clearOnFailure: false);
      if (success) {
        SmartDialog.showToast('登录成功');
        Get.back();
      } else {
        error.value = '还没有检测到登录状态';
      }
    } catch (e) {
      error.value = '刷新登录状态失败: $e';
    } finally {
      submitting.value = false;
    }
  }

  Future<void> _saveCookiesFromUrl(String url) async {
    final Uri uri = Uri.parse(url);
    final List<Cookie> cookies = <Cookie>[];
    uri.queryParameters.forEach((String key, String value) {
      if (key == 'gourl' || key == 'Expires') {
        return;
      }
      cookies.add(Cookie(key, value));
    });
    if (cookies.isEmpty) {
      return;
    }
    await Request.cookieManager.cookieJar
        .saveFromResponse(Uri.parse(HttpString.baseUrl), cookies);
    await Request.cookieManager.cookieJar
        .saveFromResponse(Uri.parse(HttpString.apiBaseUrl), cookies);
    await Request.cookieManager.cookieJar
        .saveFromResponse(Uri.parse(HttpString.tUrl), cookies);
    Request.dio.options.headers['cookie'] = cookies
        .map((Cookie cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  Future<void> _saveCookiesFromResponseHeaders(dynamic headers) async {
    if (headers is! Headers) {
      return;
    }
    final List<String>? values = headers.map['set-cookie'];
    if (values == null || values.isEmpty) {
      return;
    }
    final List<Cookie> cookies = values
        .expand((String value) => value.split(RegExp(r', (?=[^;,]+=)')))
        .map((String value) => Cookie.fromSetCookieValue(value))
        .where((Cookie cookie) => cookie.name.isNotEmpty)
        .toList(growable: false);
    if (cookies.isEmpty) {
      return;
    }
    await Request.cookieManager.cookieJar
        .saveFromResponse(Uri.parse(HttpString.baseUrl), cookies);
    await Request.cookieManager.cookieJar
        .saveFromResponse(Uri.parse(HttpString.apiBaseUrl), cookies);
    await Request.cookieManager.cookieJar
        .saveFromResponse(Uri.parse(HttpString.tUrl), cookies);
    Request.dio.options.headers['cookie'] = cookies
        .map((Cookie cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  @override
  void onInit() {
    super.onInit();
    startLogin();
  }

  @override
  void onClose() {
    pollTimer?.cancel();
    super.onClose();
  }
}
