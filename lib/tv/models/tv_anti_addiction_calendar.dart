enum TvAntiAddictionDayType {
  workday,
  restDay,
}

extension TvAntiAddictionDayTypeLabel on TvAntiAddictionDayType {
  String get label {
    switch (this) {
      case TvAntiAddictionDayType.restDay:
        return '休息日';
      case TvAntiAddictionDayType.workday:
      default:
        return '工作日';
    }
  }
}

class TvAntiAddictionCustomRestRange {
  const TvAntiAddictionCustomRestRange({
    required this.startKey,
    required this.endKey,
  });

  final String startKey;
  final String endKey;

  bool contains(DateTime date) {
    final String key = TvAntiAddictionCalendar.dateKey(date);
    return key.compareTo(startKey) >= 0 && key.compareTo(endKey) <= 0;
  }

  Map<String, String> toJson() => <String, String>{
        'start': startKey,
        'end': endKey,
      };

  static TvAntiAddictionCustomRestRange? fromJson(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final String? start = value['start']?.toString();
    final String? end = value['end']?.toString();
    if (start == null || end == null) {
      return null;
    }
    if (!TvAntiAddictionCalendar.isDateKey(start) ||
        !TvAntiAddictionCalendar.isDateKey(end)) {
      return null;
    }
    return TvAntiAddictionCustomRestRange(
      startKey: start.compareTo(end) <= 0 ? start : end,
      endKey: start.compareTo(end) <= 0 ? end : start,
    );
  }
}

class TvAntiAddictionCalendar {
  const TvAntiAddictionCalendar._();

  static TvAntiAddictionDayType dayTypeOf(
    DateTime date, {
    List<TvAntiAddictionCustomRestRange> customRestRanges = const [],
  }) {
    for (final TvAntiAddictionCustomRestRange range in customRestRanges) {
      if (range.contains(date)) {
        return TvAntiAddictionDayType.restDay;
      }
    }
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return TvAntiAddictionDayType.restDay;
    }
    return TvAntiAddictionDayType.workday;
  }

  static String dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static bool isDateKey(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final List<int?> parts =
        value.split('-').map((String item) => int.tryParse(item)).toList();
    if (parts.any((int? part) => part == null)) {
      return false;
    }
    final int year = parts[0]!;
    final int month = parts[1]!;
    final int day = parts[2]!;
    final DateTime date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  static String dateKeyFromNumber(int value) {
    final String raw = value.toString().padLeft(8, '0');
    final String key = '${raw.substring(0, 4)}-'
        '${raw.substring(4, 6)}-'
        '${raw.substring(6, 8)}';
    if (!isDateKey(key)) {
      return '';
    }
    return key;
  }
}
