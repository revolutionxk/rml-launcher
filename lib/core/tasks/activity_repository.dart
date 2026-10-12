import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';

final class ActivityRepository {
  const ActivityRepository(this._store);

  static const String documentName = 'activity';
  static const int limit = 20;

  final JsonStore _store;

  Future<List<StudioTask>> load() async {
    final JsonMap? json = (await _store.read(documentName)).valueOrNull;
    final Object? tasks = json?['tasks'];
    if (tasks is! List<Object?>) {
      return const <StudioTask>[];
    }
    return tasks
        .map(StudioTask.fromJson)
        .whereType<StudioTask>()
        .take(limit)
        .toList();
  }

  Future<Result<void>> save(List<StudioTask> finished) =>
      _store.write(documentName, <String, Object?>{
        'schema': 1,
        'tasks': finished
            .take(limit)
            .map((StudioTask task) => task.toJson())
            .toList(),
      });
}
