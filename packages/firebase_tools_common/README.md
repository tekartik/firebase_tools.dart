# tekartik_firebase_tools_common

Firebase developer tools for dart, on the firebase abstractions only:

- the **emulator suite** of a firebase folder (starting it, querying its
  status) — the same api as `tekartik_firebase_emulator`;
- the **`firebase` cli deploy commands** of a firebase project (functions,
  firestore rules and indexes, storage rules, serve) — the firebase part of
  `tekartik_firebase_build`;
- an **explorer** for the auth users, the firestore database and the storage
  bucket of a project;
- the **`dev_build` console menus** built on top of all three.

Nothing here picks a firebase implementation, so nothing here can reach a real
project on its own. **[`tekartik_firebase_tools`](../firebase_tools) binds all
of this to the admin sdk and adds the main dev menu — that is the package to
depend on unless you are supplying your own implementation.**

Reading a project past its rules, and listing or creating its auth users, needs
privileged credentials. That belongs in a dev tool, never in an app.

## Setup

```yaml
dependencies:
  tekartik_firebase_tools_common:
    git:
      url: https://github.com/tekartik/firebase_tools.dart
      path: packages/firebase_tools_common
```

## Entry points

| Import | Holds |
| --- | --- |
| `package:tekartik_firebase_tools_common/firebase_tools_common.dart` | everything but the menus |
| `package:tekartik_firebase_tools_common/firebase_emulator.dart` | `FirebaseEmulatorService`, `FirebaseEmulator`, `FirebaseEmulatorOptions` |
| `package:tekartik_firebase_tools_common/firebase_project.dart` | `FirebaseProjectBuilder`, `FirebaseProjectOptions`, `firebaseFolderProjectId` |
| `package:tekartik_firebase_tools_common/firebase_explorer.dart` | `FirebaseToolsContext` and the three explorers, plus the path helpers |
| `package:tekartik_firebase_tools_common/menu.dart` | the `dev_build` menus |

## Exploring a project

A `FirebaseToolsContext` names the project and builds its services on first
use — declaring a menu over one costs no network call and no credential
lookup.

This package only knows how to build one over services you already have:

```dart
import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';

var context = FirebaseToolsContext.services(
  FirebaseToolsServices(
    firebaseApp: firebaseApp,
    authService: authService,
    firestoreService: firestoreService,
    storageService: storageService,
  ),
);
```

Reaching a real project is `tekartik_firebase_tools`'
`newFirebaseToolsContextAdminSdk(projectId: 'my_project')` and friends.

### Auth users

```dart
var auth = await context.authExplorer;
var user = await auth.findUserByEmail('alex@example.com');
for (var user in await auth.listUsers(maxResults: 100)) {
  print(firebaseUserText(user)); // alex@example.com (uid)
}
```

`listUsers` needs an implementation that can enumerate users; ask
`supportsListUsers` first, or catch the `StateError` it throws otherwise.

### Firestore

The explorer keeps a current path the way a shell keeps a current directory.
Paths alternate collection and document segments, so the root and every
document hold collections while every collection holds documents.

```dart
var firestore = await context.firestoreExplorer;
firestore.cd('app/my_app');           // relative, `/…` absolute, `..` up
var listing = await firestore.list(); // its sub collections
var document = await firestore.getDocument();
```

Entering a document that does not exist works and is the point: firestore
keeps a document id alive as soon as something hangs below it, so
`app/my_app` routinely has sub collections while the document itself was never
written. `getDocument` reports it with `exists` false and lists its
collections all the same.

Bringing those ids into a *collection* listing needs a `listDocuments` call,
which the tekartik abstraction does not cover — so it needs a
`FirestoreCollectionDocumentIdsLister`, passed either directly or through a
`FirestoreDocumentIdsListerResolver` on the context. `tekartik_firebase_tools`
supplies one backed by the admin sdk native instance; check
`supportsMissingDocuments` to know whether one is in place.

### Storage

A bucket stores flat file names that happen to contain `/`, so the directories
are inferred from those names — an empty one simply does not exist.

```dart
var storage = await context.storageExplorer;
storage.cd('image');

// One level deep: sub directories and the files directly in it.
var listing = await storage.list(filter: '*.png');
for (var entry in listing.entries) {
  print(entry.path);                     // full: image/thumb/a.png
  print(entry.relativeTo(storage.path)); // relative: thumb/a.png
}

// Or the flat, recursive view.
var files = await storage.listAll(filter: 'thumb');
```

A filter holding `*` or `?` is an anchored glob, any other filter is a
case-insensitive *contains*; both match names, not whole paths. The helpers
behind all of this are exported too and work on plain strings, no bucket
needed: `storagePathJoin`, `storagePathRelative`, `storagePathResolve`,
`storageNameMatchesFilter`, `storageDirectoryNamesFromPaths`, …

## Deploying a project

`FirebaseProjectBuilder` runs the `firebase` cli commands of one firebase
folder: `deployFunctions`, `deployFirestoreRules`, `deployFirestoreIndexes`,
`deployStorageRules`, `deploy` for everything, and `serve` for the emulators.

```dart
import 'package:tekartik_firebase_tools_common/firebase_project.dart';

var builder = FirebaseProjectBuilder(
  options: FirebaseProjectOptions.firebaseFolder(path: 'my_app_dartff'),
);
await builder.deployFunctions(functions: ['commanddartv2dev']);
```

The builder is a `CommonAppBuilder` of `tekartik_common_build`, so
`generateVersion` and `bumpVersion` apply to the firebase folder package.
Deploying or compiling the functions regenerates `lib/src/version.dart` first,
in the firebase folder package and in the functions package, for those that
have one — a bumped `pubspec.yaml` is never deployed with a stale version file.

## Menus

`menuFirebaseExplorerContent` declares the auth, firestore and storage
submenus over a context; `menuFirebaseEmulatorContent` and
`menuFirebaseProjectBuilderContent` do the same for the emulator and the
deploy commands. The three explorer submenus can also be declared on their own
(`menuFirebaseAuthExplorerContent`, `menuFirestoreExplorerContent`,
`menuStorageExplorerContent`), sharing a `FirebaseExplorerMenuState` so the
selected user and the name filter carry across them.

For the whole thing in one call, see `firebaseToolsMenuMain` in
`tekartik_firebase_tools`.

## Agent skills

The `skills/` folder holds the agent skills of this package, one per area:
`tekartik-firebase-tools-common-emulator`,
`tekartik-firebase-tools-common-deploy` and
`tekartik-firebase-tools-common-explorer`. `dart run skills@ get` installs the
skills of every dependency into `.agents/skills/`.
