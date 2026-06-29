String tvFormatDuration(int seconds) {
  if (seconds <= 0) {
    return '--:--';
  }
  final Duration duration = Duration(seconds: seconds);
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
  }
  return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
}

String tvCompactNumber(int? value) {
  final int safeValue = value ?? 0;
  if (safeValue >= 100000000) {
    return '${(safeValue / 100000000).toStringAsFixed(1)}亿';
  }
  if (safeValue >= 10000) {
    return '${(safeValue / 10000).toStringAsFixed(1)}万';
  }
  return safeValue.toString();
}
