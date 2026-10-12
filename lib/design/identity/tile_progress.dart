sealed class TileProgress {
  const TileProgress();
}

final class PhaseProgress extends TileProgress {
  const PhaseProgress(this.completed)
    : assert(completed >= 0 && completed <= 4, 'completed must be 0 to 4');

  final int completed;

  @override
  bool operator ==(Object other) =>
      other is PhaseProgress && other.completed == completed;

  @override
  int get hashCode => completed.hashCode;
}

final class FractionProgress extends TileProgress {
  const FractionProgress(this.value)
    : assert(value >= 0 && value <= 1, 'value must be 0 to 1');

  final double value;

  @override
  bool operator ==(Object other) =>
      other is FractionProgress && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
