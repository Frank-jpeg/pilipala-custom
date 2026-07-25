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

class TvAntiAddictionCalendar {
  const TvAntiAddictionCalendar._();

  static TvAntiAddictionDayType dayTypeOf(DateTime date) {
    final String key = dateKey(date);
    if (_workdayOverrides2026.contains(key)) {
      return TvAntiAddictionDayType.workday;
    }
    if (_restDayOverrides2026.contains(key)) {
      return TvAntiAddictionDayType.restDay;
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

  // 2026 中国法定节假日和调休上班日。
  static const Set<String> _restDayOverrides2026 = <String>{
    '2026-01-01',
    '2026-01-02',
    '2026-01-03',
    '2026-02-15',
    '2026-02-16',
    '2026-02-17',
    '2026-02-18',
    '2026-02-19',
    '2026-02-20',
    '2026-02-21',
    '2026-02-22',
    '2026-02-23',
    '2026-04-04',
    '2026-04-05',
    '2026-04-06',
    '2026-05-01',
    '2026-05-02',
    '2026-05-03',
    '2026-05-04',
    '2026-05-05',
    '2026-06-19',
    '2026-06-20',
    '2026-06-21',
    '2026-09-25',
    '2026-09-26',
    '2026-09-27',
    '2026-10-01',
    '2026-10-02',
    '2026-10-03',
    '2026-10-04',
    '2026-10-05',
    '2026-10-06',
    '2026-10-07',
  };

  static const Set<String> _workdayOverrides2026 = <String>{
    '2026-01-04',
    '2026-02-14',
    '2026-02-28',
    '2026-05-09',
    '2026-09-20',
    '2026-10-10',
  };
}
