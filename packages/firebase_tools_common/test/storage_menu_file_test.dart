@TestOn('vm')
library;

import 'package:tekartik_firebase_storage_fs/storage_fs.dart';
import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';
import 'package:tekartik_firebase_tools_common/src/storage_menu_file.dart';
import 'package:test/test.dart';

void main() {
  // What the storage menu items ('show file metadata', 'read file as text',
  // 'delete file', 'pick' on a file) act on, in a folder other than the root
  // holding a sub folder of the same name.
  group('StorageMenuFile in a sub folder', () {
    late Bucket bucket;
    late StorageExplorer explorer;

    setUp(() async {
      bucket = newStorageMemory().bucket('test-bucket');
      await bucket.file('image/a.png').writeAsString('a');
      await bucket.file('image/image/a.png').writeAsString('nested a');
      explorer = StorageExplorer(bucket)..cd('image');
    });

    test('relative path', () async {
      var file = StorageMenuFile(explorer, 'a.png');
      expect(file.fullPath, 'image/a.png');
      expect(file.relativePath, 'a.png');
      expect(file.name, 'a.png');
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), 'a');
      expect((await file.metadata())!.size, 1);
    });

    test('absolute path', () async {
      var file = StorageMenuFile(explorer, '/image/image/a.png');
      expect(file.fullPath, 'image/image/a.png');
      expect(await file.readAsString(), 'nested a');
    });

    test('missing file', () async {
      var file = StorageMenuFile(explorer, 'image/b.png');
      expect(await file.exists(), isFalse);
      expect(await file.metadata(), isNull);
    });

    test('listing entry', () async {
      var entry = (await explorer.list()).files.single;
      expect(entry.path, 'image/a.png');
      var file = StorageMenuFile.entry(explorer, entry);
      expect(file.fullPath, 'image/a.png');
      expect((await file.metadata())!.size, 1);
    });

    test('delete removes the named file only', () async {
      await StorageMenuFile(explorer, 'a.png').delete();
      expect(await bucket.file('image/a.png').exists(), isFalse);
      expect(await bucket.file('image/image/a.png').exists(), isTrue);
    });
  });
}
