/// The `/` separated path helpers shared by the firestore and storage paths,
/// both written with no leading slash, the empty string being the root.
library;

/// The non-empty segments of [path]: leading, trailing and repeated `/` are
/// ignored.
List<String> slashPathParts(String path) =>
    path.split('/').where((part) => part.isNotEmpty).toList();

/// The segments of [path] joined by a single `/`, with no leading or trailing
/// slash.
String slashPathNormalize(String path) => slashPathParts(path).join('/');

/// The last segment of [path], an empty string for the root.
String slashPathLast(String path) {
  var parts = slashPathParts(path);
  return parts.isEmpty ? '' : parts.last;
}

/// [path] without its last segment, `null` for the root.
String? slashPathParent(String path) {
  var parts = slashPathParts(path);
  if (parts.isEmpty) {
    return null;
  }
  return parts.sublist(0, parts.length - 1).join('/');
}

/// [path] with [child] appended, both normalized.
String slashPathJoin(String path, String child) =>
    [...slashPathParts(path), ...slashPathParts(child)].join('/');

/// Resolves [target] against [current] the way `cd` does: absolute when it
/// starts with `/`, `..` going one level up (a no-op at the root), `.` staying
/// put.
String slashPathResolve(String current, String target) {
  var parts = target.startsWith('/') ? <String>[] : slashPathParts(current);
  for (var part in slashPathParts(target)) {
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
