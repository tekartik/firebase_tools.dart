/// Managing Firebase projects through the Google REST APIs: the projects
/// (Firebase Management), the hosting sites (configuration, versions,
/// number of versions kept) and their usage (Cloud Monitoring).
///
/// Works on the web too. The credentials come from a
/// [GoogleAccessTokenProvider], the io ones (Firebase CLI login, gcloud) are
/// in `firebase_manager_io.dart`.
library;

import 'src/firebase_manager/google_access_token.dart';

export 'src/firebase_manager/firebase_hosting_api.dart'
    show
        FirebaseHostingSiteInfo,
        FirebaseHostingSiteConfig,
        FirebaseHostingVersionInfo,
        FirebaseHostingVersionsSummary,
        FirebaseManagerClientHostingExt,
        firebaseHostingMaxVersionsText;
export 'src/firebase_manager/firebase_hosting_max_versions.dart'
    show
        FirebaseHostingSiteMaxVersions,
        firebaseHostingMaxVersionsTarget,
        firebaseHostingProjectsMaxVersions,
        firebaseHostingProjectsMaxVersionsLog,
        firebaseHostingMaxVersionsSummary;
export 'src/firebase_manager/firebase_manager_client.dart'
    show FirebaseManagerClient, FirebaseProjectInfo, FirebaseRestException;
export 'src/firebase_manager/firebase_usage_api.dart'
    show FirebaseHostingSiteUsage, FirebaseManagerClientUsageExt;
export 'src/firebase_manager/google_access_token.dart'
    show GoogleAccessTokenProvider, GoogleAccessToken;
