/// Exporting the firestore database of a project to a cloud storage bucket,
/// and importing it back, through the `gcloud` cli.
///
/// Start from a [FirestoreExporter] over a [FirestoreExportOptions]. This is
/// the managed export of the firestore admin api, so it needs the `gcloud` cli
/// logged in, not the admin sdk. See `menu.dart` for the console menu built on
/// top of it.
library;

export 'src/firestore_export.dart'
    show
        FirestoreExportOperation,
        FirestoreExportOptions,
        FirestoreExporter,
        FirestoreExporterExt,
        StorageUsage,
        firebaseDefaultStorageBucket,
        firestoreBackupBucket,
        firestoreCollectionIdsArgument,
        firestoreDatabaseLocationCommand,
        firestoreExportCommand,
        firestoreExportLocationMatches,
        firestoreExportName,
        firestoreExportOperationsFromJson,
        firestoreImportCommand,
        firestoreOperationsListCommand,
        gsBucketUri,
        storageBucketCreateCommand,
        storageBucketLocationCommand,
        storageListCommand,
        storageListingNames,
        storageSizeCommand,
        storageSizeFromDu,
        storageSizeText,
        storageUsageCommand,
        storageUsageFromDu;
