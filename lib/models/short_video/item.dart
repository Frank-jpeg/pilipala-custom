import 'package:pilipala/models/model_owner.dart';
import 'package:pilipala/utils/id_utils.dart';

class ShortVideoItem {
  ShortVideoItem({
    this.aid,
    this.bvid,
    this.cid,
    this.title,
    this.pic,
    this.duration,
    this.width,
    this.height,
    this.owner,
    this.uri,
    this.isFollowed = 0,
    ShortVideoStat? stat,
  }) : stat = stat ?? ShortVideoStat();

  int? aid;
  String? bvid;
  int? cid;
  String? title;
  String? pic;
  int? duration;
  int? width;
  int? height;
  Owner? owner;
  String? uri;
  int? isFollowed;
  ShortVideoStat stat;

  bool get isVertical =>
      width != null && height != null && width! > 0 && height! > width!;

  static ShortVideoItem? fromAppFeedJson(Map<String, dynamic> json) {
    final playerArgs = json['player_args'];
    if (playerArgs is! Map) {
      return null;
    }

    final int? aid = _toInt(playerArgs['aid'] ?? json['param']);
    final int? cid = _toInt(playerArgs['cid']);
    if (aid == null || cid == null) {
      return null;
    }

    final String uri = json['uri']?.toString() ?? '';
    final String? rcmdReason = json['bottom_rcmd_reason']?.toString() ??
        json['top_rcmd_reason']?.toString();
    final bool isFollowed =
        rcmdReason != null && RegExp(r'已关注|新关注').hasMatch(rcmdReason);
    final args = json['args'];

    return ShortVideoItem(
      aid: aid,
      bvid: IdUtils.av2bv(aid),
      cid: cid,
      title: json['title']?.toString() ?? '获取标题失败',
      pic: json['cover']?.toString(),
      duration: _toInt(playerArgs['duration']),
      width: _queryInt(uri, 'player_width'),
      height: _queryInt(uri, 'player_height'),
      uri: uri,
      owner: Owner(
        mid: args is Map ? _toInt(args['up_id']) : null,
        name: args is Map ? args['up_name']?.toString() : '',
      ),
      isFollowed: isFollowed ? 1 : 0,
      stat: ShortVideoStat(
        view: _parseCompactCount(json['cover_left_text_1']),
        danmu: _parseCompactCount(json['cover_left_text_2']),
      ),
    );
  }

  static int? _queryInt(String uri, String key) {
    final Uri? parsed = Uri.tryParse(uri);
    final String? value = parsed?.queryParameters[key];
    return _toInt(value);
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static int? _parseCompactCount(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is! String || value.isEmpty) {
      return null;
    }
    final String normalized = value.trim();
    final double? number =
        double.tryParse(normalized.replaceAll(RegExp(r'[万亿]'), ''));
    if (number == null) {
      return null;
    }
    if (normalized.contains('亿')) {
      return (number * 100000000).round();
    }
    if (normalized.contains('万')) {
      return (number * 10000).round();
    }
    return number.round();
  }
}

class ShortVideoStat {
  ShortVideoStat({
    this.view,
    this.like,
    this.danmu,
  });

  int? view;
  int? like;
  int? danmu;
}
