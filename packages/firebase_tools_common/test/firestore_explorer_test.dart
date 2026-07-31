@TestOn('vm')
library;

import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';
import 'package:test/test.dart';

void main() {
  late Firestore firestore;
  late FirestoreExplorer explorer;

  setUp(() async {
    firestore = newFirestoreMemory();
    explorer = FirestoreExplorer(firestore);
    await firestore.doc('app/app1').set({'name': 'App 1'});
    await firestore.doc('app/app1/project/p1').set({'name': 'Project 1'});
    await firestore.doc('app/app1/project/p2').set({'name': 'Project 2'});
    await firestore.doc('other/o1').set({'name': 'Other 1'});
  });

  group('navigation', () {
    test('starts at the root', () {
      expect(explorer.path, '');
      expect(explorer.kind, FirestorePathKind.root);
    });

    test('starts where it was told to', () {
      expect(FirestoreExplorer(firestore, path: '/app/app1/').path, 'app/app1');
    });

    test('cd relative then absolute', () {
      expect(explorer.cd('app'), 'app');
      expect(explorer.kind, FirestorePathKind.collection);
      expect(explorer.cd('app1'), 'app/app1');
      expect(explorer.kind, FirestorePathKind.document);
      expect(explorer.cd('/other'), 'other');
    });

    test('up stops at the root', () {
      explorer.cd('app/app1');
      expect(explorer.up(), isTrue);
      expect(explorer.path, 'app');
      expect(explorer.up(), isTrue);
      expect(explorer.path, '');
      expect(explorer.up(), isFalse);
      expect(explorer.path, '');
    });

    test('cd into a document that does not exist', () {
      expect(explorer.cd('app/missing'), 'app/missing');
      expect(explorer.kind, FirestorePathKind.document);
    });
  });

  group('listCollectionIds', () {
    test('root collections', () async {
      expect(await explorer.listCollectionIds(), ['app', 'other']);
    });

    test('sub collections of a document', () async {
      expect(await explorer.listCollectionIds('app/app1'), ['project']);
    });

    test('uses the current path by default', () async {
      explorer.cd('app/app1');
      expect(await explorer.listCollectionIds(), ['project']);
    });

    test('a collection path is refused', () async {
      await expectLater(
        () => explorer.listCollectionIds('app'),
        throwsArgumentError,
      );
    });
  });

  group('listDocuments', () {
    test('lists the documents of a collection, sorted', () async {
      var documents = await explorer.listDocuments('app/app1/project');
      expect(documents.map((e) => e.id), ['p1', 'p2']);
      expect(documents.first.exists, isTrue);
      expect(documents.first.path, 'app/app1/project/p1');
      expect(documents.first.data, {'name': 'Project 1'});
    });

    test('honours the limit', () async {
      var documents = await explorer.listDocuments('app/app1/project', 1);
      expect(documents, hasLength(1));
    });

    test('a document path is refused', () async {
      await expectLater(
        () => explorer.listDocuments('app/app1'),
        throwsArgumentError,
      );
    });

    test('without a lister, only the existing documents show up', () async {
      // The sembast firestore has no listDocuments, so a document that was
      // never written stays hidden even though it holds a sub collection.
      expect(explorer.supportsMissingDocuments, isFalse);
      await firestore.doc('app/ghost/project/p1').set({'name': 'Ghost'});
      var documents = await explorer.listDocuments('app');
      expect(documents.map((e) => e.id), ['app1']);
    });

    test('a lister brings the missing documents in', () async {
      await firestore.doc('app/ghost/project/p1').set({'name': 'Ghost'});
      var listing = FirestoreExplorer(
        firestore,
        documentIdsLister: (collectionRef) async =>
            collectionRef.path == 'app' ? ['app1', 'ghost'] : [],
      );
      expect(listing.supportsMissingDocuments, isTrue);
      var documents = await listing.listDocuments('app');
      expect(documents.map((e) => e.id), ['app1', 'ghost']);
      var ghost = documents.last;
      expect(ghost.exists, isFalse);
      expect(ghost.data, isNull);
      expect(ghost.path, 'app/ghost');
      expect('$ghost', 'ghost (no document)');
    });
  });

  group('getDocument', () {
    test('an existing document, with its sub collections', () async {
      var document = await explorer.getDocument('app/app1');
      expect(document.exists, isTrue);
      expect(document.data, {'name': 'App 1'});
      expect(document.collectionIds, ['project']);
      expect(document.id, 'app1');
    });

    test('a document that does not exist still lists its children', () async {
      await firestore.doc('app/ghost/project/p1').set({'name': 'Ghost'});
      var document = await explorer.getDocument('app/ghost');
      expect(document.exists, isFalse);
      expect(document.data, isNull);
      expect(document.collectionIds, ['project']);
    });

    test('a document that exists nowhere', () async {
      var document = await explorer.getDocument('app/nothing');
      expect(document.exists, isFalse);
      expect(document.collectionIds, isEmpty);
    });

    test('a collection path is refused', () async {
      await expectLater(() => explorer.getDocument('app'), throwsArgumentError);
    });
  });

  group('list', () {
    test('the root lists its collections', () async {
      var listing = await explorer.list();
      expect(listing.kind, FirestorePathKind.root);
      expect(listing.collectionIds, ['app', 'other']);
      expect(listing.documents, isEmpty);
      expect(listing.isEmpty, isFalse);
    });

    test('a collection lists its documents', () async {
      var listing = await explorer.list(path: 'app/app1/project');
      expect(listing.kind, FirestorePathKind.collection);
      expect(listing.documents.map((e) => e.id), ['p1', 'p2']);
      expect(listing.collectionIds, isEmpty);
    });

    test('a document lists its collections', () async {
      var listing = await explorer.list(path: 'app/app1');
      expect(listing.kind, FirestorePathKind.document);
      expect(listing.collectionIds, ['project']);
    });

    test('an empty spot', () async {
      var listing = await explorer.list(path: 'app/nothing');
      expect(listing.isEmpty, isTrue);
    });
  });

  group('deleteDocument', () {
    test('deletes the document but keeps its children', () async {
      await explorer.deleteDocument('app/app1');
      var document = await explorer.getDocument('app/app1');
      expect(document.exists, isFalse);
      expect(document.collectionIds, ['project']);
    });

    test('a collection path is refused', () async {
      await expectLater(
        () => explorer.deleteDocument('app'),
        throwsArgumentError,
      );
    });
  });
}
