final class RunningStudio {
  const RunningStudio({
    required this.pid,
    required this.executable,
    required this.startedAt,
    this.installId,
  });

  final int pid;
  final String executable;
  final DateTime startedAt;
  final String? installId;
}
