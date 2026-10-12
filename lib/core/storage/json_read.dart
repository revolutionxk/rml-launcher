T? enumNamed<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) {
    return null;
  }
  for (final T value in values) {
    if (value.name == raw) {
      return value;
    }
  }
  return null;
}

DateTime? dateFrom(Object? raw) =>
    raw is String ? DateTime.tryParse(raw) : null;

String isoDate(DateTime date) => date.toUtc().toIso8601String();
