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
