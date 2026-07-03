import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:gt3_flutter_plugin/gt3_flutter_plugin.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/index.dart';
import 'package:pilipala/http/login.dart';
import 'package:pilipala/models/login/index.dart';
import 'package:pilipala/tv/controllers/tv_session_controller.dart';
import 'package:pilipala/tv/tv_routes.dart';

class TvLoginController extends GetxController {
  final RxBool loading = false.obs;
  final RxBool submitting = false.obs;
  final RxInt validSeconds = 180.obs;
  final RxString qrUrl = ''.obs;
  final RxnString error = RxnString();
  final RxInt loginMode = 0.obs;
  final RxInt smsStep = 0.obs;
  final RxString phoneInput = ''.obs;
  final RxString smsCodeInput = ''.obs;
  final RxInt smsCountdown = 0.obs;
  final RxBool smsSending = false.obs;
  final RxBool smsLoggingIn = false.obs;
  final Gt3FlutterPlugin captcha = Gt3FlutterPlugin();
  Timer? pollTimer;
  Timer? smsTimer;
  String? qrcodeKey;
  String? captchaKey;
  bool _polling = false;

  void setLoginMode(int mode) {
    loginMode.value = mode.clamp(0, 2);
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

  bool get isPhoneStep => smsStep.value == 0;

  String get maskedPhone {
    final String phone = phoneInput.value;
    if (phone.length < 7) {
      return phone;
    }
    return '${phone.substring(0, 3)}****${phone.substring(7)}';
  }

  String get smsCodeDisplay {
    if (smsCodeInput.value.isEmpty) {
      return '------';
    }
    return smsCodeInput.value.padRight(6, '•');
  }

  void inputDigit(String digit) {
    error.value = null;
    if (isPhoneStep) {
      if (phoneInput.value.length >= 11) {
        return;
      }
      phoneInput.value = '${phoneInput.value}$digit';
      return;
    }
    if (smsCodeInput.value.length >= 6) {
      return;
    }
    smsCodeInput.value = '${smsCodeInput.value}$digit';
  }

  void deleteDigit() {
    error.value = null;
    if (isPhoneStep) {
      if (phoneInput.value.isNotEmpty) {
        phoneInput.value =
            phoneInput.value.substring(0, phoneInput.value.length - 1);
      }
      return;
    }
    if (smsCodeInput.value.isNotEmpty) {
      smsCodeInput.value =
          smsCodeInput.value.substring(0, smsCodeInput.value.length - 1);
    }
  }

  void clearInput() {
    error.value = null;
    if (isPhoneStep) {
      phoneInput.value = '';
      return;
    }
    smsCodeInput.value = '';
  }

  void previousSmsStepOrBack() {
    if (!isPhoneStep) {
      smsStep.value = 0;
      smsCodeInput.value = '';
      error.value = null;
      return;
    }
    Get.back();
  }

  Future<void> requestSmsCode() async {
    if (phoneInput.value.length != 11) {
      error.value = '请输入 11 位手机号';
      return;
    }
    if (smsCountdown.value > 0 || smsSending.value) {
      return;
    }
    smsSending.value = true;
    error.value = null;
    try {
      final CaptchaDataModel? captchaData = await _requestCaptcha();
      if (captchaData == null) {
        error.value = '验证取消或失败，可切到网页登录兜底';
        return;
      }
      final dynamic res = await LoginHttp.sendWebSmsCode(
        cid: 86,
        tel: int.parse(phoneInput.value),
        token: captchaData.token!,
        challenge: captchaData.geetest!.challenge!,
        validate: captchaData.validate!,
        seccode: captchaData.seccode!,
      );
      if (res['status'] == true) {
        captchaKey = res['data']['captcha_key']?.toString();
        smsStep.value = 1;
        smsCodeInput.value = '';
        _startSmsCountdown();
        SmartDialog.showToast('验证码已发送');
      } else {
        error.value = res['msg']?.toString() ?? '验证码发送失败，请使用网页登录兜底';
      }
    } catch (e) {
      error.value = '验证码发送失败: $e';
    } finally {
      smsSending.value = false;
    }
  }

  Future<void> loginBySmsCode() async {
    if (phoneInput.value.length != 11) {
      smsStep.value = 0;
      error.value = '请输入 11 位手机号';
      return;
    }
    if (smsCodeInput.value.length != 6) {
      error.value = '请输入 6 位短信验证码';
      return;
    }
    final String? key = captchaKey;
    if (key == null || key.isEmpty) {
      error.value = '请先获取验证码';
      return;
    }
    smsLoggingIn.value = true;
    error.value = null;
    try {
      final dynamic res = await LoginHttp.loginInByWebSmsCode(
        cid: 86,
        tel: int.parse(phoneInput.value),
        code: int.parse(smsCodeInput.value),
        captchaKey: key,
      );
      if (res['status'] == true) {
        await _saveCookiesFromResponseHeaders(res['headers']);
        final dynamic data = res['data'];
        if (data is Map && data['url'] != null) {
          await _saveCookiesFromUrl(data['url'].toString());
        }
        final bool success = await Get.find<TvSessionController>()
            .syncUserFromServer(silent: true, clearOnFailure: false);
        if (success) {
          SmartDialog.showToast('登录成功');
          Get.back();
        } else {
          error.value = '登录已提交，但暂未同步到账号状态，请稍后点检查登录状态';
        }
      } else {
        error.value = res['msg']?.toString() ?? '验证码登录失败，请使用网页登录兜底';
      }
    } catch (e) {
      error.value = '验证码登录失败: $e';
    } finally {
      smsLoggingIn.value = false;
    }
  }

  Future<CaptchaDataModel?> _requestCaptcha() async {
    SmartDialog.showLoading(msg: '请求验证中...');
    try {
      final dynamic result = await LoginHttp.queryCaptcha();
      if (result['status'] != true) {
        SmartDialog.dismiss();
        error.value = result['msg']?.toString() ?? '获取验证失败';
        return null;
      }
      final CaptchaDataModel captchaData = result['data'] as CaptchaDataModel;
      final Completer<CaptchaDataModel?> completer =
          Completer<CaptchaDataModel?>();
      captcha.addEventHandler(
        onShow: (Map<String, dynamic> message) async {
          SmartDialog.dismiss();
        },
        onClose: (Map<String, dynamic> message) async {
          SmartDialog.dismiss();
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
        onResult: (Map<String, dynamic> message) async {
          SmartDialog.dismiss();
          final String code = message['code']?.toString() ?? '';
          if (code == '1') {
            captchaData.validate = message['result']['geetest_validate'];
            captchaData.seccode = message['result']['geetest_seccode'];
            captchaData.geetest!.challenge =
                message['result']['geetest_challenge'];
            if (!completer.isCompleted) {
              completer.complete(captchaData);
            }
          } else if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
        onError: (Map<String, dynamic> message) async {
          SmartDialog.dismiss();
          if (!completer.isCompleted) {
            completer.completeError(message['message'] ?? message.toString());
          }
        },
      );
      final Gt3RegisterData registerData = Gt3RegisterData(
        challenge: captchaData.geetest!.challenge,
        gt: captchaData.geetest!.gt!,
        success: true,
      );
      captcha.startCaptcha(registerData);
      return completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => null,
      );
    } catch (e) {
      SmartDialog.dismiss();
      error.value = '验证失败: $e';
      return null;
    }
  }

  void _startSmsCountdown() {
    smsTimer?.cancel();
    smsCountdown.value = 60;
    smsTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (smsCountdown.value <= 1) {
        smsCountdown.value = 0;
        timer.cancel();
        return;
      }
      smsCountdown.value--;
    });
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
    smsTimer?.cancel();
    super.onClose();
  }
}
