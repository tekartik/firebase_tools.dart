@TestOn('vm')
library;

import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_tools/firebase_tools.dart';
import 'package:test/test.dart';

void main() {
  group('firestoreAdminSdkDocumentIdsLister', () {
    test('is null for a firestore that is not admin sdk backed', () {
      expect(firestoreAdminSdkDocumentIdsLister(newFirestoreMemory()), isNull);
    });

    test('an explorer built with it lists only what exists', () async {
      var firestore = newFirestoreMemory();
      var explorer = FirestoreExplorer(
        firestore,
        documentIdsListerResolver: firestoreAdminSdkDocumentIdsLister,
      );
      expect(explorer.supportsMissingDocuments, isFalse);
      await firestore.doc('app/ghost/project/p1').set({'name': 'Ghost'});
      await firestore.doc('app/app1').set({'name': 'App 1'});
      var documents = await explorer.listDocuments('app');
      expect(documents.map((e) => e.id), ['app1']);
    });
  });

  group('newFirebaseToolsContextAdminSdk', () {
    test('reports the project id it was given', () {
      var context = newFirebaseToolsContextAdminSdk(projectId: 'my_project');
      expect(context.projectId, 'my_project');
      expect(context.storageBucket, isNull);
    });

    test('reports the storage bucket it was given', () {
      var context = newFirebaseToolsContextAdminSdk(
        projectId: 'my_project',
        storageBucket: 'my-bucket',
      );
      expect(context.storageBucket, 'my-bucket');
    });

    test('takes no project id at all', () {
      // Nothing is reached until the services are used, so declaring this
      // costs no credential lookup even without a project.
      expect(newFirebaseToolsContextAdminSdk().projectId, isNull);
    });

    test('wires the admin sdk document ids lister in', () {
      var context = newFirebaseToolsContextAdminSdk(projectId: 'my_project');
      expect(
        context.documentIdsListerResolver,
        same(firestoreAdminSdkDocumentIdsLister),
      );
    });

    test('builds nothing until the services are used', () {
      // Declaring a menu over a context must not reach the network nor look
      // any credential up; the constructor doing anything would break that.
      expect(
        () => newFirebaseToolsContextAdminSdk(projectId: 'my_project'),
        returnsNormally,
      );
    });
  });

  group('newFirebaseToolsContextServiceAccountMap', () {
    test('takes the project id of the service account', () {
      var context = newFirebaseToolsContextServiceAccountMap({
        'project_id': 'from_service_account',
      });
      expect(context.projectId, 'from_service_account');
      expect(
        context.documentIdsListerResolver,
        same(firestoreAdminSdkDocumentIdsLister),
      );
    });

    test('an explicit project id wins', () {
      var context = newFirebaseToolsContextServiceAccountMap({
        'project_id': 'from_service_account',
      }, projectId: 'explicit');
      expect(context.projectId, 'explicit');
    });

    test('a service account without a project id', () {
      expect(newFirebaseToolsContextServiceAccountMap({}).projectId, isNull);
    });
  });

  group('newFirebaseToolsContextFirebaseFolder', () {
    test('throws when the folder is not a firebase folder', () {
      expect(
        () => newFirebaseToolsContextFirebaseFolder(path: '.dart_tool'),
        throwsStateError,
      );
    });
  });
}
