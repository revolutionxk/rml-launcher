import 'package:rml_launcher/core/storage/json_read.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/design/identity/identity_color.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';

enum InstallKind { managed, found }

enum InstallSource {
  rml('rml'),
  roblox('roblox'),
  bloxstrap('bloxstrap'),
  macBundle('mac'),
  vinegar('vinegar');

  const InstallSource(this.slug);

  final String slug;
}

enum UpdatePolicy { followLive, pinned }

const Object _keep = Object();

final class InstallLook {
  const InstallLook({required this.color, this.monogram, this.glyph});

  final IdentityColor color;
  final String? monogram;
  final String? glyph;

  static InstallLook fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return const InstallLook(color: IdentityColor.graphite);
    }
    final Object? monogram = json['monogram'];
    final Object? glyph = json['glyph'];
    return InstallLook(
      color:
          enumNamed(IdentityColor.values, json['color']) ??
          IdentityColor.graphite,
      monogram: monogram is String ? monogram : null,
      glyph: glyph is String ? glyph : null,
    );
  }

  JsonMap toJson() => <String, Object?>{
    'color': color.name,
    'monogram': monogram,
    'glyph': glyph,
  };

  @override
  bool operator ==(Object other) =>
      other is InstallLook &&
      other.color == color &&
      other.monogram == monogram &&
      other.glyph == glyph;

  @override
  int get hashCode => Object.hash(color, monogram, glyph);
}

final class StudioInstall {
  const StudioInstall({
    required this.id,
    required this.name,
    required this.kind,
    required this.source,
    required this.look,
    this.policy = UpdatePolicy.followLive,
    this.current,
    this.previous,
    this.ready,
    this.pinnedInSidebar = false,
    this.lastLaunchedAt,
  });

  final String id;
  final String name;
  final InstallKind kind;
  final InstallSource source;
  final InstallLook look;
  final UpdatePolicy policy;
  final StudioBuild? current;
  final StudioBuild? previous;
  final StudioBuild? ready;
  final bool pinnedInSidebar;
  final DateTime? lastLaunchedAt;

  bool get isManaged => kind == InstallKind.managed;

  Iterable<StudioBuild> get builds =>
      <StudioBuild?>[current, previous, ready].whereType<StudioBuild>();

  static StudioInstall? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? id = json['id'];
    final Object? name = json['name'];
    final InstallKind? kind = enumNamed(InstallKind.values, json['kind']);
    final InstallSource? source = enumNamed(
      InstallSource.values,
      json['source'],
    );
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        kind == null ||
        source == null) {
      return null;
    }
    return StudioInstall(
      id: id,
      name: name,
      kind: kind,
      source: source,
      look: InstallLook.fromJson(json['look']),
      policy:
          enumNamed(UpdatePolicy.values, json['policy']) ??
          UpdatePolicy.followLive,
      current: StudioBuild.fromJson(json['current']),
      previous: StudioBuild.fromJson(json['previous']),
      ready: StudioBuild.fromJson(json['ready']),
      pinnedInSidebar: json['pinnedInSidebar'] == true,
      lastLaunchedAt: dateFrom(json['lastLaunchedAt']),
    );
  }

  StudioInstall copyWith({
    String? name,
    InstallLook? look,
    UpdatePolicy? policy,
    Object? current = _keep,
    Object? previous = _keep,
    Object? ready = _keep,
    bool? pinnedInSidebar,
    Object? lastLaunchedAt = _keep,
  }) => StudioInstall(
    id: id,
    name: name ?? this.name,
    kind: kind,
    source: source,
    look: look ?? this.look,
    policy: policy ?? this.policy,
    current: identical(current, _keep) ? this.current : current as StudioBuild?,
    previous: identical(previous, _keep)
        ? this.previous
        : previous as StudioBuild?,
    ready: identical(ready, _keep) ? this.ready : ready as StudioBuild?,
    pinnedInSidebar: pinnedInSidebar ?? this.pinnedInSidebar,
    lastLaunchedAt: identical(lastLaunchedAt, _keep)
        ? this.lastLaunchedAt
        : lastLaunchedAt as DateTime?,
  );

  JsonMap toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'kind': kind.name,
    'source': source.name,
    'look': look.toJson(),
    'policy': policy.name,
    'current': current?.toJson(),
    'previous': previous?.toJson(),
    'ready': ready?.toJson(),
    'pinnedInSidebar': pinnedInSidebar,
    'lastLaunchedAt': lastLaunchedAt == null ? null : isoDate(lastLaunchedAt!),
  };
}
