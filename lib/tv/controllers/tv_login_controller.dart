import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/index.dart';
import 'package:pilipala/http/login.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';

class TvLoginController extends GetxController {
  final RxBool loading = false.obs;
  final RxInt validSeconds = 180.obs;
  final RxString qrUrl = ''.obs;
  final RxnString error = RxnString();
  Timer? pollTimer;
  late String qrcodeKey;

  Future<void> startLogin() async {
    loading.value = true;
    error.value = null;
    pollTimer?.cancel();
    validSeconds.value = 180;
    try {
      final dynamic res = await LoginHttp.getWebQrcode();
      if (res['status'] == true) {
        qrUrl.value = res['data']['url'] as String;
        qrcodeKey = res['data']['qrcode_key'] as String;
        pollTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) async {
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
    final dynamic res = await LoginHttp.queryWebQrcodeStatus(qrcodeKey);
    if (res['status'] == true) {
      final String url = res['data']['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        await _saveCookiesFromUrl(url);
      }
      final bool success =
          await Get.find<TvSessionController>().syncUserFromServer(silent: true);
      if (success) {
        SmartDialog.showToast('登录成功');
        pollTimer?.cancel();
      }
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
    Request.dio.options.headers['cookie'] =
        cookies.map((Cookie cookie) => '${cookie.name}=${cookie.value}').join('; ');
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
