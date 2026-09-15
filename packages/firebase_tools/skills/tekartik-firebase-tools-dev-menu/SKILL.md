---
name: tekartik-firebase-tools-dev-menu
description: >-
  Use when writing a dart dev tool (tool/ script or dev_build console menu)
  over a real firebase project with tekartik_firebase_tools: the one-call main
  menu (firebaseToolsMenuMain, menuFirebaseToolsContent) with its emulator,
  deploy and explorer submenus, and reaching a project through the admin sdk
  with ambient credentials, a service account or a firebase folder
  (newFirebaseToolsContextAdminSdk, newFirebaseToolsContextServiceAccountMap,
  newFirebaseToolsContextFirebaseFolder) to list auth users, browse firestore
  past the rules or browse a storage bucket.
---

# Firebase dev tools with tekartik_firebase_tools

`tekartik_firebase_tools` is the package a firebase dev tool depends on: it
re-exports the whole of `tekartik_firebase_tools_common` (emulator suite,
`firebase` cli deploy commands, auth/firestore/storage explorer and their
`dev_build` menus) and binds it to the admin sdk, which reaches a real project
with full privileges.

## Guidelines

* Add it as a `dev_dependency` of the package holding the `tool/` scripts
  (git `https://github.com/tekartik/firebase_tools.dart`, path
  `packages/firebase_tools`), never as a dependency of an app: the admin sdk
  reads and creates auth users and bypasses the firestore rules. Import
  `package:tekartik_firebase_tools/menu.dart` for menus and
  `package:tekartik_firebase_tools/firebase_tools.dart` for scripts.
* A complete tool is one line: `firebaseToolsMenuMain(arguments, path:
  'deploy')` runs a `dev_build` console with the `emulator`, `project` and
  `explore` submenus of the firebase folder at `path` (the one holding
  `firebase.json`), the project id read from its `.firebaserc`.
  `menuFirebaseToolsContent(...)` declares the same inside a
  `mainMenuConsole` of your own, next to app specific items.
* Both take `projectId` to act on another project than the `.firebaserc`
  one, `context` to decide the credentials yourself, `emulatorOptions` /
  `projectOptions` to configure the emulator and deploy submenus, and
  `withEmulator` / `withProject` / `withExplorer: false` to drop a submenu.
  Without a firebase folder, drop the emulator and project submenus or call
  `menuFirebaseExplorerContent(context:)` directly.
* Reaching a project: `newFirebaseToolsContextAdminSdk(projectId:)` uses the
  ambient credentials (`gcloud auth application-default login`, or the
  service account of the machine). With no `projectId` at all the
  environment decides (`GOOGLE_CLOUD_PROJECT`, the credentials themselves):
  only for a tool that is explicitly environment driven.
  `newFirebaseToolsContextFirebaseFolder(path:)` takes the project id from
  the folder's `.firebaserc` and throws a `StateError` when it has none.
  `newFirebaseToolsContextServiceAccountMap(jsonDecode(json))` uses a service
  account json checked into a private repo, its `project_id` by default.
  `storageBucket:` overrides the default bucket on all three.
* All three build the app on first use, so declaring a menu costs no
  credential lookup, and all three wire `firestoreAdminSdkDocumentIdsLister`,
  so a firestore collection listing includes the documents that do not exist
  but hold sub collections (`FirestoreExplorerDocument.exists` false). Pass
  it as `documentIdsListerResolver` when building a `FirebaseToolsContext` by
  hand over the admin sdk.
* Dev and prod are two contexts: name each menu after its project and never
  pick the project from an environment variable silently.
* What to do with a context (`authExplorer`, `firestoreExplorer`,
  `storageExplorer`, the path helpers, the explorer menus) is the api of the
  common package, see its `tekartik-firebase-tools-common-explorer` skill;
  the emulator and deploy parts have theirs too.
* Tests run on the in-memory implementations through
  `FirebaseToolsContext.services`, no admin sdk needed; keep the admin sdk
  code in `tool/`, out of `lib/`.
* At run time the tool needs the `firebase` cli (deploy, emulators) and
  either `gcloud auth application-default login` or
  `GOOGLE_APPLICATION_CREDENTIALS` for the explorer.

## Examples

### tool/firebase_menu.dart

```dart
import 'package:tekartik_firebase_tools/menu.dart';

Future<void> main(List<String> arguments) =>
    firebaseToolsMenuMain(arguments, path: 'deploy');
```

### Custom menu with dev and prod

```dart
import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_firebase_tools/firebase_tools.dart';
import 'package:tekartik_firebase_tools/menu.dart';

Future<void> main(List<String> arguments) async {
  mainMenuConsole(arguments, () {
    menu('dev', () {
      menuFirebaseToolsContent(path: 'deploy', projectId: 'my-app-dev');
    });
    menu('prod', () {
      // Explorer only: no emulator and no deploy from here.
      menuFirebaseExplorerContent(
        context: newFirebaseToolsContextAdminSdk(projectId: 'my-app-prod'),
      );
    });
  });
}
```

### Script inspecting a user

```dart
import 'package:tekartik_firebase_tools/firebase_tools.dart';

Future<void> main() async {
  var context = newFirebaseToolsContextFirebaseFolder(path: 'deploy');
  var auth = await context.authExplorer;
  var user = await auth.findUserByEmail('someone@example.com');
  if (user == null) {
    print('unknown user');
    return;
  }
  print(firebaseUserText(user));
  var firestore = await context.firestoreExplorer;
  print(await firestore.list(path: '/users/${user.uid}'));
}
```
