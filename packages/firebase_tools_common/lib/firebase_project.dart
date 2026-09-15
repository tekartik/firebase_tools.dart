/// Driving the `firebase` cli for one firebase project folder: deploying
/// functions, firestore rules/indexes, storage rules, and serving emulators.
///
/// [FirebaseProjectBuilder] is a `CommonAppBuilder` of `tekartik_common_build`,
/// re-exported here with its `CommonAppBuilderExt` so the version helpers
/// (`generateVersion`, `bumpVersion`) are at hand from this import alone.
library;

export 'package:tekartik_common_build/common_app_builder.dart'
    show CommonAppBuilder, CommonAppBuilderExt;

export 'src/firebase_project.dart'
    show
        FirebaseProjectOptions,
        FirebaseProjectBuilder,
        FirebaseProjectActionController,
        firebaseDeployCommand,
        firebaseFunctionsDeployOnly,
        firebaseFolderProjectId,
        firebaseRcContentProjectId;
