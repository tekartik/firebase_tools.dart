## 0.1.4

- `FirestoreExporter` / `FirestoreExportOptions`: the `gcloud firestore
  export` and `import` of a project, to a dated folder of a cloud storage
  bucket, `<projectId>-backup` unless another is named.
  `menuFirestoreExportContent` declares them in a `dev_build` menu, and the
  command lines are built by `firestoreExportCommand` /
  `firestoreImportCommand`.
- `checkBucket` / `ensureBucket` / `databaseLocation` / `bucketLocation`:
  firestore only exports to a bucket in the location of the database, so the
  backup bucket is created there on first use and a mismatch is reported
  before the export rather than by `gcloud` after it
  (`firestoreExportLocationMatches`).
- `listExportNames` / `latestExportName` / `sizeOf` / `usageOf`: the exports
  already in the bucket, and the size and file count of one (`gcloud storage
  ls`, `gcloud storage du`), with `storageSizeText` for a readable byte count.
- `exportOperation` / `listExportOperations`: the document count and the state
  of an export, from `gcloud firestore operations list` — the bucket holds no
  record count.
- Agent skill `tekartik-firebase-tools-common-export`.

## 0.1.3

- `compileAndDeployFunctions` removed: `firebase deploy` compiles the dart
  functions itself (`dart pub get`, `build_runner`, `dart compile exe`), no
  compile step is needed before `deployFunctions`. `compileFunctions` stays as
  a local compilation check, documented as such.

## 0.1.2

- `FirebaseProjectBuilder` is a `CommonAppBuilder` of `tekartik_common_build`;
  `deployFunctions` and `compileFunctions` regenerate the generated
  `lib/src/version.dart` of the firebase folder package and of the functions
  package first (`generateFunctionsVersionIfNeeded`).
- Agent skills in `skills/`: emulator, deploy, explorer.

## 0.1.1

- `force` option (`firebase deploy --force`) on the `FirebaseProjectBuilder`
  deploy methods, `firebaseDeployCommand` helper.

## 0.1.0

- Initial version, aggregating `tekartik_firebase_emulator` and the firebase
  parts of `tekartik_firebase_build`, plus an explorer for auth users,
  firestore and storage on the firebase abstractions only.
