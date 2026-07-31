import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';
import 'package:test/test.dart';

void main() {
  group('firestorePathParts', () {
    test('ignores empty segments', () {
      expect(firestorePathParts(''), <String>[]);
      expect(firestorePathParts('/'), <String>[]);
      expect(firestorePathParts('a'), ['a']);
      expect(firestorePathParts('/a//b/'), ['a', 'b']);
    });
  });

  test('firestorePathNormalize', () {
    expect(firestorePathNormalize(''), '');
    expect(firestorePathNormalize('/'), '');
    expect(firestorePathNormalize('/a//b/'), 'a/b');
  });

  group('firestorePathKind', () {
    test('alternates collection and document', () {
      expect(firestorePathKind(''), FirestorePathKind.root);
      expect(firestorePathKind('/'), FirestorePathKind.root);
      expect(firestorePathKind('app'), FirestorePathKind.collection);
      expect(firestorePathKind('app/my_app'), FirestorePathKind.document);
      expect(
        firestorePathKind('app/my_app/project'),
        FirestorePathKind.collection,
      );
      expect(
        firestorePathKind('/app/my_app/project/p1/'),
        FirestorePathKind.document,
      );
    });

    test('predicates', () {
      expect(firestorePathIsRoot(''), isTrue);
      expect(firestorePathIsCollection(''), isFalse);
      expect(firestorePathIsDocument(''), isFalse);

      expect(firestorePathIsCollection('app'), isTrue);
      expect(firestorePathIsDocument('app'), isFalse);

      expect(firestorePathIsDocument('app/my_app'), isTrue);
      expect(firestorePathIsCollection('app/my_app'), isFalse);
    });
  });

  test('firestorePathId', () {
    expect(firestorePathId(''), '');
    expect(firestorePathId('app'), 'app');
    expect(firestorePathId('app/my_app/project/p1'), 'p1');
  });

  test('firestorePathParent', () {
    expect(firestorePathParent(''), isNull);
    expect(firestorePathParent('app'), '');
    expect(firestorePathParent('app/my_app'), 'app');
    expect(firestorePathParent('app/my_app/project/p1'), 'app/my_app/project');
  });

  test('firestorePathJoin', () {
    expect(firestorePathJoin('', 'app'), 'app');
    expect(firestorePathJoin('/a/', '/b/c/'), 'a/b/c');
    expect(firestorePathJoin('app', 'my_app/project'), 'app/my_app/project');
  });

  group('firestorePathResolve', () {
    test('relative', () {
      expect(firestorePathResolve('', 'app'), 'app');
      expect(firestorePathResolve('app', 'my_app'), 'app/my_app');
      expect(
        firestorePathResolve('app', 'my_app/project'),
        'app/my_app/project',
      );
    });

    test('absolute', () {
      expect(firestorePathResolve('app/my_app', '/'), '');
      expect(firestorePathResolve('app/my_app', '/other'), 'other');
    });

    test('dot and dot dot', () {
      expect(firestorePathResolve('app/my_app', '..'), 'app');
      expect(firestorePathResolve('app/my_app', '../../other'), 'other');
      expect(firestorePathResolve('app', '.'), 'app');
      expect(
        firestorePathResolve('app/my_app', './project'),
        'app/my_app/project',
      );
    });

    test('dot dot at the root is a no-op', () {
      expect(firestorePathResolve('', '..'), '');
      expect(firestorePathResolve('app', '../../..'), '');
    });
  });
}
