/// Driving the `firebase` cli for one firebase project folder: deploying
/// functions, firestore rules/indexes, storage rules, and serving emulators.
library;

export 'src/firebase_project.dart'
    show
        FirebaseProjectOptions,
        FirebaseProjectBuilder,
        FirebaseProjectActionController,
        firebaseFunctionsDeployOnly,
        firebaseFolderProjectId,
        firebaseRcContentProjectId;
