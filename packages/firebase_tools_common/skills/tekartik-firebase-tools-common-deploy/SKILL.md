---
name: tekartik-firebase-tools-common-deploy
description: >-
  Use when deploying a firebase project from a dart tool/ script or dev_build
  menu with tekartik_firebase_tools_common: FirebaseProjectBuilder and
  FirebaseProjectOptions running firebase deploy (cloud functions, firestore
  rules and indexes, storage rules, everything), compiling dart cloud
  functions, regenerating the version file before a deploy, cancelling a
  deploy, reading the project id of a .firebaserc, firebaseDeployCommand.
---

# Deploying a firebase project with tekartik_firebase_tools_common

`FirebaseProjectBuilder` runs the `firebase` cli in one firebase folder (the
one holding `firebase.json`) for the project its `FirebaseProjectOptions`
name. It is the firebase part of `tekartik_firebase_build` (the
`FirebaseProjectBuilder` of `app_build` subclasses it) and
`tekartik_firebase_tools` re-exports it.

## Guidelines

* Import `package:tekartik_firebase_tools_common/firebase_project.dart`. The
  firebase cli must be installed and logged in (`firebase login`); nothing
  here uses the admin sdk.
* Build the options once. `FirebaseProjectOptions.firebaseFolder(path:
  'deploy', functions: [...])` reads the `default` project id of the folder's
  `.firebaserc` and throws a `StateError` when `firebase.json`, `.firebaserc`
  or the default project is missing, which beats deploying to the wrong
  project. `FirebaseProjectOptions(projectId:, path:)` names the project
  explicitly; `path` defaults to the current directory and is made absolute.
  `copyWith` derives the prod options from the dev ones.
* `functions` is the default list of function names `deployFunctions` sends
  (`--only functions:a,functions:b`); `null` or empty deploys every function
  of the codebase. A per-call `functions:` argument overrides it. Deploy a
  named subset when one project holds the functions of several environments
  (`commanddartv2dev` next to `commanddartv2prod`).
* Deploy methods: `deployFunctions`, `deployFirestoreRules`,
  `deployFirestoreIndexes`, `deployFirestore` (rules and indexes),
  `deployStorageRules`, `deployOnly('hosting,firestore:rules')` and `deploy()`
  (everything of `firebase.json`). Each takes `force: true` to add `--force`,
  which deletes the functions or indexes no longer in the source and skips
  the runtime upgrade prompts without asking: use it in non-interactive
  scripts and CI, not by default in a menu.
* Every deploy method and `serve` takes a `controller:`
  (`FirebaseProjectActionController`); `controller.cancel()` kills the
  running `firebase` command, which is how a menu offers a `cancel action`
  item. One controller serves every item: cancel before starting a new
  action.
* Dart cloud functions (`*_dartff` layout: the firebase folder is a dart
  package and `functions/bin/server.dart` the entry point of the functions
  package): `compileFunctions()` runs `dart compile exe` in
  `functionsSourcePath` for `functionsTargetOs` / `functionsTargetArch`
  (linux x64 by default) and `compileAndDeployFunctions()` chains both, for
  a deploy that ships the executable. Override `functionsSource`,
  `functionsEntryPoint`, `functionsTargetOs` and `functionsTargetArch` in
  the options when the layout differs.
* Versions: the builder is a `CommonAppBuilder` of `tekartik_common_build`
  (re-exported with `CommonAppBuilderExt`), so `generateVersion()`,
  `generateVersionIfNeeded()` and `bumpVersion(patch: true)` act on the
  firebase folder package. `deployFunctions` and `compileFunctions` call
  `generateFunctionsVersionIfNeeded()` first: the `lib/src/version.dart` of
  the firebase folder package and of the functions package are rewritten from
  their `pubspec.yaml` version when they exist and left alone otherwise. Opt
  a package in by generating the file once (`generateVersion(path:, force:
  true)` of `package:tekartik_common_build/version_io.dart`) and committing
  it.
* `serve(only: 'functions,firestore')` runs `firebase emulators:start` in
  the folder and returns when it exits; prefer `FirebaseEmulatorService`
  (see the emulator skill) when the script needs to know when the emulators
  are ready or whether they already run.
* Command line helpers, for logs or a custom shell:
  `firebaseDeployCommand(projectId:, only:, force:)`,
  `firebaseFunctionsDeployOnly(names)`, `firebaseFolderProjectId(path:)`,
  `firebaseRcContentProjectId(json)`.
* In a `dev_build` menu, `menuFirebaseProjectBuilderContent(builder:)`
  (`package:tekartik_firebase_tools_common/menu.dart`) declares `serve
  emulators`, `deploy functions`, `deploy firestore rules`, `deploy firestore
  indexes`, `deploy storage rules`, `deploy all` and `cancel action`;
  `menuFirebaseProjectContent(builders: [...])` makes one submenu per project
  (dev, prod) when given several builders.

## Examples

### Deploy script of a dartff project

```dart
import 'package:tekartik_firebase_tools_common/firebase_project.dart';

final devBuilder = FirebaseProjectBuilder(
  options: FirebaseProjectOptions.firebaseFolder(
    path: 'my_app_dartff',
    functions: ['commanddartv2dev', 'callcommanddartv2dev'],
  ),
);
final prodBuilder = FirebaseProjectBuilder(
  options: devBuilder.options.copyWith(
    projectId: 'my-app-prod',
    functions: ['commanddartv2prod', 'callcommanddartv2prod'],
  ),
);

Future<void> main() async {
  // The version files are regenerated first, then the dev functions go up.
  await devBuilder.deployFunctions();
  // Rules and indexes of both projects, no prompt for the removed indexes.
  for (var builder in [devBuilder, prodBuilder]) {
    await builder.deployFirestore(force: true);
  }
}
```

### Menu over dev and prod

```dart
import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_firebase_tools_common/menu.dart';

Future<void> main(List<String> arguments) async {
  mainMenuConsole(arguments, () {
    menuFirebaseProjectContent(builders: [devBuilder, prodBuilder]);
  });
}
```

### Cancellable deploy from a custom item

```dart
var controller = FirebaseProjectActionController();
item('deploy functions', () async {
  controller.cancel(); // whatever was still running
  await devBuilder.deployFunctions(controller: controller);
});
item('cancel', () async {
  controller.cancel();
});
```
