import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/tv/models/tv_anti_addiction_unlock.dart';

void main() {
  test('unknown or missing unlock mode falls back to PIN', () {
    expect(
      parseTvAntiAddictionUnlockMode(null),
      TvAntiAddictionUnlockMode.pin,
    );
    expect(
      parseTvAntiAddictionUnlockMode('old-value'),
      TvAntiAddictionUnlockMode.pin,
    );
    expect(
      parseTvAntiAddictionUnlockMode('mathMedium'),
      TvAntiAddictionUnlockMode.mathMedium,
    );
  });

  for (final TvAntiAddictionUnlockMode mode
      in TvAntiAddictionUnlockMode.values.where(
    (TvAntiAddictionUnlockMode value) => value.usesMath,
  )) {
    test('${mode.name} creates three distinct choices containing the answer',
        () {
      final TvMathChallengeGenerator generator =
          TvMathChallengeGenerator(random: Random(100 + mode.index));
      for (int i = 0; i < 100; i++) {
        final TvMathChallenge challenge = generator.generate(mode);
        expect(challenge.prompt, isNotEmpty);
        expect(challenge.options, hasLength(3));
        expect(challenge.options.toSet(), hasLength(3));
        expect(challenge.options, contains(challenge.answer));
        if (mode == TvAntiAddictionUnlockMode.mathEasy) {
          expect(challenge.answer, inInclusiveRange(0, 100));
        }
      }
    });
  }

  test('PIN mode does not generate a math challenge', () {
    expect(
      () => TvMathChallengeGenerator(random: Random(1))
          .generate(TvAntiAddictionUnlockMode.pin),
      throwsArgumentError,
    );
  });
}
