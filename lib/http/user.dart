import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:html/parser.dart';
import 'package:pilipala/models/video/later.dart';
import '../common/constants.dart';
import '../models/model_hot_video_item.dart';
import '../models/user/fav_detail.dart';
import '../models/user/fav_folder.dart';
import '../models/user/history.dart';
import '../models/user/info.dart';
import '../models/user/stat.dart';
import '../models/user/sub_detail.dart';
import '../models/user/sub_folder.dart';
import '../tv/models/tv_video_card_data.dart';
import '../utils/storage.dart';
import 'api.dart';
import 'init.dart';
import 'login.dart';

class UserHttp {
  static Future<dynamic> userStat({required int mid}) async {
    var res = await Request().get(Api.userStat, data: {'vmid': mid});
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false};
    }
  }

  static Future<dynamic> userInfo() async {
    var res = await Request().get(Api.userInfo);
    if (res.data['code'] == 0) {
      UserInfoData data = UserInfoData.fromJson(res.data['data']);
      return {'status': true, 'data': data};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  static Future<dynamic> tvUserInfoByAccessKey({
    required String accessKey,
  }) async {
    if (accessKey.isEmpty) {
      return {'status': false, 'msg': 'access_key 为空'};
    }
    final Map<String, dynamic> params =
        await LoginHttp.signedTvParams(<String, dynamic>{
      'access_key': accessKey,
    });
    final Response<dynamic> res = await Request.dio.get(
      Api.tvUserInfo,
      queryParameters: params,
      options: Options(
        headers: <String, dynamic>{'user-agent': LoginHttp.tvUserAgent},
      ),
    );
    final dynamic body = res.data;
    if (body is Map && body['code'] == 0 && body['data'] is Map) {
      return {
        'status': true,
        'data': _tvAccountToUserInfo(
          Map<String, dynamic>.from(body['data'] as Map),
        ),
      };
    }
    return {
      'status': false,
      'msg': body is Map
          ? body['message']?.toString() ?? 'TV 登录状态无效'
          : 'TV 登录状态无效',
      'code': body is Map ? body['code'] : res.statusCode,
    };
  }

  static UserInfoData _tvAccountToUserInfo(Map<String, dynamic> data) {
    final Map<String, dynamic> vip = data['vip'] is Map
        ? Map<String, dynamic>.from(data['vip'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> levelInfo = data['level_info'] is Map
        ? Map<String, dynamic>.from(data['level_info'] as Map)
        : <String, dynamic>{
            'current_level': _toInt(data['level']),
            'current_min': 0,
            'current_exp': 0,
            'next_exp': 0,
          };
    final int mid = _toInt(data['mid']);
    return UserInfoData.fromJson(<String, dynamic>{
      'isLogin': data['is_login'] ?? mid > 0,
      'email_verified': _toInt(data['email_status']),
      'face': data['face']?.toString() ?? '',
      'level_info': levelInfo,
      'mid': mid,
      'mobile_verified': _toInt(data['tel_status']),
      'money': _toDouble(data['coins']),
      'moral': 0,
      'official': data['official'] ?? <String, dynamic>{},
      'officialVerify': data['official'] ?? <String, dynamic>{},
      'pendant': data['pendant'] ?? <String, dynamic>{},
      'scores': 0,
      'uname': data['name']?.toString() ??
          data['uname']?.toString() ??
          data['guest_name']?.toString() ??
          '',
      'vipDueDate': _toInt(vip['due_date'] ?? vip['vip_due_date']),
      'vipStatus': _toInt(vip['status'] ?? vip['vip_status']),
      'vipType': _toInt(vip['type'] ?? vip['vip_type']),
      'vip_pay_type': _toInt(vip['pay_type'] ?? vip['vip_pay_type']),
      'vip_theme_type': _toInt(vip['theme_type'] ?? vip['vip_theme_type']),
      'vip_label': vip['label'] ?? vip['vip_label'] ?? <String, dynamic>{},
      'vip_avatar_subscript': _toInt(
        vip['avatar_subscript'] ?? vip['vip_avatar_subscript'],
      ),
      'vip_nickname_color':
          vip['nickname_color']?.toString() ?? vip['vip_nickname_color'],
      'wallet': data['wallet'] ?? <String, dynamic>{},
      'has_shop': false,
      'shop_url': '',
    });
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<dynamic> userStatOwner() async {
    var res = await Request().get(Api.userStatOwner);
    if (res.data['code'] == 0) {
      UserStat data = UserStat.fromJson(res.data['data']);
      return {'status': true, 'data': data};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  static String cachedAccessKey() {
    final dynamic accessKeyInfo = GStrorage.localCache.get(
      LocalCacheKey.accessKey,
      defaultValue: const <String, Object>{},
    );
    if (accessKeyInfo is Map) {
      return accessKeyInfo['value']?.toString() ?? '';
    }
    return '';
  }

  static int _tvInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int tvInt(dynamic value) => _tvInt(value);

  static String _tvString(dynamic value) => value?.toString() ?? '';

  static List<dynamic> _tvList(dynamic value) {
    if (value is List) {
      return value;
    }
    return const <dynamic>[];
  }

  static TvVideoCardData _tvCardFromMap(Map<dynamic, dynamic> json) {
    final Map<dynamic, dynamic> upper = json['upper'] is Map
        ? json['upper'] as Map
        : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> owner = json['owner'] is Map
        ? json['owner'] as Map
        : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> uploader = json['uploader'] is Map
        ? json['uploader'] as Map
        : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> ugcExt = json['ugc_ext'] is Map
        ? json['ugc_ext'] as Map
        : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> infocExt = json['infoc_ext'] is Map
        ? json['infoc_ext'] as Map
        : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> jumpInfo = json['jump_info'] is Map
        ? json['jump_info'] as Map
        : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> page =
        json['page'] is Map ? json['page'] as Map : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> playerArgs = json['player_args'] is Map
        ? json['player_args'] as Map
        : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> stat =
        json['stat'] is Map ? json['stat'] as Map : const <dynamic, dynamic>{};
    final List<dynamic> playList = _tvList(json['play_list']);
    final Map<dynamic, dynamic> firstPlay =
        playList.isNotEmpty && playList.first is Map
            ? playList.first as Map
            : const <dynamic, dynamic>{};

    final int aid = _tvInt(
      json['aid'] ??
          json['oid'] ??
          json['id'] ??
          json['param'] ??
          json['card_id'] ??
          jumpInfo['video_id'] ??
          jumpInfo['VideoId'] ??
          playerArgs['aid'] ??
          ugcExt['aid'] ??
          infocExt['aid'],
    );
    final int cid = _tvInt(
      json['cid'] ??
          playerArgs['cid'] ??
          firstPlay['cid'] ??
          page['cid'] ??
          page['id'] ??
          ugcExt['cid'] ??
          ugcExt['first_cid'] ??
          infocExt['cid'],
    );
    final String bvid = _tvString(
      json['bvid'] ??
          json['bv_id'] ??
          json['bvid_str'] ??
          json['bv'] ??
          ugcExt['bvid'] ??
          ugcExt['bv_id'],
    );
    final String title = _tvString(
      json['title'] ??
          json['hover_title'] ??
          json['long_title'] ??
          json['name'] ??
          page['title'] ??
          firstPlay['title'] ??
          ugcExt['title'],
    );
    final String cover = _tvString(
      json['cover'] ??
          json['horizontal_url'] ??
          json['vertical_url'] ??
          json['pic'] ??
          json['poster'] ??
          json['card_cover'] ??
          json['image'] ??
          firstPlay['cover'] ??
          ugcExt['cover'],
    );
    final String ownerName = _tvString(
      upper['name'] ??
          upper['uname'] ??
          owner['name'] ??
          owner['uname'] ??
          uploader['up_name'] ??
          uploader['name'] ??
          uploader['uname'] ??
          ugcExt['up_name'] ??
          json['author'] ??
          json['author_name'] ??
          json['up_name'],
    );
    final String desc = _tvString(
      json['desc'] ??
          json['description'] ??
          json['hover_subtitle'] ??
          json['subtitle'] ??
          json['subtitle2'] ??
          firstPlay['subtitle'] ??
          ugcExt['desc'] ??
          json['intro'] ??
          stat['view'],
    );

    return TvVideoCardData(
      title: title.isEmpty ? '未命名视频' : title,
      cover: cover.startsWith('//') ? 'https:$cover' : cover,
      bvid: bvid,
      cid: cid,
      aid: aid,
      ownerName: ownerName.isEmpty ? '未知UP' : ownerName,
      duration: _tvInt(
        json['duration'] ??
            playerArgs['duration'] ??
            firstPlay['duration'] ??
            ugcExt['duration'],
      ),
      subtitle: desc.isEmpty ? null : desc,
      desc: desc.isEmpty ? null : desc,
    );
  }

  static Future<dynamic> tvHistoryListByAccessKey({
    required String accessKey,
    int pn = 1,
    int ps = 20,
  }) async {
    if (accessKey.isEmpty) {
      return {'status': false, 'msg': 'access_key 为空'};
    }
    final Map<String, dynamic> params =
        await LoginHttp.signedTvParams(<String, dynamic>{
      'access_key': accessKey,
      'pn': pn,
      'ps': ps,
    });
    final Response<dynamic> res = await Request.dio.get(
      '${Api.tvHistory}?${LoginHttp.tvEncodedQuery(params)}',
      options: Options(
          headers: <String, dynamic>{'user-agent': LoginHttp.tvUserAgent}),
    );
    final dynamic body = res.data;
    if (body is Map && body['code'] == 0) {
      final List<TvVideoCardData> cards = _tvList(body['data'])
          .whereType<Map>()
          .map(_tvCardFromMap)
          .where((TvVideoCardData item) => item.aid > 0 || item.bvid.isNotEmpty)
          .toList(growable: false);
      return {'status': true, 'data': cards};
    }
    return {
      'status': false,
      'data': <TvVideoCardData>[],
      'msg': body is Map ? body['message']?.toString() ?? '加载历史失败' : '加载历史失败',
      'code': body is Map ? body['code'] : res.statusCode,
    };
  }

  static Future<dynamic> tvWatchLaterByAccessKey({
    required String accessKey,
    int pn = 1,
    int ps = 20,
  }) async {
    if (accessKey.isEmpty) {
      return {'status': false, 'msg': 'access_key 为空'};
    }
    final Map<String, dynamic> params =
        await LoginHttp.signedTvParams(<String, dynamic>{
      'access_key': accessKey,
      'pn': pn,
      'ps': ps,
      'login_guide_type': '',
    });
    final Response<dynamic> res = await Request.dio.get(
      '${Api.tvWatchLater}?${LoginHttp.tvEncodedQuery(params)}',
      options: Options(
          headers: <String, dynamic>{'user-agent': LoginHttp.tvUserAgent}),
    );
    final dynamic body = res.data;
    if (body is Map && body['code'] == 0 && body['data'] is Map) {
      final dynamic list = (body['data'] as Map)['cards'];
      final List<TvVideoCardData> cards = _tvList(list)
          .whereType<Map>()
          .map(_tvCardFromMap)
          .where((TvVideoCardData item) => item.aid > 0 || item.bvid.isNotEmpty)
          .toList(growable: false);
      return {'status': true, 'data': cards};
    }
    return {
      'status': false,
      'data': <TvVideoCardData>[],
      'msg':
          body is Map ? body['message']?.toString() ?? '加载稍后再看失败' : '加载稍后再看失败',
      'code': body is Map ? body['code'] : res.statusCode,
    };
  }

  static Future<dynamic> tvFavoritesByAccessKey({
    required String accessKey,
    int fid = 0,
    int pn = 1,
  }) async {
    if (accessKey.isEmpty) {
      return {'status': false, 'msg': 'access_key 为空'};
    }
    final Map<String, dynamic> params =
        await LoginHttp.signedTvParams(<String, dynamic>{
      'fid': fid,
      'pn': pn,
      'access_key': accessKey,
      'login_guide_type': '',
    });
    final Response<dynamic> res = await Request.dio.get(
      '${Api.tvFavorites}?${LoginHttp.tvEncodedQuery(params)}',
      options: Options(
          headers: <String, dynamic>{'user-agent': LoginHttp.tvUserAgent}),
    );
    final dynamic body = res.data;
    if (body is Map && body['code'] == 0 && body['data'] is Map) {
      final dynamic list = (body['data'] as Map)['list'];
      final List<TvVideoCardData> cards = _tvList(list)
          .whereType<Map>()
          .map(_tvCardFromMap)
          .where((TvVideoCardData item) => item.aid > 0 || item.bvid.isNotEmpty)
          .toList(growable: false);
      return {'status': true, 'data': cards};
    }
    return {
      'status': false,
      'data': <TvVideoCardData>[],
      'msg': body is Map ? body['message']?.toString() ?? '加载收藏失败' : '加载收藏失败',
      'code': body is Map ? body['code'] : res.statusCode,
    };
  }

  static Future<dynamic> tvFavoriteFoldersByAccessKey({
    required String accessKey,
  }) async {
    if (accessKey.isEmpty) {
      return {'status': false, 'msg': 'access_key 为空'};
    }
    final Map<String, dynamic> params =
        await LoginHttp.signedTvParams(<String, dynamic>{
      'access_key': accessKey,
      'aid': '',
      'login_guide_type': '',
    });
    final Response<dynamic> res = await Request.dio.get(
      '${Api.tvFavoritesFolders}?${LoginHttp.tvEncodedQuery(params)}',
      options: Options(
          headers: <String, dynamic>{'user-agent': LoginHttp.tvUserAgent}),
    );
    final dynamic body = res.data;
    if (body is Map && body['code'] == 0) {
      return {
        'status': true,
        'data': _tvList(body['data']).whereType<Map>().toList(growable: false),
      };
    }
    return {
      'status': false,
      'data': <Map<dynamic, dynamic>>[],
      'msg': body is Map ? body['message']?.toString() ?? '加载收藏夹失败' : '加载收藏夹失败',
      'code': body is Map ? body['code'] : res.statusCode,
    };
  }

  // 收藏夹
  static Future<dynamic> userfavFolder({
    required int pn,
    required int ps,
    required int mid,
  }) async {
    var res = await Request().get(Api.userFavFolder, data: {
      'pn': pn,
      'ps': ps,
      'up_mid': mid,
    });
    if (res.data['code'] == 0) {
      late FavFolderData data;
      if (res.data['data'] != null) {
        data = FavFolderData.fromJson(res.data['data']);
        return {'status': true, 'data': data};
      } else {
        return {'status': false, 'msg': '收藏夹为空'};
      }
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
        'code': res.data['code'],
      };
    }
  }

  static Future<dynamic> userFavFolderDetail(
      {required int mediaId,
      required int pn,
      required int ps,
      String keyword = '',
      String order = 'mtime',
      int type = 0}) async {
    var res = await Request().get(Api.userFavFolderDetail, data: {
      'media_id': mediaId,
      'pn': pn,
      'ps': ps,
      'keyword': keyword,
      'order': order,
      'type': type,
      'tid': 0,
      'platform': 'web'
    });
    if (res.data['code'] == 0) {
      FavDetailData data = FavDetailData.fromJson(res.data['data']);
      return {'status': true, 'data': data};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // 稍后再看
  static Future<dynamic> seeYouLater() async {
    var res = await Request().get(Api.seeYouLater);
    if (res.data['code'] == 0) {
      if (res.data['data']['count'] == 0) {
        return {
          'status': true,
          'data': {'list': [], 'count': 0}
        };
      }
      List<HotVideoItemModel> list = [];
      for (var i in res.data['data']['list']) {
        list.add(HotVideoItemModel.fromJson(i));
      }
      return {
        'status': true,
        'data': {'list': list, 'count': res.data['data']['count']}
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
        'code': res.data['code'],
      };
    }
  }

  // 观看历史
  static Future historyList(int? max, int? viewAt) async {
    var res = await Request().get(Api.historyList, data: {
      'type': 'all',
      'ps': 20,
      'max': max ?? 0,
      'view_at': viewAt ?? 0,
    });
    if (res.data['code'] == 0) {
      return {'status': true, 'data': HistoryData.fromJson(res.data['data'])};
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
        'code': res.data['code'],
      };
    }
  }

  // 暂停观看历史
  static Future pauseHistory(bool switchStatus) async {
    // 暂停switchStatus传true 否则false
    var res = await Request().post(
      Api.pauseHistory,
      data: {
        'switch': switchStatus,
        'jsonp': 'jsonp',
        'csrf': await Request.getCsrf(),
      },
    );
    return res;
  }

  // 观看历史暂停状态
  static Future historyStatus() async {
    var res = await Request().get(Api.historyStatus);
    return res;
  }

  // 清空历史记录
  static Future clearHistory() async {
    var res = await Request().post(
      Api.clearHistory,
      data: {
        'jsonp': 'jsonp',
        'csrf': await Request.getCsrf(),
      },
    );
    return res;
  }

  // 稍后再看
  static Future toViewLater({String? bvid, dynamic aid}) async {
    var data = {'csrf': await Request.getCsrf()};
    if (bvid != null) {
      data['bvid'] = bvid;
    } else if (aid != null) {
      data['aid'] = aid;
    }
    var res = await Request().post(
      Api.toViewLater,
      data: data,
    );
    if (res.data['code'] == 0) {
      return {'status': true, 'msg': 'yeah！稍后再看'};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 移除已观看
  static Future toViewDel({int? aid}) async {
    final Map<String, dynamic> params = {
      'jsonp': 'jsonp',
      'csrf': await Request.getCsrf(),
    };

    params[aid != null ? 'aid' : 'viewed'] = aid ?? true;
    var res = await Request().post(
      Api.toViewDel,
      data: params,
    );
    if (res.data['code'] == 0) {
      return {'status': true, 'msg': 'yeah！成功移除'};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 获取用户凭证 失效
  static Future thirdLogin() async {
    var res = await Request().get(
      'https://passport.bilibili.com/login/app/third',
      data: {
        'appkey': Constants.appKey,
        'api': Constants.thirdApi,
        'sign': Constants.thirdSign,
      },
    );
    try {
      if (res.data['code'] == 0 && res.data['data']['has_login'] == 1) {
        Request().get(res.data['data']['confirm_uri']);
      }
    } catch (err) {
      SmartDialog.showNotify(msg: '获取用户凭证: $err', notifyType: NotifyType.error);
    }
  }

  // 清空稍后再看
  static Future toViewClear() async {
    var res = await Request().post(
      Api.toViewClear,
      data: {
        'jsonp': 'jsonp',
        'csrf': await Request.getCsrf(),
      },
    );
    if (res.data['code'] == 0) {
      return {'status': true, 'msg': '操作完成'};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 删除历史记录
  static Future delHistory(kid) async {
    var res = await Request().post(
      Api.delHistory,
      data: {
        'kid': kid,
        'jsonp': 'jsonp',
        'csrf': await Request.getCsrf(),
      },
    );
    if (res.data['code'] == 0) {
      return {'status': true, 'msg': '已删除'};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  static Future hasFollow(int mid) async {
    var res = await Request().get(
      Api.hasFollow,
      data: {
        'fid': mid,
      },
    );
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }
  // // 相互关系查询
  // static Future relationSearch(int mid) async {
  //   Map params = await WbiSign().makSign({
  //     'mid': mid,
  //     'token': '',
  //     'platform': 'web',
  //     'web_location': 1550101,
  //   });
  //   var res = await Request().get(
  //     Api.relationSearch,
  //     data: {
  //       'mid': mid,
  //       'w_rid': params['w_rid'],
  //       'wts': params['wts'],
  //     },
  //   );
  //   if (res.data['code'] == 0) {
  //     // relation 主动状态
  //     // 被动状态
  //     return {'status': true, 'data': res.data['data']};
  //   } else {
  //     return {'status': false, 'msg': res.data['message']};
  //   }
  // }

  // 搜索历史记录
  static Future searchHistory(
      {required int pn, required String keyword}) async {
    var res = await Request().get(
      Api.searchHistory,
      data: {
        'pn': pn,
        'keyword': keyword,
        'business': 'all',
      },
    );
    if (res.data['code'] == 0) {
      return {'status': true, 'data': HistoryData.fromJson(res.data['data'])};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 我的订阅
  static Future userSubFolder({
    required int mid,
    required int pn,
    required int ps,
  }) async {
    var res = await Request().get(Api.userSubFolder, data: {
      'up_mid': mid,
      'ps': ps,
      'pn': pn,
      'platform': 'web',
    });
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': SubFolderModelData.fromJson(res.data['data'])
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
        'code': res.data['code'],
      };
    }
  }

  static Future userSeasonList({
    required int seasonId,
    required int pn,
    required int ps,
  }) async {
    var res = await Request().get(Api.userSeasonList, data: {
      'season_id': seasonId,
      'ps': ps,
      'pn': pn,
    });
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': SubDetailModelData.fromJson(res.data['data'])
      };
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  static Future userResourceList({
    required int seasonId,
    required int pn,
    required int ps,
  }) async {
    var res = await Request().get(Api.userResourceList, data: {
      'media_id': seasonId,
      'ps': ps,
      'pn': pn,
      'keyword': '',
      'order': 'mtime',
      'type': 0,
      'tid': 0,
      'platform': 'web',
    });
    if (res.data['code'] == 0) {
      try {
        return {
          'status': true,
          'data': SubDetailModelData.fromJson(res.data['data'])
        };
      } catch (err) {
        return {'status': false, 'msg': err};
      }
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 取消订阅
  static Future cancelSub({required int seasonId}) async {
    var res = await Request().post(
      Api.cancelSub,
      data: {
        'platform': 'web',
        'season_id': seasonId,
        'csrf': await Request.getCsrf(),
      },
    );
    if (res.data['code'] == 0) {
      return {'status': true};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 删除文件夹
  static Future delFavFolder({required int mediaIds}) async {
    var res = await Request().post(
      Api.delFavFolder,
      data: {
        'media_ids': mediaIds,
        'platform': 'web',
        'csrf': await Request.getCsrf(),
      },
    );
    if (res.data['code'] == 0) {
      return {'status': true};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 稍后再看播放全部
  // static Future toViewPlayAll({required int oid, required String bvid}) async {
  //   var res = await Request().get(
  //     Api.watchLaterHtml,
  //     data: {
  //       'oid': oid,
  //       'bvid': bvid,
  //     },
  //   );
  //   String scriptContent =
  //       extractScriptContents(parse(res.data).body!.outerHtml)[0];
  //   int startIndex = scriptContent.indexOf('{');
  //   int endIndex = scriptContent.lastIndexOf('};');
  //   String jsonContent = scriptContent.substring(startIndex, endIndex + 1);
  //   // 解析JSON字符串为Map
  //   Map<String, dynamic> jsonData = json.decode(jsonContent);
  //   // 输出解析后的数据
  //   return {
  //     'status': true,
  //     'data': jsonData['resourceList']
  //         .map((e) => MediaVideoItemModel.fromJson(e))
  //         .toList()
  //   };
  // }

  static List<String> extractScriptContents(String htmlContent) {
    RegExp scriptRegExp = RegExp(r'<script>([\s\S]*?)<\/script>');
    Iterable<Match> matches = scriptRegExp.allMatches(htmlContent);
    List<String> scriptContents = [];
    for (Match match in matches) {
      String scriptContent = match.group(1)!;
      scriptContents.add(scriptContent);
    }
    return scriptContents;
  }

  // 稍后再看列表
  static Future getMediaList({
    required int type,
    required int bizId,
    required int ps,
    int? oid,
  }) async {
    var res = await Request().get(
      Api.mediaList,
      data: {
        'mobi_app': 'web',
        'type': type,
        'biz_id': bizId,
        'oid': oid ?? '',
        'otype': 2,
        'ps': ps,
        'direction': false,
        'desc': true,
        'sort_field': 1,
        'tid': 0,
        'with_current': false,
      },
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data']['media_list'] != null
            ? res.data['data']['media_list']
                .map<MediaVideoItemModel>(
                    (e) => MediaVideoItemModel.fromJson(e))
                .toList()
            : []
      };
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 解析收藏夹视频
  static Future parseFavVideo({
    required int mediaId,
    required int oid,
    required String bvid,
  }) async {
    var res = await Request().get(
      'https://www.bilibili.com/list/ml$mediaId',
      data: {
        'oid': mediaId,
        'bvid': bvid,
      },
    );
    String scriptContent =
        extractScriptContents(parse(res.data).body!.outerHtml)[0];
    int startIndex = scriptContent.indexOf('{');
    int endIndex = scriptContent.lastIndexOf('};');
    String jsonContent = scriptContent.substring(startIndex, endIndex + 1);
    // 解析JSON字符串为Map
    Map<String, dynamic> jsonData = json.decode(jsonContent);
    return {
      'status': true,
      'data': jsonData['resourceList']
          .map<MediaVideoItemModel>((e) => MediaVideoItemModel.fromJson(e))
          .toList()
    };
  }
}
