/// Storage paths are plain `/` separated strings, with no leading slash: a
/// bucket has no real directories, only file names that happen to contain `/`.
///
/// Every helper here takes and returns such a normalized path, the empty string
/// being the bucket root.
library;

/// The non-empty segments of the storage path [path].
///
/// Leading, trailing and repeated `/` are ignored, so `'/a//b/'` and `'a/b'`
/// both give `['a', 'b']`.
List<String> storagePathParts(String path) =>
    path.split('/').where((part) => part.isNotEmpty).toList();

/// The canonical form of [path]: its segments joined by a single `/`, with no
/// leading or trailing slash.
///
/// The bucket root is the empty string.
String storagePathNormalize(String path) => storagePathParts(path).join('/');

/// [path] with [child] appended, both normalized.
///
/// [child] may hold several `/` separated segments. Joining onto the root
/// (`''`) simply returns the normalized [child].
String storagePathJoin(String path, String child) =>
    [...storagePathParts(path), ...storagePathParts(child)].join('/');

/// The last segment of [path], i.e. the file or directory name.
///
/// Returns an empty string for the root.
String storagePathName(String path) {
  var parts = storagePathParts(path);
  return parts.isEmpty ? '' : parts.last;
}

/// The directory holding [path], i.e. [path] without its last segment.
///
/// Returns `null` for the root, which has no parent, and the empty string (the
/// root) for a top level entry.
String? storagePathParent(String path) {
  var parts = storagePathParts(path);
  if (parts.isEmpty) {
    return null;
  }
  return parts.sublist(0, parts.length - 1).join('/');
}

/// The prefix to pass to a listing call to restrict it to the directory [path],
/// i.e. [path] with a trailing `/`.
///
/// Returns an empty string for the root, which matches everything.
String storagePathPrefix(String path) {
  var normalized = storagePathNormalize(path);
  return normalized.isEmpty ? '' : '$normalized/';
}

/// Whether [path] is inside the directory [directory], at any depth.
///
/// A path is not inside itself. Everything is inside the root (`''`).
bool storagePathIsWithin(String path, String directory) {
  var normalized = storagePathNormalize(path);
  var prefix = storagePathPrefix(directory);
  if (normalized.isEmpty) {
    return false;
  }
  return normalized.startsWith(prefix) && normalized != prefix;
}

/// [path] expressed relatively to the directory [from].
///
/// `storagePathRelative('a/b/c.txt', from: 'a')` is `'b/c.txt'`. When [path] is
/// not inside [from], the normalized [path] is returned unchanged — a caller
/// showing relative paths still gets something usable rather than a throw.
String storagePathRelative(String path, {required String from}) {
  var normalized = storagePathNormalize(path);
  if (!storagePathIsWithin(normalized, from)) {
    return normalized;
  }
  return normalized.substring(storagePathPrefix(from).length);
}

/// Resolves [target] against the current directory [current], the way `cd`
/// does.
///
/// [target] is absolute when it starts with `/` (or is empty), relative
/// otherwise. A `..` segment goes one level up (and is a no-op at the root), a
/// `.` segment stays put.
///
/// Returns the normalized resulting path.
String storagePathResolve(String current, String target) {
  var parts = target.startsWith('/') ? <String>[] : storagePathParts(current);
  for (var part in storagePathParts(target)) {
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

/// Whether [name] passes the name filter [filter].
///
/// A `null` or empty [filter] matches everything. A [filter] holding `*` or `?`
/// is treated as a glob anchored on the whole name (`*` for any run of
/// characters, `?` for exactly one); any other filter matches when [name]
/// contains it. Matching is case insensitive either way.
bool storageNameMatchesFilter(String name, String? filter) {
  if (filter == null || filter.isEmpty) {
    return true;
  }
  var lowerName = name.toLowerCase();
  var lowerFilter = filter.toLowerCase();
  if (!lowerFilter.contains('*') && !lowerFilter.contains('?')) {
    return lowerName.contains(lowerFilter);
  }
  return _globRegExp(lowerFilter).hasMatch(lowerName);
}

/// The anchored regular expression matching the glob [filter], every character
/// but `*` and `?` being escaped.
RegExp _globRegExp(String filter) {
  var buffer = StringBuffer('^');
  for (var char in filter.split('')) {
    switch (char) {
      case '*':
        buffer.write('.*');
      case '?':
        buffer.write('.');
      default:
        buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}

/// What a directory of a bucket holds, as computed from a flat file listing.
///
/// A bucket has no real directories, so these are the distinct first segments
/// of what lies below the listed path: [directoryNames] for the ones holding
/// something deeper, [fileNames] for the files sitting directly in it.
class StorageDirectoryNames {
  /// The names of the sub directories, sorted, without trailing `/`.
  final List<String> directoryNames;

  /// The names of the files directly in the directory, sorted.
  final List<String> fileNames;

  /// Creates a listing result holding [directoryNames] and [fileNames].
  StorageDirectoryNames({
    required this.directoryNames,
    required this.fileNames,
  });

  @override
  String toString() => 'dirs: $directoryNames, files: $fileNames';
}

/// Groups the full file paths [paths] into what the directory [path] directly
/// holds.
///
/// [paths] is a flat file listing, typically everything under [path]; entries
/// outside [path] are ignored, so passing a whole bucket listing works. [path]
/// defaults to the bucket root.
///
/// A path going deeper than one segment contributes its first segment as a
/// directory name; a path with exactly one remaining segment contributes a file
/// name. Some backends also store an explicit empty marker object for a
/// directory (a path ending with `/`): it is reported as a directory, never as
/// a file.
///
/// Returns the distinct, sorted names, see [StorageDirectoryNames].
StorageDirectoryNames storageDirectoryNamesFromPaths(
  Iterable<String> paths, {
  String path = '',
}) {
  var prefix = storagePathPrefix(path);
  var directoryNames = <String>{};
  var fileNames = <String>{};
  for (var filePath in paths) {
    var isDirectoryMarker = filePath.endsWith('/');
    var normalized = storagePathNormalize(filePath);
    if (normalized.isEmpty || !normalized.startsWith(prefix)) {
      continue;
    }
    var relative = normalized.substring(prefix.length);
    var parts = storagePathParts(relative);
    if (parts.isEmpty) {
      continue;
    }
    if (parts.length > 1 || isDirectoryMarker) {
      directoryNames.add(parts.first);
    } else {
      fileNames.add(parts.first);
    }
  }
  // A name can be both, a file and a directory holding more: keep it as a
  // directory too so browsing into it stays possible.
  return StorageDirectoryNames(
    directoryNames: directoryNames.toList()..sort(),
    fileNames: fileNames.toList()..sort(),
  );
}
