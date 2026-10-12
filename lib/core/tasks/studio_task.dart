import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/storage/json_read.dart';
import 'package:rml_launcher/core/storage/json_store.dart';

enum TaskKind {
  install,
  update,
  checkFiles,
  duplicate,
  uninstall,
  launch;

  bool get pausable => this == install || this == update || this == checkFiles;

  bool get recorded => this != launch;
}

enum TaskState {
  queued,
  running,
  paused,
  failed,
  done,
  cancelled;

  bool get isActive => this == queued || this == running || this == paused;
}

enum TaskPhase { resolving, downloading, extracting, finalizing }

const Object _keep = Object();

final class TaskProgress {
  const TaskProgress({
    required this.fraction,
    this.bytesDone = 0,
    this.bytesTotal = 0,
    this.speed = 0,
    this.eta,
  });

  final double fraction;
  final int bytesDone;
  final int bytesTotal;
  final double speed;
  final Duration? eta;
}

final class StudioTask {
  const StudioTask({
    required this.id,
    required this.kind,
    required this.installId,
    required this.state,
    required this.startedAt,
    this.version,
    this.phase,
    this.progress = 0,
    this.bytesDone = 0,
    this.bytesTotal = 0,
    this.speed = 0,
    this.eta,
    this.failure,
    this.failureCode,
    this.finishedAt,
  });

  final String id;
  final TaskKind kind;
  final String installId;
  final TaskState state;
  final DateTime startedAt;
  final String? version;
  final TaskPhase? phase;
  final double progress;
  final int bytesDone;
  final int bytesTotal;
  final double speed;
  final Duration? eta;
  final AppFailure? failure;
  final String? failureCode;
  final DateTime? finishedAt;

  static StudioTask? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? id = json['id'];
    final Object? installId = json['installId'];
    final Object? version = json['version'];
    final Object? failureCode = json['failureCode'];
    final Object? bytesTotal = json['bytesTotal'];
    final TaskKind? kind = enumNamed(TaskKind.values, json['kind']);
    final TaskState? state = enumNamed(TaskState.values, json['state']);
    final DateTime? startedAt = dateFrom(json['startedAt']);
    if (id is! String ||
        installId is! String ||
        kind == null ||
        state == null ||
        startedAt == null) {
      return null;
    }
    return StudioTask(
      id: id,
      kind: kind,
      installId: installId,
      state: state,
      startedAt: startedAt,
      version: version is String ? version : null,
      progress: state == TaskState.done ? 1 : 0,
      bytesTotal: bytesTotal is int ? bytesTotal : 0,
      failureCode: failureCode is String ? failureCode : null,
      finishedAt: dateFrom(json['finishedAt']),
    );
  }

  StudioTask copyWith({
    TaskState? state,
    String? version,
    TaskPhase? phase,
    double? progress,
    int? bytesDone,
    int? bytesTotal,
    double? speed,
    Object? eta = _keep,
    AppFailure? failure,
    String? failureCode,
    DateTime? finishedAt,
  }) => StudioTask(
    id: id,
    kind: kind,
    installId: installId,
    state: state ?? this.state,
    startedAt: startedAt,
    version: version ?? this.version,
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    bytesDone: bytesDone ?? this.bytesDone,
    bytesTotal: bytesTotal ?? this.bytesTotal,
    speed: speed ?? this.speed,
    eta: identical(eta, _keep) ? this.eta : eta as Duration?,
    failure: failure ?? this.failure,
    failureCode: failureCode ?? this.failureCode,
    finishedAt: finishedAt ?? this.finishedAt,
  );

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'installId': installId,
    'version': version,
    'state': state.name,
    'bytesTotal': bytesTotal,
    'failureCode': failureCode,
    'startedAt': isoDate(startedAt),
    'finishedAt': finishedAt == null ? null : isoDate(finishedAt!),
  };
}
