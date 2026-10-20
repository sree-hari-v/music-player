/// Base exception for all Shadow Player domain errors.
abstract class AppException implements Exception {
  final String message;
  final dynamic cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() => message;
}

/// Thrown when folder permission is missing, denied, or revoked.
class FolderPermissionException extends AppException {
  const FolderPermissionException(super.message, [super.cause]);
}

/// Thrown when the specified SAF folder or URI cannot be found.
class FolderNotFoundException extends AppException {
  const FolderNotFoundException(super.message, [super.cause]);
}

/// Thrown when an error occurs during library directory scanning.
class LibraryScanException extends AppException {
  const LibraryScanException(super.message, [super.cause]);
}

/// Thrown when an error occurs extracting audio metadata.
class MetadataException extends AppException {
  const MetadataException(super.message, [super.cause]);
}
