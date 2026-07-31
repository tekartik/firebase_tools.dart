/// The `dev_build` console menus of this package: driving the emulator suite,
/// deploying a firebase project, and exploring its auth users, firestore
/// database and storage bucket.
///
/// Declare them from a `mainMenuConsole` body, see
/// `package:dev_build/menu/menu_io.dart`.
library;

export 'src/emulator_menu.dart' show menuFirebaseEmulatorContent;
export 'src/explorer_menu.dart'
    show
        FirebaseExplorerMenuState,
        menuFirebaseExplorerContent,
        menuFirebaseAuthExplorerContent,
        menuFirestoreExplorerContent,
        menuStorageExplorerContent;
export 'src/firebase_project_menu.dart'
    show menuFirebaseProjectBuilderContent, menuFirebaseProjectContent;
