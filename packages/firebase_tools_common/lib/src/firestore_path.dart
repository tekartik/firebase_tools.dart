/// What a firestore path points to.
///
/// Firestore paths alternate collection and document segments, so the kind is
/// decided by the number of segments alone: `''` is the root, `a` a collection,
/// `a/b` a document, `a/b/c` a collection again, …
enum FirestorePathKind {
  /// The database root, i.e. the empty path. Holds root collections.
  root,

  /// A collection, i.e. an odd number of segments. Holds documents.
  collection,

  /// A document, i.e. an even, non-zero number of segments. Holds sub
  /// collections.
  document,
}

/// The non-empty segments of the firestore path [path].
///
/// [path] may use any number of leading, trailing or repeated `/`, they are all
/// ignored: `'/a//b/'` and `'a/b'` both give `['a', 'b']`.
///
/// Returns an empty list for the root path.
List<String> firestorePathParts(String path) =>
    path.split('/').where((part) => part.isNotEmpty).toList();

/// The canonical form of the firestore path [path], i.e. its segments joined
/// by a single `/`, with no leading or trailing slash.
///
/// The root path is the empty string.
String firestorePathNormalize(String path) =>
    firestorePathParts(path).join('/');

/// What [path] points to, see [FirestorePathKind].
///
/// [path] does not need to be normalized.
FirestorePathKind firestorePathKind(String path) {
  var length = firestorePathParts(path).length;
  if (length == 0) {
    return FirestorePathKind.root;
  }
  return length.isOdd
      ? FirestorePathKind.collection
      : FirestorePathKind.document;
}

/// Whether [path] points to a collection.
bool firestorePathIsCollection(String path) =>
    firestorePathKind(path) == FirestorePathKind.collection;

/// Whether [path] points to a document.
bool firestorePathIsDocument(String path) =>
    firestorePathKind(path) == FirestorePathKind.document;

/// Whether [path] is the database root, i.e. has no segment.
bool firestorePathIsRoot(String path) =>
    firestorePathKind(path) == FirestorePathKind.root;

/// The last segment of [path], i.e. the document or collection id.
///
/// Returns an empty string for the root path.
String firestorePathId(String path) {
  var parts = firestorePathParts(path);
  return parts.isEmpty ? '' : parts.last;
}

/// The path of the parent of [path], one segment up.
///
/// Returns `null` for the root path, which has no parent, and the empty string
/// (the root) for a root collection.
String? firestorePathParent(String path) {
  var parts = firestorePathParts(path);
  if (parts.isEmpty) {
    return null;
  }
  return parts.sublist(0, parts.length - 1).join('/');
}

/// [path] with [segment] appended.
///
/// [segment] may itself hold several `/` separated parts. Both sides are
/// normalized, so `firestorePathJoin('/a/', '/b/c/')` is `'a/b/c'`.
String firestorePathJoin(String path, String segment) =>
    [...firestorePathParts(path), ...firestorePathParts(segment)].join('/');

/// Resolves [target] against the current path [current], the way `cd` does.
///
/// [target] is absolute when it starts with `/` (or is empty), relative
/// otherwise. A `..` segment goes one level up (and is a no-op at the root),
/// a `.` segment stays put.
///
/// Returns the normalized resulting path.
String firestorePathResolve(String current, String target) {
  var parts = target.startsWith('/') ? <String>[] : firestorePathParts(current);
  for (var part in firestorePathParts(target)) {
    if (part == '.') {
      continue;
    }
    if (part == '..') {
      if (parts.isNotEmpty) {
        parts.removeLast();
      }
      continue;
    }
    parts.add(part);
  }
  return parts.join('/');
}
