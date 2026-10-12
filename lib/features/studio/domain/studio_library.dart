import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';

final class StudioLibrary {
  const StudioLibrary({
    this.installs = const <StudioInstall>[],
    this.defaultInstallId,
    this.hiddenFoundIds = const <String>{},
  });

  factory StudioLibrary.fromJson(JsonMap json) {
    final List<StudioInstall> installs = <StudioInstall>[];
    final Set<String> ids = <String>{};
    final Object? raw = json['installs'];
    if (raw is List<Object?>) {
      for (final Object? item in raw) {
        final StudioInstall? install = StudioInstall.fromJson(item);
        if (install != null && ids.add(install.id)) {
          installs.add(install);
        }
      }
    }
    final Object? defaultId = json['defaultInstallId'];
    final Object? hidden = json['hiddenFoundIds'];
    return StudioLibrary(
      installs: List<StudioInstall>.unmodifiable(installs),
      defaultInstallId: defaultId is String ? defaultId : null,
      hiddenFoundIds: hidden is List<Object?>
          ? Set<String>.unmodifiable(hidden.whereType<String>())
          : const <String>{},
    );
  }

  static const StudioLibrary empty = StudioLibrary();
  static const int schema = 1;

  final List<StudioInstall> installs;
  final String? defaultInstallId;
  final Set<String> hiddenFoundIds;

  Iterable<StudioInstall> get visible => installs.where(
    (StudioInstall install) => !hiddenFoundIds.contains(install.id),
  );

  Iterable<String> get ids =>
      installs.map((StudioInstall install) => install.id);

  StudioInstall? byId(String id) {
    for (final StudioInstall install in installs) {
      if (install.id == id) {
        return install;
      }
    }
    return null;
  }

  StudioInstall? get defaultInstall {
    final List<StudioInstall> candidates = visible.toList();
    for (final StudioInstall install in candidates) {
      if (install.id == defaultInstallId) {
        return install;
      }
    }
    StudioInstall? latest;
    for (final StudioInstall install in candidates) {
      final DateTime? launched = install.lastLaunchedAt;
      final DateTime? best = latest?.lastLaunchedAt;
      if (launched != null && (best == null || launched.isAfter(best))) {
        latest = install;
      }
    }
    return latest ??
        candidates
            .where((StudioInstall install) => install.isManaged)
            .firstOrNull ??
        candidates.firstOrNull;
  }

  StudioLibrary upsert(StudioInstall install) {
    final List<StudioInstall> next = List<StudioInstall>.of(installs);
    final int index = next.indexWhere(
      (StudioInstall existing) => existing.id == install.id,
    );
    if (index < 0) {
      next.add(install);
    } else {
      next[index] = install;
    }
    return _copy(installs: next);
  }

  StudioLibrary remove(String id) => StudioLibrary(
    installs: List<StudioInstall>.unmodifiable(
      installs.where((StudioInstall install) => install.id != id),
    ),
    defaultInstallId: defaultInstallId == id ? null : defaultInstallId,
    hiddenFoundIds: Set<String>.unmodifiable(
      hiddenFoundIds.where((String hidden) => hidden != id),
    ),
  );

  StudioLibrary withDefault(String? id) => StudioLibrary(
    installs: installs,
    defaultInstallId: id,
    hiddenFoundIds: hiddenFoundIds,
  );

  StudioLibrary hide(String id) =>
      _copy(hidden: <String>{...hiddenFoundIds, id});

  StudioLibrary show(String id) => _copy(
    hidden: hiddenFoundIds.where((String hidden) => hidden != id).toSet(),
  );

  StudioLibrary _copy({List<StudioInstall>? installs, Set<String>? hidden}) =>
      StudioLibrary(
        installs: List<StudioInstall>.unmodifiable(installs ?? this.installs),
        defaultInstallId: defaultInstallId,
        hiddenFoundIds: Set<String>.unmodifiable(hidden ?? hiddenFoundIds),
      );

  JsonMap toJson() => <String, Object?>{
    'schema': schema,
    'defaultInstallId': defaultInstallId,
    'hiddenFoundIds': hiddenFoundIds.toList(),
    'installs': installs
        .map((StudioInstall install) => install.toJson())
        .toList(),
  };
}
