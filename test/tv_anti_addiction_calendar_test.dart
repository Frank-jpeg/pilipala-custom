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

    test('does not auto-detect legal holidays without a custom range', () {
      expect(
        TvAntiAddictionCalendar.dayTypeOf(DateTime(2026, 10, 1)),
        TvAntiAddictionDayType.workday,
      );
      expect(
        TvAntiAddictionCalendar.dayTypeOf(DateTime(2026, 2, 16)),
        TvAntiAddictionDayType.workday,
      );
    });

    test('custom rest ranges override weekdays', () {
      const List<TvAntiAddictionCustomRestRange> ranges =
          <TvAntiAddictionCustomRestRange>[
        TvAntiAddictionCustomRestRange(
          startKey: '2026-07-01',
          endKey: '2026-08-31',
        ),
      ];
      expect(
        TvAntiAddictionCalendar.dayTypeOf(
          DateTime(2026, 7, 1),
          customRestRanges: ranges,
        ),
        TvAntiAddictionDayType.restDay,
      );
      expect(
        TvAntiAddictionCalendar.dayTypeOf(
          DateTime(2026, 9, 1),
          customRestRanges: ranges,
        ),
        TvAntiAddictionDayType.workday,
      );
    });

    test('parses and validates numeric date input', () {
      expect(
        TvAntiAddictionCalendar.dateKeyFromNumber(20260701),
        '2026-07-01',
      );
      expect(TvAntiAddictionCalendar.dateKeyFromNumber(20260230), '');
    });
  });
}
