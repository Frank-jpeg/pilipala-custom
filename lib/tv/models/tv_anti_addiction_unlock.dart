import 'dart:math';

enum TvAntiAddictionUnlockMode {
  pin,
  mathEasy,
  mathMedium,
  mathHard,
}

extension TvAntiAddictionUnlockModeLabel on TvAntiAddictionUnlockMode {
  String get label {
    switch (this) {
      case TvAntiAddictionUnlockMode.pin:
        return '家长 PIN';
      case TvAntiAddictionUnlockMode.mathEasy:
        return '简单算术';
      case TvAntiAddictionUnlockMode.mathMedium:
        return '中等算术';
      case TvAntiAddictionUnlockMode.mathHard:
        return '困难算术';
    }
  }

  bool get usesMath => this != TvAntiAddictionUnlockMode.pin;
}

TvAntiAddictionUnlockMode parseTvAntiAddictionUnlockMode(dynamic value) {
  final String name = value?.toString() ?? '';
  return TvAntiAddictionUnlockMode.values.firstWhere(
    (TvAntiAddictionUnlockMode mode) => mode.name == name,
    orElse: () => TvAntiAddictionUnlockMode.pin,
  );
}

class TvMathChallenge {
  const TvMathChallenge({
    required this.prompt,
    required this.answer,
    required this.options,
  });

  final String prompt;
  final int answer;
  final List<int> options;
}

class TvMathChallengeGenerator {
  TvMathChallengeGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  TvMathChallenge generate(TvAntiAddictionUnlockMode mode) {
    late final String prompt;
    late final int answer;
    switch (mode) {
      case TvAntiAddictionUnlockMode.mathEasy:
        final bool addition = _random.nextBool();
        if (addition) {
          final int left = 10 + _random.nextInt(60);
          final int right = 2 + _random.nextInt(99 - left);
          prompt = '$left + $right = ?';
          answer = left + right;
        } else {
          final int left = 20 + _random.nextInt(80);
          final int right = 1 + _random.nextInt(left);
          prompt = '$left - $right = ?';
          answer = left - right;
        }
        break;
      case TvAntiAddictionUnlockMode.mathMedium:
        final int template = _random.nextInt(3);
        if (template == 0) {
          final int left = 3 + _random.nextInt(10);
          final int right = 2 + _random.nextInt(11);
          prompt = '$left × $right = ?';
          answer = left * right;
        } else if (template == 1) {
          final int divisor = 2 + _random.nextInt(11);
          final int quotient = 2 + _random.nextInt(11);
          prompt = '${divisor * quotient} ÷ $divisor = ?';
          answer = quotient;
        } else {
          final int left = 2 + _random.nextInt(8);
          final int right = 2 + _random.nextInt(8);
          final int extra = 2 + _random.nextInt(19);
          prompt = '$left × $right + $extra = ?';
          answer = left * right + extra;
        }
        break;
      case TvAntiAddictionUnlockMode.mathHard:
        final int template = _random.nextInt(3);
        if (template == 0) {
          final int base = 4 + _random.nextInt(12);
          final int minus = 2 + _random.nextInt(19);
          prompt = '$base² - $minus = ?';
          answer = base * base - minus;
        } else if (template == 1) {
          final int left = 3 + _random.nextInt(18);
          final int right = 3 + _random.nextInt(18);
          final int multiplier = 2 + _random.nextInt(8);
          prompt = '($left + $right) × $multiplier = ?';
          answer = (left + right) * multiplier;
        } else {
          final int coefficient = 2 + _random.nextInt(8);
          final int x = 2 + _random.nextInt(14);
          final int extra = 1 + _random.nextInt(20);
          prompt = '${coefficient}x + $extra = '
              '${coefficient * x + extra}，x = ?';
          answer = x;
        }
        break;
      case TvAntiAddictionUnlockMode.pin:
        throw ArgumentError('PIN mode does not generate math challenges');
    }
    return TvMathChallenge(
      prompt: prompt,
      answer: answer,
      options: _buildOptions(answer, mode),
    );
  }

  List<int> _buildOptions(int answer, TvAntiAddictionUnlockMode mode) {
    final int spread = switch (mode) {
      TvAntiAddictionUnlockMode.mathEasy => 8,
      TvAntiAddictionUnlockMode.mathMedium => 12,
      TvAntiAddictionUnlockMode.mathHard => 20,
      TvAntiAddictionUnlockMode.pin => 8,
    };
    final Set<int> values = <int>{answer};
    while (values.length < 3) {
      final int distance = 1 + _random.nextInt(spread);
      final int candidate =
          answer + (_random.nextBool() ? distance : -distance);
      if (candidate >= 0) {
        values.add(candidate);
      }
    }
    final List<int> options = values.toList(growable: false)..shuffle(_random);
    return options;
  }
}
