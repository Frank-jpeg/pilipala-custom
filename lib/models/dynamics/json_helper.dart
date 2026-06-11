bool? dynamicBool(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    final num? parsed = num.tryParse(normalized);
    if (parsed != null) {
      return parsed != 0;
    }
  }
  return null;
}

int? dynamicInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final int? parsedInt = int.tryParse(normalized);
    if (parsedInt != null) {
      return parsedInt;
    }
    final num? parsedNum = num.tryParse(normalized);
    return parsedNum?.toInt();
  }
  return null;
}

double? dynamicDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }
  return null;
}
