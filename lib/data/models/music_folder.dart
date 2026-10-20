/// Represents the user's selected SAF music folder.
class MusicFolder {
  /// SAF Document tree URI (`content://...`).
  final String uri;

  /// Display name of the folder chosen by the user.
  final String name;

  /// Whether the app holds a valid persisted read permission for this folder.
  final bool hasValidPermission;

  /// Number of tracks discovered in this folder.
  final int trackCount;

  /// Timestamp when this folder was last scanned.
  final DateTime? lastScanned;

  const MusicFolder({
    required this.uri,
    required this.name,
    this.hasValidPermission = true,
    this.trackCount = 0,
    this.lastScanned,
  });

  MusicFolder copyWith({
    String? uri,
    String? name,
    bool? hasValidPermission,
    int? trackCount,
    DateTime? lastScanned,
  }) {
    return MusicFolder(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      hasValidPermission: hasValidPermission ?? this.hasValidPermission,
      trackCount: trackCount ?? this.trackCount,
      lastScanned: lastScanned ?? this.lastScanned,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicFolder &&
          runtimeType == other.runtimeType &&
          uri == other.uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() {
    return 'MusicFolder(uri: $uri, name: $name, hasValidPermission: $hasValidPermission, tracks: $trackCount)';
  }
}
