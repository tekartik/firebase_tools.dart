@TestOn('vm')
library;

import 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_firebase_storage_fs/storage_fs.dart';
import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';
import 'package:test/test.dart';

/// A context over in-memory services, i.e. what a test uses in place of the
/// admin sdk.
FirebaseToolsContext _newMemoryContext({String projectId = 'test_project'}) {
  var firebaseApp = newFirebaseMemory().initializeApp(
    options: FirebaseAppOptions(projectId: projectId),
  );
  return FirebaseToolsContext.services(
    FirebaseToolsServices(
      firebaseApp: firebaseApp,
      authService: newFirebaseAuthServiceMemory(),
      firestoreService: newFirestoreServiceMemory(),
      storageService: newStorageServiceMemory(),
    ),
  );
}

void main() {
  test('reports the project id of the app', () async {
    var context = _newMemoryContext(projectId: 'my_project');
    expect(context.projectId, 'my_project');
  });

  test('an explicit project id wins over the one of the app', () async {
    var firebaseApp = newFirebaseMemory().initializeApp(
      options: FirebaseAppOptions(projectId: 'from_app'),
    );
    var context = FirebaseToolsContext.services(
      FirebaseToolsServices(
        firebaseApp: firebaseApp,
        authService: newFirebaseAuthServiceMemory(),
        firestoreService: newFirestoreServiceMemory(),
        storageService: newStorageServiceMemory(),
      ),
      projectId: 'explicit',
    );
    expect(context.projectId, 'explicit');
  });

  test('the services are built once, lazily', () async {
    var built = 0;
    var context = FirebaseToolsContext(
      projectId: 'my_project',
      servicesBuilder: () async {
        built++;
        return FirebaseToolsServices(
          firebaseApp: newFirebaseAppMemory(),
          authService: newFirebaseAuthServiceMemory(),
          firestoreService: newFirestoreServiceMemory(),
          storageService: newStorageServiceMemory(),
        );
      },
    );
    expect(built, 0, reason: 'declaring a context costs nothing');
    await context.services;
    await context.services;
    await context.firestore;
    expect(built, 1);
  });

  test('gives an explorer for each service', () async {
    var context = _newMemoryContext();
    expect(await context.authExplorer, isA<FirebaseAuthExplorer>());
    expect(await context.firestoreExplorer, isA<FirestoreExplorer>());
    expect(await context.storageExplorer, isA<StorageExplorer>());
  });

  test('the same explorer comes back, so its path is kept', () async {
    var context = _newMemoryContext();
    var explorer = await context.firestoreExplorer;
    explorer.cd('app/app1');
    expect((await context.firestoreExplorer).path, 'app/app1');

    var storageExplorer = await context.storageExplorer;
    storageExplorer.cd('image/thumb');
    expect((await context.storageExplorer).path, 'image/thumb');
  });

  test('the explorers act on the services of the context', () async {
    var context = _newMemoryContext();
    var firestore = await context.firestore;
    await firestore.doc('app/app1').set({'name': 'App 1'});
    var listing = await (await context.firestoreExplorer).list();
    expect(listing.collectionIds, ['app']);

    var bucket = await context.bucket();
    await bucket.file('image/a.png').writeAsString('a');
    var storageListing = await (await context.storageExplorer).list();
    expect(storageListing.directories.map((e) => e.name), ['image']);
  });
}
