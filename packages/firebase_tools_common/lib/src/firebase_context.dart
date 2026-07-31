import 'package:tekartik_firebase_auth/auth.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_firebase_storage/storage.dart';

import 'auth_explorer.dart';
import 'firestore_explorer.dart';
import 'storage_explorer.dart';

/// An initialized firebase app and the three services a tool explores.
///
/// Bundled rather than reached through `FirebaseApp.getProduct` so any
/// implementation works, the in-memory ones of the tests included.
class FirebaseToolsServices {
  /// The initialized app the services are bound to.
  final FirebaseApp firebaseApp;

  /// The auth service, i.e. what resolves [auth].
  final FirebaseAuthService authService;

  /// The firestore service, i.e. what resolves [firestore].
  final FirestoreService firestoreService;

  /// The storage service, i.e. what resolves [storage].
  final FirebaseStorageService storageService;

  /// Bundles [firebaseApp] with the services acting on it.
  FirebaseToolsServices({
    required this.firebaseApp,
    required this.authService,
    required this.firestoreService,
    required this.storageService,
  });

  /// The auth of [firebaseApp].
  FirebaseAuth get auth => authService.auth(firebaseApp);

  /// The firestore of [firebaseApp].
  Firestore get firestore => firestoreService.firestore(firebaseApp);

  /// The storage of [firebaseApp].
  FirebaseStorage get storage => storageService.storage(firebaseApp);
}

/// A firebase project a dev tool acts on.
///
/// Whatever builds the services decides what the tool can do: listing and
/// creating auth users, and reading firestore past its rules, needs privileged
/// credentials — the admin sdk, in practice, see
/// `newFirebaseToolsContextAdminSdk` in `tekartik_firebase_tools`. That belongs
/// in a dev tool, never in an app.
///
/// The services are built on first use, not on construction: declaring a menu
/// over a context costs no network call and no credential lookup.
class FirebaseToolsContext {
  /// The firebase project id, informative.
  ///
  /// The credentials decide which project is really reached; this is what the
  /// tool reports and what it was asked to work on. `null` when it was left to
  /// the ambient environment to decide.
  final String? projectId;

  /// The storage bucket the tool browses, or `null` for the default bucket of
  /// the project.
  final String? storageBucket;

  /// Builds the app and its services, called once, on first use.
  final Future<FirebaseToolsServices> Function() servicesBuilder;

  /// Asked for the document ids lister of the firestore when
  /// [firestoreExplorer] is built, so a collection listing can report the
  /// documents that do not exist but hold sub collections.
  ///
  /// `null` — the default — lists only the documents that exist. See
  /// [FirestoreDocumentIdsListerResolver].
  final FirestoreDocumentIdsListerResolver? documentIdsListerResolver;

  /// Creates a context whose services are built by [servicesBuilder] on first
  /// use.
  ///
  /// [projectId] and [storageBucket] are what the tool reports; they do not
  /// drive [servicesBuilder], which is free to reach whatever it wants.
  /// [documentIdsListerResolver] is what the firestore explorer gets, see the
  /// field.
  FirebaseToolsContext({
    required this.servicesBuilder,
    this.projectId,
    this.storageBucket,
    this.documentIdsListerResolver,
  });

  /// A context over already initialized [services], whichever implementation
  /// built them.
  ///
  /// [projectId] defaults to the project id of the app. [storageBucket] and
  /// [documentIdsListerResolver] are the ones of the default constructor. This
  /// is what a test uses, with the in-memory implementations.
  factory FirebaseToolsContext.services(
    FirebaseToolsServices services, {
    String? projectId,
    String? storageBucket,
    FirestoreDocumentIdsListerResolver? documentIdsListerResolver,
  }) => FirebaseToolsContext(
    projectId: projectId ?? services.firebaseApp.options.projectId,
    storageBucket: storageBucket,
    documentIdsListerResolver: documentIdsListerResolver,
    servicesBuilder: () async => services,
  );

  Future<FirebaseToolsServices>? _services;

  /// The app and its services, built on first use and kept afterwards.
  Future<FirebaseToolsServices> get services => _services ??= servicesBuilder();

  /// The auth of the project.
  Future<FirebaseAuth> get auth async => (await services).auth;

  /// The firestore of the project.
  Future<Firestore> get firestore async => (await services).firestore;

  /// The storage of the project.
  Future<FirebaseStorage> get storage async => (await services).storage;

  /// The bucket named [name], or the one of [storageBucket] when [name] is
  /// omitted, or the default bucket of the project when neither is set.
  Future<Bucket> bucket([String? name]) async =>
      (await storage).bucket(name ?? storageBucket);

  /// Explores the auth users of the project.
  Future<FirebaseAuthExplorer> get authExplorer async =>
      _authExplorer ??= FirebaseAuthExplorer(await auth);
  FirebaseAuthExplorer? _authExplorer;

  /// Browses the firestore database of the project.
  ///
  /// The same explorer comes back on every call, so the path it is on is kept
  /// between two menu items.
  Future<FirestoreExplorer> get firestoreExplorer async =>
      _firestoreExplorer ??= FirestoreExplorer(
        await firestore,
        documentIdsListerResolver: documentIdsListerResolver,
      );
  FirestoreExplorer? _firestoreExplorer;

  /// Browses the storage bucket of the project.
  ///
  /// The same explorer comes back on every call, so the directory it is in is
  /// kept between two menu items.
  Future<StorageExplorer> get storageExplorer async =>
      _storageExplorer ??= StorageExplorer(await bucket());
  StorageExplorer? _storageExplorer;
}
