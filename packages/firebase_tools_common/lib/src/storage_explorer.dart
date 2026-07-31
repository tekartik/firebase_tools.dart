import 'dart:typed_data';

import 'package:tekartik_firebase_storage/storage.dart';

import 'storage_path.dart';

/// One entry of a bucket listing: a file, or a directory inferred from the file
/// names below it.
class StorageExplorerEntry {
  /// The full path of the entry in the bucket, e.g. `image/thumb/a.png`.
  ///
  /// This is what [Bucket.file] takes, for a file.
  final String path;

  /// Whether this is a directory, i.e. a prefix holding deeper entries rather
  /// than a file.
  ///
  /// A bucket has no real directories: this is inferred from the `/` of the
  /// file names below, so an empty directory simply does not exist.
  final bool isDirectory;

  /// The size of the file in bytes, or `null` for a directory or when the
  /// metadata was not fetched.
  final int? size;

  /// The date the file was last updated, or `null` for a directory or when the
  /// metadata was not fetched.
  final DateTime? dateUpdated;

  /// The MIME content type of the file, or `null` for a directory or when it is
  /// unknown.
  final String? contentType;

  /// Creates an entry, see each field.
  StorageExplorerEntry({
    required this.path,
    required this.isDirectory,
    this.size,
    this.dateUpdated,
    this.contentType,
  });

  /// The name of the entry, i.e. the last segment of [path].
  String get name => storagePathName(path);

  /// [path] expressed relatively to the directory [from].
  ///
  /// See [storagePathRelative]: when the entry is not inside [from], its full
  /// path comes back unchanged.
  String relativeTo(String from) => storagePathRelative(path, from: from);

  @override
  String toString() =>
      '$name${isDirectory ? '/' : ''}'
      '${size == null ? '' : ' ($size bytes)'}';
}

/// What a directory of a bucket directly holds.
class StorageExplorerListing {
  /// The directory that was listed, `''` for the bucket root.
  final String path;

  /// The sub directories, sorted by name.
  final List<StorageExplorerEntry> directories;

  /// The files sitting directly in [path], sorted by name.
  final List<StorageExplorerEntry> files;

  /// Creates a listing, see each field.
  StorageExplorerListing({
    required this.path,
    required this.directories,
    required this.files,
  });

  /// The directories followed by the files, i.e. how a browser shows them.
  List<StorageExplorerEntry> get entries => [...directories, ...files];

  /// Whether nothing was found (or nothing passed the filter).
  bool get isEmpty => directories.isEmpty && files.isEmpty;

  @override
  String toString() =>
      'StorageExplorerListing($path, ${directories.length} dir(s), '
      '${files.length} file(s))';
}

/// Browses a storage bucket as a directory tree, keeping a current [path] the
/// way a shell keeps a current directory.
///
/// A bucket stores flat file names that happen to contain `/`, so the
/// directories are inferred from those names: [list] fetches everything under
/// the current path and groups it one level deep, while [listAll] keeps the
/// flat, recursive view.
///
/// Both accept a name filter, see [storageNameMatchesFilter] for what a filter
/// matches. Paths are always full bucket paths; use
/// [StorageExplorerEntry.relativeTo], [relativePath] or [fullPath] to go from
/// one form to the other.
class StorageExplorer {
  /// The bucket being browsed.
  final Bucket bucket;

  String _path;

  /// Browses [bucket], starting at the directory [path] (the root by default).
  StorageExplorer(this.bucket, {String? path})
    : _path = storagePathNormalize(path ?? '');

  /// The directory currently browsed, `''` for the bucket root.
  String get path => _path;

  /// Moves to [target], the way `cd` does: absolute when it starts with `/`,
  /// relative otherwise, `..` going one level up.
  ///
  /// Nothing is fetched and no check is made — a bucket has no real
  /// directories, so there is nothing to check against.
  ///
  /// Returns the new [path].
  String cd(String target) => _path = storagePathResolve(_path, target);

  /// Moves one level up, i.e. `cd('..')`.
  ///
  /// Returns `false` when already at the bucket root, `true` otherwise.
  bool up() {
    if (_path.isEmpty) {
      return false;
    }
    cd('..');
    return true;
  }

  /// The full bucket path of [path], resolved against the current directory.
  ///
  /// An absolute [path] (starting with `/`) is taken as is, a relative one is
  /// appended to the current directory.
  String fullPath(String path) => storagePathResolve(_path, path);

  /// [path] expressed relatively to the current directory.
  ///
  /// See [storagePathRelative]: a path outside the current directory comes back
  /// unchanged.
  String relativePath(String path) => storagePathRelative(path, from: _path);

  /// Every file under the directory [path] (defaulting to the current one), at
  /// any depth.
  ///
  /// [filter] keeps only the files whose name matches, see
  /// [storageNameMatchesFilter]; it applies to the file name alone, not to the
  /// directories above it. [maxResults] caps how many files the backend
  /// returns, before filtering.
  ///
  /// Returns the matching files, sorted by full path, with the metadata the
  /// listing carried.
  Future<List<StorageExplorerEntry>> listAll({
    String? path,
    String? filter,
    int? maxResults,
  }) async {
    var entries = [
      for (var file in await _getFiles(path: path, maxResults: maxResults))
        _entryFromFile(file),
    ];
    var files = [
      for (var entry in entries)
        if (storageNameMatchesFilter(entry.name, filter)) entry,
    ];
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// What the directory [path] (defaulting to the current one) directly holds:
  /// its sub directories and its files.
  ///
  /// [filter] keeps only the entries whose name matches, see
  /// [storageNameMatchesFilter]; it applies to directory and file names alike.
  /// [maxResults] caps how many files the backend returns, before grouping.
  Future<StorageExplorerListing> list({
    String? path,
    String? filter,
    int? maxResults,
  }) async {
    var target = storagePathNormalize(path ?? _path);
    var files = await _getFiles(path: target, maxResults: maxResults);
    var byPath = {
      for (var file in files)
        storagePathNormalize(file.name): _entryFromFile(file),
    };
    // The raw names, not the normalized ones: a trailing `/` is what tells an
    // explicit directory marker object apart from a file.
    var names = storageDirectoryNamesFromPaths(
      files.map((file) => file.name),
      path: target,
    );
    var directories = [
      for (var name in names.directoryNames)
        if (storageNameMatchesFilter(name, filter))
          StorageExplorerEntry(
            path: storagePathJoin(target, name),
            isDirectory: true,
          ),
    ];
    var fileEntries = [
      for (var name in names.fileNames)
        if (storageNameMatchesFilter(name, filter))
          byPath[storagePathJoin(target, name)]!,
    ];
    return StorageExplorerListing(
      path: target,
      directories: directories,
      files: fileEntries,
    );
  }

  /// Every file of the bucket under the directory [path].
  Future<List<File>> _getFiles({String? path, int? maxResults}) async {
    var target = storagePathNormalize(path ?? _path);
    var prefix = storagePathPrefix(target);
    var response = await bucket.getFiles(
      GetFilesOptions(
        // The whole bucket is `null`, not an empty prefix: some backends
        // refuse one.
        prefix: prefix.isEmpty ? null : prefix,
        maxResults: maxResults,
        autoPaginate: maxResults == null,
      ),
    );
    return response.files;
  }

  /// The metadata of the file at [path] (resolved with [fullPath]), or `null`
  /// when it does not exist.
  Future<FileMetadata?> metadata(String path) async {
    var file = bucket.file(fullPath(path));
    if (!await file.exists()) {
      return null;
    }
    return file.getMetadata();
  }

  /// Whether a file exists at [path] (resolved with [fullPath]).
  Future<bool> exists(String path) => bucket.file(fullPath(path)).exists();

  /// The content of the file at [path] (resolved with [fullPath]), decoded as
  /// UTF-8 text.
  Future<String> readAsString(String path) =>
      bucket.file(fullPath(path)).readAsString();

  /// The raw content of the file at [path] (resolved with [fullPath]).
  Future<Uint8List> readAsBytes(String path) =>
      bucket.file(fullPath(path)).readAsBytes();

  /// Writes [content] as the UTF-8 content of the file at [path] (resolved with
  /// [fullPath]), creating it or overwriting it.
  Future<void> writeAsString(String path, String content) =>
      bucket.file(fullPath(path)).writeAsString(content);

  /// Deletes the file at [path] (resolved with [fullPath]).
  Future<void> delete(String path) => bucket.file(fullPath(path)).delete();
}

/// An entry for [file], reading what its cached metadata carries when the
/// listing populated it.
StorageExplorerEntry _entryFromFile(File file) {
  var metadata = file.metadata;
  return StorageExplorerEntry(
    path: storagePathNormalize(file.name),
    isDirectory: false,
    size: metadata?.size,
    dateUpdated: metadata?.dateUpdated,
    contentType: metadata?.contentType,
  );
}
