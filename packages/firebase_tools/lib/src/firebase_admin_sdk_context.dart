import 'package:tekartik_firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_auth_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_storage_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firestore_admin_sdk.dart';
import 'package:tekartik_firebase_tools_common/firebase_tools_common.dart';

/// The document ids lister [firestore] supports natively, if any.
///
/// Returns an admin sdk backed lister for a [FirestoreAdminSdk] — its native
/// instance is the only way to reach `listDocuments()`, which the tekartik
/// abstraction does not cover — and `null` for any other implementation, which
/// can only list the documents a query returns.
///
/// This is the [FirestoreDocumentIdsListerResolver] every context built here
/// passes on, so a collection listing reports the documents that do not exist
/// but hold sub collections.
FirestoreCollectionDocumentIdsLister? firestoreAdminSdkDocumentIdsLister(
  Firestore firestore,
) {
  if (firestore is! FirestoreAdminSdk) {
    return null;
  }
  return (collectionRef) async {
    var nativeRefs = await firestore.nativeInstance
        .collection(collectionRef.path)
        .listDocuments();
    return nativeRefs.map((ref) => ref.id).toList();
  };
}

/// A firebase project reached through the admin sdk with the ambient
/// credentials, i.e. `gcloud auth application-default login` or the service
/// account of the machine it runs on.
///
/// [projectId] names the project to reach; leave it `null` to let the ambient
/// environment decide (`GOOGLE_CLOUD_PROJECT`, the credentials themselves, …),
/// in which case no app option is set at all and the sdk keeps every one of its
/// defaults. [storageBucket] overrides the default bucket of the project.
///
/// The app is built on first use, so declaring a menu over the returned context
/// costs no network call and no credential lookup.
FirebaseToolsContext newFirebaseToolsContextAdminSdk({
  String? projectId,
  String? storageBucket,
}) {
  return FirebaseToolsContext(
    projectId: projectId,
    storageBucket: storageBucket,
    documentIdsListerResolver: firestoreAdminSdkDocumentIdsLister,
    servicesBuilder: () async => _adminSdkServices(
      firebaseAdminSdk.initializeApp(
        // No options at all when there is nothing to say, so the sdk keeps
        // every one of its own defaults.
        options: (projectId == null && storageBucket == null)
            ? null
            : FirebaseAppOptions(
                projectId: projectId,
                storageBucket: storageBucket,
              ),
      ),
    ),
  );
}

/// A firebase project reached through the admin sdk with the service account
/// [serviceAccountMap], i.e. the parsed content of a service account json.
///
/// This is the flavour to use when the credentials are checked into a private
/// repository instead of coming from the environment.
///
/// [projectId] defaults to the `project_id` of [serviceAccountMap].
/// [storageBucket] overrides the default bucket of the project.
FirebaseToolsContext newFirebaseToolsContextServiceAccountMap(
  Map serviceAccountMap, {
  String? projectId,
  String? storageBucket,
}) {
  return FirebaseToolsContext(
    projectId: projectId ?? serviceAccountMap['project_id']?.toString(),
    storageBucket: storageBucket,
    documentIdsListerResolver: firestoreAdminSdkDocumentIdsLister,
    servicesBuilder: () async => _adminSdkServices(
      await firebaseAdminSdk.initializeAppWithServiceAccountMap(
        serviceAccountMap,
        options: storageBucket == null
            ? null
            : FirebaseAppOptions(storageBucket: storageBucket),
      ),
    ),
  );
}

/// The project a firebase folder deploys to, reached through the admin sdk with
/// the ambient credentials.
///
/// [path] is the firebase folder, defaulting to the current directory; its
/// `.firebaserc` names the project, see [firebaseFolderProjectId] for when that
/// throws. [storageBucket] overrides the default bucket of the project.
FirebaseToolsContext newFirebaseToolsContextFirebaseFolder({
  String? path,
  String? storageBucket,
}) => newFirebaseToolsContextAdminSdk(
  projectId: firebaseFolderProjectId(path: path),
  storageBucket: storageBucket,
);

/// The admin sdk services of [firebaseApp].
FirebaseToolsServices _adminSdkServices(FirebaseApp firebaseApp) =>
    FirebaseToolsServices(
      firebaseApp: firebaseApp,
      authService: firebaseAuthServiceAdminSdk,
      firestoreService: firestoreServiceAdminSdk,
      storageService: firebaseStorageServiceAdminSdk,
    );
