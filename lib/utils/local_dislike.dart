import 'package:pilipala/utils/storage.dart';

class LocalDislike {
  static List<int> _blockedMids() {
    return List<int>.from(
      GStrorage.setting.get(SettingBoxKey.blackMidsList, defaultValue: [-1]),
    );
  }

  static List<String> _keywords(String key) {
    return List<String>.from(
      GStrorage.setting.get(key, defaultValue: <String>[]),
    );
  }

  static String titleOf(dynamic videoItem) {
    try {
      return videoItem.title?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String ownerNameOf(dynamic videoItem) {
    try {
      return videoItem.owner?.name?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  static int? ownerMidOf(dynamic videoItem) {
    try {
      return videoItem.owner?.mid as int?;
    } catch (_) {
      return null;
    }
  }

  static bool hasBlockedKeyword(String title) {
    final String lowerTitle = title.toLowerCase();
    final List<String> keywords = [
      ..._keywords(SettingBoxKey.blockedTitleKeywords),
      ..._keywords(SettingBoxKey.reducedSimilarKeywords),
    ];
    return keywords.any((keyword) {
      final String value = keyword.trim().toLowerCase();
      return value.isNotEmpty && lowerTitle.contains(value);
    });
  }

  static String blockUp(dynamic videoItem) {
    final int? mid = ownerMidOf(videoItem);
    if (mid == null || mid <= 0) {
      return '未找到UP信息';
    }
    final List<int> list = _blockedMids();
    if (!list.contains(mid)) {
      list.add(mid);
      GStrorage.setting.put(SettingBoxKey.blackMidsList, list);
    }
    final String name = ownerNameOf(videoItem);
    return name.isEmpty ? '已不看这个UP' : '已不看 $name';
  }

  static String blockKeyword(String keyword) {
    final String value = keyword.trim();
    if (value.isEmpty) {
      return '关键词为空';
    }
    final List<String> list = _keywords(SettingBoxKey.blockedTitleKeywords);
    if (!list.contains(value)) {
      list.add(value);
      GStrorage.setting.put(SettingBoxKey.blockedTitleKeywords, list);
    }
    return '已屏蔽关键词：$value';
  }

  static String reduceSimilar(dynamic videoItem) {
    final List<String> suggestions = suggestKeywords(videoItem);
    if (suggestions.isEmpty) {
      return '没有找到合适关键词';
    }
    final String value = suggestions.first;
    final List<String> list = _keywords(SettingBoxKey.reducedSimilarKeywords);
    if (!list.contains(value)) {
      list.add(value);
      GStrorage.setting.put(SettingBoxKey.reducedSimilarKeywords, list);
    }
    return '已减少类似内容：$value';
  }

  static List<String> suggestKeywords(dynamic videoItem) {
    final String title = titleOf(videoItem);
    if (title.isEmpty) {
      return <String>[];
    }
    final List<String> candidates = title
        .split(RegExp(r'[\s,，。.!！?？:：;；、|｜【】\[\]()（）《》<>「」『』"“”‘’]+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 2 && e.length <= 12)
        .where((e) => !RegExp(r'^\d+$').hasMatch(e))
        .where((e) => !_commonWords.contains(e))
        .toSet()
        .toList();
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) => b.length.compareTo(a.length));
      return candidates.take(3).toList();
    }

    final String compact = title.replaceAll(RegExp(r'\s+'), '');
    if (compact.length >= 4) {
      return <String>[compact.substring(0, 4)];
    }
    return <String>[];
  }

  static const Set<String> _commonWords = {
    '一个',
    '这个',
    '那个',
    '什么',
    '怎么',
    '为什么',
    '真的',
    '不是',
    '没有',
    '可以',
    '不会',
    '视频',
    '官方',
  };
}
