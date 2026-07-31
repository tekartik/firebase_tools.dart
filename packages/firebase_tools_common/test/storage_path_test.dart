import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';
import 'package:test/test.dart';

void main() {
  test('storagePathParts', () {
    expect(storagePathParts(''), <String>[]);
    expect(storagePathParts('/'), <String>[]);
    expect(storagePathParts('/image//thumb/a.png/'), [
      'image',
      'thumb',
      'a.png',
    ]);
  });

  test('storagePathNormalize', () {
    expect(storagePathNormalize(''), '');
    expect(storagePathNormalize('/image/'), 'image');
    expect(storagePathNormalize('image//thumb'), 'image/thumb');
  });

  test('storagePathJoin', () {
    expect(storagePathJoin('', 'image'), 'image');
    expect(storagePathJoin('image', 'thumb/a.png'), 'image/thumb/a.png');
    expect(storagePathJoin('/image/', '/thumb/'), 'image/thumb');
  });

  test('storagePathName', () {
    expect(storagePathName(''), '');
    expect(storagePathName('a.png'), 'a.png');
    expect(storagePathName('image/thumb/a.png'), 'a.png');
  });

  test('storagePathParent', () {
    expect(storagePathParent(''), isNull);
    expect(storagePathParent('a.png'), '');
    expect(storagePathParent('image/thumb/a.png'), 'image/thumb');
  });

  test('storagePathPrefix', () {
    expect(storagePathPrefix(''), '');
    expect(storagePathPrefix('/'), '');
    expect(storagePathPrefix('image'), 'image/');
    expect(storagePathPrefix('/image/thumb/'), 'image/thumb/');
  });

  group('storagePathIsWithin', () {
    test('everything is within the root', () {
      expect(storagePathIsWithin('a.png', ''), isTrue);
      expect(storagePathIsWithin('image/a.png', ''), isTrue);
    });

    test('the root is within nothing', () {
      expect(storagePathIsWithin('', ''), isFalse);
      expect(storagePathIsWithin('', 'image'), isFalse);
    });

    test('a path is not within itself', () {
      expect(storagePathIsWithin('image', 'image'), isFalse);
    });

    test('at any depth', () {
      expect(storagePathIsWithin('image/thumb/a.png', 'image'), isTrue);
      expect(storagePathIsWithin('image/thumb/a.png', 'image/thumb'), isTrue);
      expect(storagePathIsWithin('imageother/a.png', 'image'), isFalse);
    });
  });

  group('storagePathRelative', () {
    test('inside', () {
      expect(
        storagePathRelative('image/thumb/a.png', from: 'image'),
        'thumb/a.png',
      );
      expect(storagePathRelative('image/a.png', from: ''), 'image/a.png');
    });

    test('outside comes back unchanged', () {
      expect(storagePathRelative('other/a.png', from: 'image'), 'other/a.png');
      expect(storagePathRelative('/image/', from: 'image'), 'image');
    });
  });

  group('storagePathResolve', () {
    test('relative', () {
      expect(storagePathResolve('', 'image'), 'image');
      expect(storagePathResolve('image', 'thumb'), 'image/thumb');
    });

    test('absolute', () {
      expect(storagePathResolve('image/thumb', '/'), '');
      expect(storagePathResolve('image/thumb', '/other'), 'other');
    });

    test('dot and dot dot', () {
      expect(storagePathResolve('image/thumb', '..'), 'image');
      expect(storagePathResolve('image/thumb', '../../other'), 'other');
      expect(storagePathResolve('image', './thumb'), 'image/thumb');
    });

    test('dot dot at the root is a no-op', () {
      expect(storagePathResolve('', '..'), '');
      expect(storagePathResolve('image', '../..'), '');
    });
  });

  group('storageNameMatchesFilter', () {
    test('no filter matches everything', () {
      expect(storageNameMatchesFilter('a.png', null), isTrue);
      expect(storageNameMatchesFilter('a.png', ''), isTrue);
    });

    test('plain filter is a case insensitive contains', () {
      expect(storageNameMatchesFilter('Image.PNG', 'png'), isTrue);
      expect(storageNameMatchesFilter('Image.PNG', 'IMA'), isTrue);
      expect(storageNameMatchesFilter('Image.PNG', 'jpg'), isFalse);
    });

    test('a filter with a wildcard is an anchored glob', () {
      expect(storageNameMatchesFilter('a.png', '*.png'), isTrue);
      expect(storageNameMatchesFilter('a.png', '*.PNG'), isTrue);
      expect(storageNameMatchesFilter('a.png.bak', '*.png'), isFalse);
      expect(storageNameMatchesFilter('a.png', 'a?.png'), isFalse);
      expect(storageNameMatchesFilter('ab.png', 'a?.png'), isTrue);
    });

    test('a glob does not match a mere substring', () {
      expect(storageNameMatchesFilter('thumb_a.png', 'a*'), isFalse);
      expect(storageNameMatchesFilter('a_thumb.png', 'a*'), isTrue);
    });

    test('special characters are escaped', () {
      expect(storageNameMatchesFilter('axpng', '*.png'), isFalse);
      expect(storageNameMatchesFilter('a+b.png', 'a+b*'), isTrue);
    });
  });

  group('storageDirectoryNamesFromPaths', () {
    test('empty', () {
      var names = storageDirectoryNamesFromPaths([]);
      expect(names.directoryNames, <String>[]);
      expect(names.fileNames, <String>[]);
    });

    test('groups one level deep at the root', () {
      var names = storageDirectoryNamesFromPaths([
        'a.png',
        'image/b.png',
        'image/thumb/c.png',
        'other/d.png',
      ]);
      expect(names.directoryNames, ['image', 'other']);
      expect(names.fileNames, ['a.png']);
    });

    test('groups one level deep in a directory', () {
      var names = storageDirectoryNamesFromPaths([
        'a.png',
        'image/b.png',
        'image/thumb/c.png',
        'image/thumb/big/d.png',
      ], path: 'image');
      expect(names.directoryNames, ['thumb']);
      expect(names.fileNames, ['b.png']);
    });

    test('ignores what is outside the directory', () {
      var names = storageDirectoryNamesFromPaths([
        'a.png',
        'imageother/b.png',
        'image/c.png',
      ], path: 'image');
      expect(names.directoryNames, <String>[]);
      expect(names.fileNames, ['c.png']);
    });

    test('names are distinct and sorted', () {
      var names = storageDirectoryNamesFromPaths([
        'b/2.png',
        'a/1.png',
        'a/2.png',
        'z.png',
        'a.png',
      ]);
      expect(names.directoryNames, ['a', 'b']);
      expect(names.fileNames, ['a.png', 'z.png']);
    });

    test('an explicit directory marker is a directory, never a file', () {
      var names = storageDirectoryNamesFromPaths(['empty/', 'a.png']);
      expect(names.directoryNames, ['empty']);
      expect(names.fileNames, ['a.png']);
    });

    test('a name that is both a file and a directory shows up twice', () {
      var names = storageDirectoryNamesFromPaths(['image', 'image/a.png']);
      expect(names.directoryNames, ['image']);
      expect(names.fileNames, ['image']);
    });
  });
}
