import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pilipala/common/constants.dart';
import 'package:pilipala/http/constants.dart';
import 'package:uuid/uuid.dart';
import '../models/login/index.dart';
import '../utils/login.dart';
import 'index.dart';

class LoginHttp {
  static const int _tvBuild = 108700;
  static const String _tvMobiApp = 'android_tv_yst';
  static const String _tvChannel = 'master';
  static const String _tvUserAgent = 'Mozilla/5.0 BiliTV/1.8.7';
  static String? _tvBuvid;
  static String? _tvDeviceId;

  static String get tvUserAgent => _tvUserAgent;

  static Future queryCaptcha() async {
    var res = await Request().get(Api.getCaptcha);
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': CaptchaDataModel.fromJson(res.data['data']),
      };
    } else {
      return {'status': false, 'data': res.message};
    }
  }

  // static Future sendSmsCode({
  //   int? cid,
  //   required int tel,
  //   required String token,
  //   required String challenge,
  //   required String validate,
  //   required String seccode,
  // }) async {
  //   var res = await Request().post(
  //     Api.appSmsCode,
  //     data: {
  //       'cid': cid,
  //       'tel': tel,
  //       "source": "main_web",
  //       'token': token,
  //       'challenge': challenge,
  //       'validate': validate,
  //       'seccode': seccode,
  //     },
  //     options: Options(
  //       contentType: Headers.formUrlEncodedContentType,
  //       // headers: {'user-agent': ApiConstants.userAgent}
  //     ),
  //   );
  //   print(res);
  // }

  // web端验证码
  static Future sendWebSmsCode({
    int? cid,
    required int tel,
    required String token,
    required String challenge,
    required String validate,
    required String seccode,
  }) async {
    Map data = {
      'cid': cid,
      'tel': tel,
      "source": "main_web",
      'token': token,
      'challenge': challenge,
      'validate': validate,
      'seccode': seccode,
    };
    FormData formData = FormData.fromMap({...data});
    var res = await Request().post(
      Api.webSmsCode,
      data: formData,
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
        'headers': res.headers,
      };
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // web端验证码登录
  static Future loginInByWebSmsCode({
    int? cid,
    required int tel,
    required String code,
    required String captchaKey,
  }) async {
    // webSmsLogin
    Map data = {
      "cid": cid,
      "tel": tel,
      "code": code,
      "source": "main_mini",
      "keep": 0,
      "captcha_key": captchaKey,
      "go_url": HttpString.baseUrl
    };
    FormData formData = FormData.fromMap({...data});
    var res = await Request().post(
      Api.webSmsLogin,
      data: formData,
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
        'headers': res.headers,
      };
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  static Future sendTvSmsCode({
    required String tel,
  }) async {
    try {
      final Map<String, dynamic>? authKey = await _getTvLoginKey();
      if (authKey == null) {
        return {'status': false, 'data': [], 'msg': '获取 TV 登录密钥失败'};
      }
      final String telEncrypted = _encryptWithTvAuthKey(tel, authKey);
      if (telEncrypted.isEmpty) {
        return {'status': false, 'data': [], 'msg': '手机号加密失败'};
      }
      final Map<String, dynamic> data = await signedTvParams(<String, dynamic>{
        'cid': '86',
        'tel_encrypt': telEncrypted,
        'code': '',
        'token': await _tvDeviceId16(),
        'login_session_id': _tvLoginSessionId(),
        'spm_id': '',
        'extend': '',
        'device_tourist_id': '',
      });
      final Response<dynamic> res = await Request.dio.post(
        Api.tvSmsCode,
        data: _tvEncodedQuery(data),
        options: _tvFormOptions(),
      );
      return _tvResponse(res);
    } catch (e) {
      return {'status': false, 'data': [], 'msg': 'TV 验证码发送失败: $e'};
    }
  }

  static Future loginInByTvSmsCode({
    required String tel,
    required String code,
    required String captchaKey,
  }) async {
    try {
      final Map<String, dynamic>? authKey = await _getTvLoginKey();
      if (authKey == null) {
        return {'status': false, 'data': [], 'msg': '获取 TV 登录密钥失败'};
      }
      final String telEncrypted = _encryptWithTvAuthKey(tel, authKey);
      if (telEncrypted.isEmpty) {
        return {'status': false, 'data': [], 'msg': '手机号加密失败'};
      }
      final Map<String, dynamic> data = await signedTvParams(<String, dynamic>{
        'cid': '86',
        'tel_encrypt': telEncrypted,
        'code': code,
        'captcha_key': captchaKey,
        'login_session_id': _tvLoginSessionId(),
        'spm_id': '',
        'extend': '',
        'device_tourist_id': '',
      });
      final Response<dynamic> res = await Request.dio.post(
        Api.tvSmsLogin,
        data: _tvEncodedQuery(data),
        options: _tvFormOptions(),
      );
      return _tvResponse(res);
    } catch (e) {
      return {'status': false, 'data': [], 'msg': 'TV 验证码登录失败: $e'};
    }
  }

  static Future<Map<String, dynamic>?> _getTvLoginKey() async {
    final Map<String, dynamic> params = await signedTvParams();
    final Response<dynamic> res = await Request.dio.get(
      '${Api.tvLoginKey}?${_tvEncodedQuery(params)}',
      options: Options(headers: <String, dynamic>{'user-agent': _tvUserAgent}),
    );
    final dynamic body = res.data;
    if (body is Map && body['code'] == 0 && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return null;
  }

  static String _encryptWithTvAuthKey(
    String raw,
    Map<String, dynamic> authKey,
  ) {
    final String key = authKey['key']?.toString() ?? '';
    final String hash = authKey['hash']?.toString() ?? '';
    if (key.isEmpty || hash.isEmpty) {
      return '';
    }
    final dynamic publicKey = RSAKeyParser().parse(key);
    return Encrypter(RSA(publicKey: publicKey)).encrypt(hash + raw).base64;
  }

  static Future<Map<String, dynamic>> signedTvParams([
    Map<String, dynamic>? params,
  ]) async {
    final Map<String, dynamic> signed = <String, dynamic>{
      ...await tvCommonParams(),
      ...?params,
    }..removeWhere((String key, dynamic value) => value == null);
    // Bilibili 的 app 签名要求带秒级时间戳 ts，缺失会被服务端判为 -400 请求错误。
    // 官方 TV 端由 native signQuery 自动补 ts，这里对齐 member.dart 里其它 app 签名请求的写法。
    signed['ts'] = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    // 官方 okhttp FormBody 用 %20 编码空格，服务端按同样规则校验 sign；
    // Dart 的 Uri 默认把空格编成 +，机型名（model / device_platform）常带空格，
    // 会导致 sign 与请求体不一致而报错，这里统一用 %20 计算签名与拼接请求体。
    final String sign = md5
        .convert(utf8.encode('${_tvEncodedQuery(signed)}${Constants.appSec}'))
        .toString();
    signed['sign'] = sign;
    return signed;
  }

  // 按 key 排序后用 %20 编码拼接成 query/body，签名与实际发送共用，保证一致。
  static String tvEncodedQuery(Map<String, dynamic> params) {
    return _tvEncodedQuery(params);
  }

  static String _tvEncodedQuery(Map<String, dynamic> params) {
    final List<String> keys = params.keys.toList()..sort();
    return keys
        .map((String key) =>
            '$key=${Uri.encodeQueryComponent(params[key].toString()).replaceAll('+', '%20')}')
        .join('&');
  }

  static Future<Map<String, dynamic>> tvCommonParams() async {
    AndroidDeviceInfo? info;
    try {
      info = await DeviceInfoPlugin().androidInfo;
    } catch (_) {}
    final String brand = _notEmpty(info?.brand, 'Android');
    final String model = _notEmpty(info?.model, 'TV');
    final String device = _notEmpty(info?.device, model);
    final String manufacturer = _notEmpty(info?.manufacturer, brand);
    final String release = _notEmpty(info?.version.release, '');
    final String sdkInt = (info?.version.sdkInt ?? 0).toString();
    final String buvid = await _getTvBuvid();
    final String deviceId = _getTvDeviceId();
    final String fingerprint =
        md5.convert(utf8.encode('$deviceId-$brand-$model')).toString();
    return <String, dynamic>{
      'platform': 'android',
      'mobi_app': _tvMobiApp,
      'appkey': Constants.appKey,
      'build': _tvBuild.toString(),
      'channel': _tvChannel,
      'sys_ver': sdkInt,
      'brand': brand,
      'model': model,
      'uid': '0',
      'tv_brand': _tvChannel,
      'memory': '0',
      'mode_switch': 'true',
      'statistics': '{"appId":"18","platform":"3","version":"$_tvBuild"}',
      'teenager_mode': '3',
      'build_sn': _tvBuild.toString(),
      'child_lock': '0',
      'top_speed': '0',
      'product_top_speed': '0',
      'device': brand,
      'device_id': deviceId,
      'bili_local_id': deviceId,
      'device_name': device,
      'device_platform': 'Android$release$manufacturer$model',
      'networkstate': 'wifi',
      'buvid': buvid,
      'guid': buvid,
      'local_id': buvid,
      'local_fingerprint': fingerprint,
      'fingerprint': fingerprint,
    };
  }

  static String _notEmpty(String? value, String fallback) {
    if (value == null || value.isEmpty) {
      return fallback;
    }
    return value;
  }

  static String _tvLoginSessionId() => const Uuid().v4().replaceAll('-', '');

  static Future<String> _getTvBuvid() async {
    if (_tvBuvid != null && _tvBuvid!.isNotEmpty) {
      return _tvBuvid!;
    }
    try {
      _tvBuvid = await Request.getBuvid();
    } catch (_) {}
    if (_tvBuvid == null || _tvBuvid!.isEmpty) {
      _tvBuvid = LoginUtils.generateBuvid();
    }
    return _tvBuvid!;
  }

  static String _getTvDeviceId() {
    _tvDeviceId ??= LoginUtils.generateBuvid();
    return _tvDeviceId!;
  }

  static Future<String> _tvDeviceId16() async {
    final String raw = _getTvDeviceId();
    return raw.length <= 16 ? raw : raw.substring(0, 16);
  }

  static Options _tvFormOptions() {
    return Options(
      contentType: Headers.formUrlEncodedContentType,
      headers: <String, dynamic>{'user-agent': _tvUserAgent},
    );
  }

  static Map<String, dynamic> _tvResponse(Response<dynamic> res) {
    final dynamic body = res.data;
    if (body is Map && body['code'] == 0) {
      return {
        'status': true,
        'data': body['data'] ?? <String, dynamic>{},
        'headers': res.headers,
      };
    }
    return {
      'status': false,
      'data': body is Map ? body['data'] ?? <dynamic>[] : <dynamic>[],
      'msg': body is Map
          ? body['message']?.toString() ?? '请求失败'
          : '请求失败: ${body ?? res.statusCode}',
      'code': body is Map ? body['code'] : res.statusCode,
    };
  }

  // web端密码登录
  static Future liginInByWebPwd() async {}

  // app端验证码
  static Future sendAppSmsCode({
    int? cid,
    required int tel,
    required String token,
    required String challenge,
    required String validate,
    required String seccode,
  }) async {
    Map<String, dynamic> data = {
      'cid': cid,
      'tel': tel,
      'login_session_id': const Uuid().v4().replaceAll('-', ''),
      'recaptcha_token': token,
      'gee_challenge': challenge,
      'gee_validate': validate,
      'gee_seccode': seccode,
      'channel': 'bili',
      'buvid': buvid(),
      'local_id': buvid(),
      // 'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'statistics': {
        "appId": 1,
        "platform": 3,
        "version": "7.52.0",
        "abtest": ""
      },
    };
    // FormData formData = FormData.fromMap({...data});
    var res = await Request().post(
      Api.appSmsCode,
      data: data,
    );
    return res;
  }

  static String buvid() {
    var mac = <String>[];
    var random = Random();

    for (var i = 0; i < 6; i++) {
      var min = 0;
      var max = 0xff;
      var num = (random.nextInt(max - min + 1) + min).toRadixString(16);
      mac.add(num);
    }

    var md5Str = md5.convert(utf8.encode(mac.join(':'))).toString();
    var md5Arr = md5Str.split('');
    return 'XY${md5Arr[2]}${md5Arr[12]}${md5Arr[22]}$md5Str';
  }

  // 获取盐hash跟PubKey
  static Future getWebKey() async {
    var res = await Request().get(Api.getWebKey,
        data: {'disable_rcmd': 0, 'local_id': LoginUtils.generateBuvid()});
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': {}, 'msg': res.data['message']};
    }
  }

  // app端密码登录
  static Future loginInByMobPwd({
    required String tel,
    required String password,
    required String key,
    required String rhash,
  }) async {
    dynamic publicKey = RSAKeyParser().parse(key);
    String passwordEncryptyed =
        Encrypter(RSA(publicKey: publicKey)).encrypt(rhash + password).base64;
    Map<String, dynamic> data = {
      'username': tel,
      'password': passwordEncryptyed,
      'local_id': LoginUtils.generateBuvid(),
      'disable_rcmd': "0",
    };
    var res = await Request().post(
      Api.loginInByPwdApi,
      data: data,
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
        'headers': res.headers,
      };
    } else {
      return {
        'status': false,
        'data': res.data['data'] ?? [],
        'msg': res.data['message'],
      };
    }
  }

  // web端密码登录
  static Future loginInByWebPwd({
    required int username,
    required String password,
    required String token,
    required String challenge,
    required String validate,
    required String seccode,
  }) async {
    Map data = {
      'username': username,
      'password': password,
      'keep': 0,
      'token': token,
      'challenge': challenge,
      'validate': validate,
      'seccode': seccode,
      'source': 'main-fe-header',
      "go_url": HttpString.baseUrl
    };
    FormData formData = FormData.fromMap({...data});
    var res = await Request().post(
      Api.loginInByWebPwd,
      data: formData,
    );
    if (res.data['code'] == 0) {
      if (res.data['data']['status'] == 0) {
        return {
          'status': true,
          'data': res.data['data'],
          'headers': res.headers,
        };
      } else {
        return {
          'status': false,
          'code': 1,
          'data': res.data['data'],
          'msg': res.data['data']['message'],
        };
      }
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }

  // web端登录二维码
  static Future getWebQrcode() async {
    var res = await Request().get(Api.qrCodeApi);
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
        'headers': res.headers,
      };
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // web端二维码轮询登录状态
  static Future queryWebQrcodeStatus(String qrcodeKey) async {
    var res = await Request()
        .get(Api.loginInByQrcode, data: {'qrcode_key': qrcodeKey});
    if (res.data['data']['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
        'headers': res.headers,
      };
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }
}
