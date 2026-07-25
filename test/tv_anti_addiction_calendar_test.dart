import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/tv/models/tv_anti_addiction_calendar.dart';

void main() {
  group('TV anti-addiction calendar', () {
    test('treats regular weekdays and weekends by weekday', () {
      expect(
        TvAntiAddictionCalendar.dayTypeOf(DateTime(2026, 7, 24)),
        TvAntiAddictionDayType.workday,
      );
      expect(
        TvAntiAddictionCalendar.dayTypeOf(DateTime(2026, 7, 25)),
        TvAntiAddictionDayType.restDay,
      );
    });

    test('treats legal holiday dates as rest days', () {
      expect(
        TvAntiAddictionCalendar.dayTypeOf(DateTime(2026, 10, 1)),
        TvAntiAddictionDayType.restDay,
      );
      expect(
        TvAntiAddictionCalendar.dayTypeOf(DateTime(2026, 2, 16)),
        TvAntiAddictionDayType.restDay,
      );
    });

    test('treats make-up weekend workdays as workdays', () {
      expect(
        TvAntiAddictionCalendar.dayTypeOf(DateTime(2026, 2, 14)),
        TvAntiAddictionDayType.workday,
      );
      expect(
        TvAntiAddictionCalendar.dayTypeOf(DateTime(2026, 10, 10)),
        TvAntiAddictionDayType.workday,
      );
    });
  });
}
