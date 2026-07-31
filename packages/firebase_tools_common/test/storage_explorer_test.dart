@TestOn('vm')
library;

import 'package:tekartik_firebase_storage_fs/storage_fs.dart';
import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';
import 'package:test/test.dart';

void main() {
  late Bucket bucket;
  late StorageExplorer explorer;

  setUp(() async {
    bucket = newStorageMemory().bucket('test-bucket');
    explorer = StorageExplorer(bucket);
    for (var entry in {
      'root.txt': 'root',
      'image/a.png': 'a',
      'image/b.jpg': 'b',
      'image/thumb/a.png': 'thumb a',
      'image/thumb/big/a.png': 'big a',
      'other/c.txt': 'c',
    }.entries) {
      await bucket.file(entry.key).writeAsString(entry.value);
    }
  });

  group('navigation', () {
    test('starts at the bucket root', () {
      expect(explorer.path, '');
    });

    test('starts where it was told to', () {
      expect(
        StorageExplorer(bucket, path: '/image/thumb/').path,
        'image/thumb',
      );
    });

    test('cd relative then absolute', () {
      expect(explorer.cd('image'), 'image');
      expect(explorer.cd('thumb'), 'image/thumb');
      expect(explorer.cd('..'), 'image');
      expect(explorer.cd('/other'), 'other');
    });

    test('up stops at the bucket root', () {
      explorer.cd('image/thumb');
      expect(explorer.up(), isTrue);
      expect(explorer.path, 'image');
      expect(explorer.up(), isTrue);
      expect(explorer.path, '');
      expect(explorer.up(), isFalse);
    });
  });

  group('full and relative paths', () {
    test('fullPath resolves against the current directory', () {
      explorer.cd('image');
      expect(explorer.fullPath('a.png'), 'image/a.png');
      expect(explorer.fullPath('thumb/a.png'), 'image/thumb/a.png');
      expect(explorer.fullPath('/other/c.txt'), 'other/c.txt');
      expect(explorer.fullPath('../other/c.txt'), 'other/c.txt');
    });

    test('relativePath strips the current directory', () {
      explorer.cd('image');
      expect(explorer.relativePath('image/thumb/a.png'), 'thumb/a.png');
      expect(explorer.relativePath('other/c.txt'), 'other/c.txt');
    });

    test('an entry knows both forms', () async {
      var listing = await explorer.list(path: 'image');
      var file = listing.files.first;
      expect(file.path, 'image/a.png');
      expect(file.name, 'a.png');
      expect(file.relativeTo('image'), 'a.png');
      expect(file.relativeTo(''), 'image/a.png');
    });
  });

  group('list', () {
    test('the bucket root, one level deep', () async {
      var listing = await explorer.list();
      expect(listing.path, '');
      expect(listing.directories.map((e) => e.name), ['image', 'other']);
      expect(listing.files.map((e) => e.name), ['root.txt']);
      expect(listing.entries.map((e) => e.name), [
        'image',
        'other',
        'root.txt',
      ]);
      expect(listing.isEmpty, isFalse);
    });

    test('a directory, one level deep', () async {
      var listing = await explorer.list(path: 'image');
      expect(listing.directories.map((e) => e.name), ['thumb']);
      expect(listing.files.map((e) => e.name), ['a.png', 'b.jpg']);
    });

    test('uses the current directory by default', () async {
      explorer.cd('image/thumb');
      var listing = await explorer.list();
      expect(listing.path, 'image/thumb');
      expect(listing.directories.map((e) => e.name), ['big']);
      expect(listing.files.map((e) => e.name), ['a.png']);
    });

    test('directories carry a full path and are marked as such', () async {
      var listing = await explorer.list(path: 'image');
      var directory = listing.directories.single;
      expect(directory.path, 'image/thumb');
      expect(directory.isDirectory, isTrue);
      expect(directory.size, isNull);
    });

    test('files carry their metadata', () async {
      var listing = await explorer.list(path: 'other');
      var file = listing.files.single;
      expect(file.isDirectory, isFalse);
      expect(file.size, 'c'.length);
    });

    test('an empty spot', () async {
      var listing = await explorer.list(path: 'nothing');
      expect(listing.isEmpty, isTrue);
    });

    test('a filter keeps the matching names, directories included', () async {
      var listing = await explorer.list(filter: 'o');
      expect(listing.directories.map((e) => e.name), ['other']);
      expect(listing.files.map((e) => e.name), ['root.txt']);
    });

    test('a glob filter', () async {
      var listing = await explorer.list(path: 'image', filter: '*.png');
      expect(listing.directories, isEmpty);
      expect(listing.files.map((e) => e.name), ['a.png']);
    });
  });

  group('listAll', () {
    test('every file below, at any depth, sorted by full path', () async {
      var files = await explorer.listAll(path: 'image');
      expect(files.map((e) => e.path), [
        'image/a.png',
        'image/b.jpg',
        'image/thumb/a.png',
        'image/thumb/big/a.png',
      ]);
    });

    test('the whole bucket', () async {
      var files = await explorer.listAll();
      expect(files, hasLength(6));
    });

    test('the filter applies to the file name alone', () async {
      var files = await explorer.listAll(filter: '*.png');
      expect(files.map((e) => e.path), [
        'image/a.png',
        'image/thumb/a.png',
        'image/thumb/big/a.png',
      ]);
    });

    test('no match', () async {
      expect(await explorer.listAll(filter: '*.gif'), isEmpty);
    });
  });

  group('files', () {
    test('exists', () async {
      expect(await explorer.exists('image/a.png'), isTrue);
      expect(await explorer.exists('image/nothing.png'), isFalse);
    });

    test('exists resolves against the current directory', () async {
      explorer.cd('image');
      expect(await explorer.exists('a.png'), isTrue);
    });

    test('readAsString', () async {
      expect(await explorer.readAsString('image/thumb/a.png'), 'thumb a');
    });

    test('readAsBytes', () async {
      expect(await explorer.readAsBytes('other/c.txt'), 'c'.codeUnits);
    });

    test('writeAsString creates the file', () async {
      await explorer.writeAsString('image/new.txt', 'new');
      expect(await explorer.readAsString('image/new.txt'), 'new');
      var listing = await explorer.list(path: 'image');
      expect(listing.files.map((e) => e.name), ['a.png', 'b.jpg', 'new.txt']);
    });

    test('metadata', () async {
      var metadata = await explorer.metadata('image/thumb/a.png');
      expect(metadata!.size, 'thumb a'.length);
    });

    test('metadata of a file that does not exist', () async {
      expect(await explorer.metadata('image/nothing.png'), isNull);
    });

    test('delete', () async {
      await explorer.delete('image/a.png');
      expect(await explorer.exists('image/a.png'), isFalse);
      var listing = await explorer.list(path: 'image');
      expect(listing.files.map((e) => e.name), ['b.jpg']);
    });
  });
}
