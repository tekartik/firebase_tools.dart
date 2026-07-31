/// Exploring a firebase project from a dev tool: its auth users, its firestore
/// database and its storage bucket.
///
/// Start from a [FirebaseToolsContext] and take its explorers. Building one
/// needs privileged credentials, i.e. the admin sdk in practice — see
/// `newFirebaseToolsContextAdminSdk` in `tekartik_firebase_tools`. See
/// `menu.dart` for the console menus built on top of the explorers.
library;

export 'src/auth_explorer.dart' show FirebaseAuthExplorer, firebaseUserText;
export 'src/firebase_context.dart'
    show FirebaseToolsContext, FirebaseToolsServices;
export 'src/firestore_explorer.dart'
    show
        FirestoreExplorer,
        FirestoreExplorerDocument,
        FirestoreExplorerListing,
        FirestoreCollectionDocumentIdsLister,
        FirestoreDocumentIdsListerResolver;
export 'src/firestore_path.dart'
    show
        FirestorePathKind,
        firestorePathParts,
        firestorePathNormalize,
        firestorePathKind,
        firestorePathIsCollection,
        firestorePathIsDocument,
        firestorePathIsRoot,
        firestorePathId,
        firestorePathParent,
        firestorePathJoin,
        firestorePathResolve;
export 'src/storage_explorer.dart'
    show StorageExplorer, StorageExplorerEntry, StorageExplorerListing;
export 'src/storage_path.dart'
    show
        StorageDirectoryNames,
        storagePathParts,
        storagePathNormalize,
        storagePathJoin,
        storagePathName,
        storagePathParent,
        storagePathPrefix,
        storagePathIsWithin,
        storagePathRelative,
        storagePathResolve,
        storageNameMatchesFilter,
        storageDirectoryNamesFromPaths;
