/// Firebase developer tools bound to the admin sdk: the emulator suite, the
/// `firebase` cli deploy commands, and an explorer for the auth users, the
/// firestore database and the storage bucket of a project.
///
/// Re-exports the whole `tekartik_firebase_tools_common` api and adds what
/// needs the admin sdk, i.e. building a context that reaches a real project
/// (`newFirebaseToolsContextAdminSdk` and friends) and listing the firestore
/// documents that do not exist but hold sub collections.
///
/// See `menu.dart` for the console menus, the main entry point included.
library;

export 'package:tekartik_firebase_tools_common/firebase_tools_common.dart';

export 'src/firebase_admin_sdk_context.dart'
    show
        newFirebaseToolsContextAdminSdk,
        newFirebaseToolsContextServiceAccountMap,
        newFirebaseToolsContextFirebaseFolder,
        firestoreAdminSdkDocumentIdsLister;
