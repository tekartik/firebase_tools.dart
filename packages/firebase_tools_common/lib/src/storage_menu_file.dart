import 'package:tekartik_firebase_storage/storage.dart';

import 'storage_explorer.dart';
import 'storage_path.dart';

/// A file the storage menu acts on, its path resolved exactly once.
///
/// The [StorageExplorer] methods resolve their path against the current
/// directory, so handing them a path the menu already resolved resolves it a
/// second time: in `image`, `a.png` became `image/image/a.png` and "delete
/// file" removed that other file. Everything here goes through [file], built
/// from [fullPath] alone.
class StorageMenuFile {
  /// The explorer the file was resolved against.
  final StorageExplorer explorer;

  /// The full bucket path of the file, e.g. `image/a.png`.
  final String fullPath;

  /// The bucket file at [fullPath].
  final File file;

  /// The file [path] as typed by the user: absolute with a leading `/`,
  /// relative to the current directory of [explorer] otherwise.
  StorageMenuFile(StorageExplorer explorer, String path)
    : this._(explorer, explorer.fullPath(path));

  /// The file of a listing [entry], whose path already is a full bucket path.
  StorageMenuFile.entry(StorageExplorer explorer, StorageExplorerEntry entry)
    : this._(explorer, entry.path);

  StorageMenuFile._(this.explorer, this.fullPath)
    : file = explorer.bucket.file(fullPath);

  /// The file name, i.e. the last segment of [fullPath].
  String get name => storagePathName(fullPath);

  /// [fullPath] expressed relatively to the current directory of [explorer].
  String get relativePath => explorer.relativePath(fullPath);

  /// Whether the file exists.
  Future<bool> exists() => file.exists();

  /// The metadata of the file, or `null` when it does not exist.
  Future<FileMetadata?> metadata() async {
    if (!await file.exists()) {
      return null;
    }
    return file.getMetadata();
  }

  /// The content of the file, decoded as UTF-8 text.
  Future<String> readAsString() => file.readAsString();

  /// Deletes the file.
  Future<void> delete() => file.delete();
}
