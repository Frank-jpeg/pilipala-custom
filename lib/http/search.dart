import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'package:pilipala/models/search/all.dart';
import 'package:pilipala/utils/wbi_sign.dart';
import '../models/bangumi/info.dart';
import '../models/common/search_type.dart';
import '../models/search/hot.dart';
import '../models/search/result.dart';
import '../models/search/suggest.dart';
import '../utils/id_utils.dart';
import '../utils/storage.dart';
import 'index.dart';
import 'login.dart';
import 'user.dart';

class SearchHttp {
  static Box setting = GStrorage.setting;
  static Future hotSearchList() async {
    var res = await Request().get(Api.hotSearchList);
    if (res.data is String) {
      Map<String, dynamic> resultMap = json.decode(res.data);
      if (resultMap['code'] == 0) {
        return {
          'status': true,
          'data': HotSearchModel.fromJson(resultMap),
        };
      }
    } else if (res.data is Map<String, dynamic> && res.data['code'] == 0) {
      return {
        'status': true,
        'data': HotSearchModel.fromJson(res.data),
      };
    }

    return {
      'status': false,
      'data': [],
      'msg': '请求错误 🙅',
    };
  }

  // 获取搜索建议
  static Future searchSuggest({required term}) async {
    var res = await Request().get(Api.searchSuggest,
        data: {'term': term, 'main_ver': 'v1', 'highlight': term});
    if (res.data is String) {
      Map<String, dynamic> resultMap = json.decode(res.data);
      if (resultMap['code'] == 0) {
        if (resultMap['result'] is Map) {
          resultMap['result']['term'] = term;
        }
        return {
          'status': true,
          'data': resultMap['result'] is Map
              ? SearchSuggestModel.fromJson(resultMap['result'])
              : [],
        };
      } else {
        return {
          'status': false,
          'data': [],
          'msg': '请求错误 🙅',
        };
      }
    } else {
      return {
        'status': false,
        'data': [],
        'msg': '请求错误 🙅',
      };
    }
  }

  // 分类搜索
  static Future searchByType({
    required SearchType searchType,
    required String keyword,
    required page,
    String? order,
    int? duration,
    int? tids,
  }) async {
    var reqData = {
      'search_type': searchType.type,
      'keyword': keyword,
      // 'order_sort': 0,
      // 'user_type': 0,
      'page': page,
      'page_size': 20,
      'platform': 'pc',
      'web_location': 1430654,
      if (order != null) 'order': order,
      if (duration != null) 'duration': duration,
      if (tids != null && tids != -1) 'tids': tids,
    };
    final Map params = await WbiSign().makSign(reqData);
    var res = await Request().get(Api.searchByType, data: params);
    if (res.data is! Map) {
      return {
        'status': false,
        'data': [],
        'msg': '搜索返回异常',
      };
    }
    final Map dataMap = res.data as Map;
    if (dataMap['code'] == 0) {
      if (dataMap['data'] is! Map) {
        return {'status': true, 'data': Data()};
      }
      final Map<String, dynamic> searchData =
          Map<String, dynamic>.from(dataMap['data'] as Map);
      if (searchData['numPages'] == 0) {
        // 我想返回数据，使得可以通过data.list 取值，结果为[]
        return {'status': true, 'data': Data()};
      }
      Object data;
      try {
        switch (searchType) {
          case SearchType.video:
            List<int> blackMidsList =
                setting.get(SettingBoxKey.blackMidsList, defaultValue: [-1]);
            for (var i in searchData['result'] ?? []) {
              // 屏蔽推广和拉黑用户
              if (i is Map) {
                i['available'] = !blackMidsList.contains(i['mid']);
              }
            }
            data = SearchVideoModel.fromJson(searchData);
            break;
          case SearchType.live_room:
            data = SearchLiveModel.fromJson(searchData);
            break;
          case SearchType.bili_user:
            data = SearchUserModel.fromJson(searchData);
            break;
          case SearchType.media_bangumi:
            data = SearchMBangumiModel.fromJson(searchData);
            break;
          case SearchType.article:
            data = SearchArticleModel.fromJson(searchData);
            break;
        }
        return {
          'status': true,
          'data': data,
        };
      } catch (err) {
        return {
          'status': false,
          'data': [],
          'msg': '搜索解析失败: $err',
        };
      }
    } else {
      return {
        'status': false,
        'data': [],
        'msg': dataMap['message']?.toString() ?? '搜索失败',
      };
    }
  }

  static Future<Map<String, dynamic>> tvSearchVideo({
    required String keyword,
    int page = 1,
  }) async {
    if (keyword.trim().isEmpty) {
      return {
        'status': true,
        'data': SearchVideoModel(list: <SearchVideoItemModel>[]),
      };
    }
    final String accessKey = UserHttp.cachedAccessKey();
    try {
      final Map<String, dynamic> params =
          await LoginHttp.signedTvParams(<String, dynamic>{
        'keyword': keyword.trim(),
        'page': page,
        'category': '0',
        'search_type': 'tv_ugc',
        'order': 'totalrank',
        'search_trace': _searchTrace(),
        if (accessKey.isNotEmpty) 'access_key': accessKey,
        'sug_index': 0,
        'term': '',
        'keyword_from': '',
        'ugc_order': 'default',
        'pagesize': 20,
      });
      final Response<dynamic> res = await Request.dio.get(
        '${Api.tvSearchV2}?${LoginHttp.tvEncodedQuery(params)}',
        options: Options(
          headers: <String, dynamic>{'user-agent': LoginHttp.tvUserAgent},
        ),
      );
      final dynamic body = res.data;
      if (body is Map && body['code'] == 0 && body['data'] is Map) {
        final List<SearchVideoItemModel> items =
            _parseTvSearchItems(Map<dynamic, dynamic>.from(body['data'] as Map));
        return {
          'status': true,
          'data': SearchVideoModel(list: items),
          'source': 'tv',
        };
      }
      final String msg = body is Map
          ? body['message']?.toString() ?? 'TV 搜索失败'
          : 'TV 搜索失败: ${body ?? res.statusCode}';
      return {
        'status': false,
        'data': SearchVideoModel(list: <SearchVideoItemModel>[]),
        'msg': msg,
        'code': body is Map ? body['code'] : res.statusCode,
        'source': 'tv',
        'authInvalid': UserHttp.isTvAuthInvalidCode(
          body is Map ? body['code'] : res.statusCode,
        ),
      };
    } catch (e) {
      return {
        'status': false,
        'data': SearchVideoModel(list: <SearchVideoItemModel>[]),
        'msg': 'TV 搜索失败: $e',
        'source': 'tv',
      };
    }
  }

  static String _searchTrace() {
    final Random random = Random();
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int tail = random.nextInt(0x7fffffff);
    return '$now$tail';
  }

  static List<SearchVideoItemModel> _parseTvSearchItems(
    Map<dynamic, dynamic> data,
  ) {
    final List<Map<String, dynamic>> rawItems = <Map<String, dynamic>>[];
    void addItems(dynamic value) {
      if (value is! List) {
        return;
      }
      for (final dynamic item in value) {
        if (item is Map) {
          rawItems.add(Map<String, dynamic>.from(item));
        }
      }
    }

    addItems(data['ugc']);
    final dynamic resultAll = data['resultall'];
    if (resultAll is Map) {
      addItems(resultAll['tvugc']);
    }
    final dynamic resultV2 = data['result_v2'];
    if (resultV2 is List) {
      for (final dynamic module in resultV2) {
        if (module is Map) {
          addItems(module['list']);
        }
      }
    }

    final List<SearchVideoItemModel> items = <SearchVideoItemModel>[];
    final Set<String> seen = <String>{};
    int dropped = 0;
    int duplicated = 0;
    for (final Map<String, dynamic> raw in rawItems) {
      final Map<String, dynamic> mapped = _mapTvSearchItem(raw);
      final int aid = UserHttp.tvInt(mapped['aid'] ?? mapped['id']);
      final String bvid = (mapped['bvid']?.toString() ?? '').isNotEmpty
          ? mapped['bvid'].toString()
          : aid > 0
              ? IdUtils.av2bv(aid)
              : '';
      final String key = bvid.isNotEmpty ? bvid : aid.toString();
      if (bvid.isEmpty && aid <= 0) {
        dropped++;
        continue;
      }
      if (seen.contains(key)) {
        duplicated++;
        continue;
      }
      seen.add(key);
      items.add(SearchVideoItemModel.fromJson(mapped));
    }
    _logTvSearchParseSummary(
      rawCount: rawItems.length,
      parsedCount: items.length,
      droppedCount: dropped,
      duplicatedCount: duplicated,
    );
    return items;
  }

  @visibleForTesting
  static List<SearchVideoItemModel> debugParseTvSearchItems(
    Map<dynamic, dynamic> data,
  ) {
    return _parseTvSearchItems(data);
  }

  static void _logTvSearchParseSummary({
    required int rawCount,
    required int parsedCount,
    required int droppedCount,
    required int duplicatedCount,
  }) {
    if (!kDebugMode && droppedCount == 0) {
      return;
    }
    developer.log(
      'TV search parse raw=$rawCount parsed=$parsedCount '
      'dropped=$droppedCount duplicated=$duplicatedCount',
      name: 'SearchHttp',
    );
  }

  static Map<String, dynamic> _mapTvSearchItem(Map<String, dynamic> raw) {
    final Map<String, dynamic> upper = raw['upper'] is Map
        ? Map<String, dynamic>.from(raw['upper'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> owner = raw['owner'] is Map
        ? Map<String, dynamic>.from(raw['owner'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> uploader = raw['uploader'] is Map
        ? Map<String, dynamic>.from(raw['uploader'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> ugcExt = raw['ugc_ext'] is Map
        ? Map<String, dynamic>.from(raw['ugc_ext'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> playerArgs = raw['player_args'] is Map
        ? Map<String, dynamic>.from(raw['player_args'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> autoPlay = raw['auto_play'] is Map
        ? Map<String, dynamic>.from(raw['auto_play'] as Map)
        : <String, dynamic>{};
    final List<dynamic> cidList =
        autoPlay['cid_list'] is List ? autoPlay['cid_list'] as List : const [];
    final Map<String, dynamic> firstCid =
        cidList.isNotEmpty && cidList.first is Map
            ? Map<String, dynamic>.from(cidList.first as Map)
            : <String, dynamic>{};
    final List<dynamic> playList =
        raw['play_list'] is List ? raw['play_list'] as List : const <dynamic>[];
    final Map<String, dynamic> firstPlay =
        playList.isNotEmpty && playList.first is Map
            ? Map<String, dynamic>.from(playList.first as Map)
            : <String, dynamic>{};

    final int aid = UserHttp.tvInt(
      raw['aid'] ??
          raw['id'] ??
          raw['card_id'] ??
          raw['param'] ??
          playerArgs['aid'] ??
          firstCid['aid'] ??
          ugcExt['aid'],
    );
    final String rawBvid = _string(
      raw['bvid'] ?? raw['bv_id'] ?? raw['bv'] ?? ugcExt['bvid'],
    );
    final String bvid = rawBvid.isNotEmpty
        ? rawBvid
        : aid > 0
            ? IdUtils.av2bv(aid)
            : '';
    final String cover = _string(
      raw['cover'] ??
          raw['horizonal_cover'] ??
          raw['horizontal_cover'] ??
          raw['pic'] ??
          firstPlay['cover'] ??
          ugcExt['cover'],
    );
    return <String, dynamic>{
      'type': 'video',
      'id': aid,
      'aid': aid,
      'bvid': bvid,
      'cid': UserHttp.tvInt(
        raw['cid'] ??
            playerArgs['cid'] ??
            firstCid['cid'] ??
            firstPlay['cid'] ??
            ugcExt['cid'] ??
            ugcExt['first_cid'],
      ),
      'mid': UserHttp.tvInt(
        raw['mid'] ?? upper['mid'] ?? owner['mid'] ?? uploader['mid'],
      ),
      'title': _string(raw['title'] ??
          raw['hover_title'] ??
          raw['name'] ??
          firstCid['title'] ??
          ugcExt['title']),
      'description': _string(
        raw['description'] ??
            raw['desc'] ??
            raw['subtitle'] ??
            raw['hover_subtitle'] ??
            raw['index_show'] ??
            raw['archive_view'] ??
            ugcExt['desc'],
      ),
      'pic': cover.startsWith('//') ? 'https:$cover' : cover,
      'duration': _string(
        raw['duration'] ??
          firstCid['duration'] ??
          firstPlay['duration'] ??
          ugcExt['duration'] ??
          '0:00',
      ),
      'author': _string(
        raw['uname'] ??
            raw['author'] ??
            upper['name'] ??
            upper['uname'] ??
            owner['name'] ??
            owner['uname'] ??
            uploader['name'] ??
            uploader['uname'] ??
            uploader['up_name'] ??
            ugcExt['up_name'],
      ),
      'upic': _string(raw['upAvatar'] ?? raw['img'] ?? owner['face']),
      'play': UserHttp.tvInt(raw['play'] ?? raw['archive_view']),
      'danmaku': UserHttp.tvInt(raw['danmaku']),
      'favorite': UserHttp.tvInt(raw['favorite']),
      'review': UserHttp.tvInt(raw['review']),
      'like': UserHttp.tvInt(raw['like']),
      'available': true,
    };
  }

  static String _string(dynamic value) => value?.toString() ?? '';

  static Future<int> ab2c({int? aid, String? bvid}) async {
    Map<String, dynamic> data = {};
    if (aid != null) {
      data['aid'] = aid;
    } else if (bvid != null) {
      data['bvid'] = bvid;
    }
    final dynamic res =
        await Request().get(Api.ab2c, data: <String, dynamic>{...data});
    if (res.data['code'] == 0) {
      return res.data['data'].first['cid'];
    } else {
      return -1;
    }
  }

  static Future<Map<String, dynamic>> bangumiInfo(
      {int? seasonId, int? epId}) async {
    final Map<String, dynamic> data = {};
    if (seasonId != null) {
      data['season_id'] = seasonId;
    } else if (epId != null) {
      data['ep_id'] = epId;
    }
    final dynamic res =
        await Request().get(Api.bangumiInfo, data: <String, dynamic>{...data});
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': BangumiInfoModel.fromJson(res.data['result']),
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': '请求错误 🙅',
      };
    }
  }

  static Future<Map<String, dynamic>> ab2cWithPic(
      {int? aid, String? bvid}) async {
    Map<String, dynamic> data = {};
    if (aid != null) {
      data['aid'] = aid;
    } else if (bvid != null) {
      data['bvid'] = bvid;
    }
    final dynamic res =
        await Request().get(Api.ab2c, data: <String, dynamic>{...data});
    return {
      'cid': res.data['data'].first['cid'],
      'pic': res.data['data'].first['first_frame'],
    };
  }

  static Future<Map<String, dynamic>> searchCount(
      {required String keyword}) async {
    Map<String, dynamic> data = {
      'keyword': keyword,
      'web_location': 333.999,
    };
    Map params = await WbiSign().makSign(data);
    final dynamic res = await Request().get(Api.searchCount, data: params);
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': SearchAllModel.fromJson(res.data['data']),
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': '请求错误 🙅',
      };
    }
  }
}

class Data {
  List<dynamic> list;

  Data({this.list = const []});
}
