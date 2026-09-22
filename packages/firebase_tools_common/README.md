# tekartik_firebase_tools_common

Firebase developer tools for dart, on the firebase abstractions only:

- the **emulator suite** of a firebase folder (starting it, querying its
  status) — the same api as `tekartik_firebase_emulator`;
- the **`firebase` cli deploy commands** of a firebase project (functions,
  firestore rules and indexes, storage rules, serve) — the firebase part of
  `tekartik_firebase_build`;
- an **explorer** for the auth users, the firestore database and the storage
  bucket of a project;
- the **`gcloud firestore export`** of a project, to a cloud storage bucket,
  and the import back;
- the **`dev_build` console menus** built on top of all four.

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
| `package:tekartik_firebase_tools_common/firestore_export.dart` | `FirestoreExporter`, `FirestoreExportOptions` |
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

## Exporting a firestore database

`FirestoreExporter` runs the `gcloud firestore export` and `gcloud firestore
import` of one project — the managed export of the firestore admin api, a
consistent snapshot only firestore reads back, billed one read per exported
document. It needs the `gcloud` cli logged in, not the admin sdk.

```dart
import 'package:tekartik_firebase_tools_common/firestore_export.dart';

var exporter = FirestoreExporter(
  options: FirestoreExportOptions(projectId: 'my_project'),
);
// gs://my_project-backup/firestore-export/2026-09-22T10-30-00Z
var uri = await exporter.export();
```

The bucket defaults to `<projectId>-backup` and the folder in it to
`firestore-export`; `bucket:` and `bucketPath:` name another one. Each export
goes in a new dated sub folder, so nothing is ever overwritten, and `export`
returns its uri — the one `importFrom` takes back.

**Firestore only exports to a bucket in the location of the database**, which
the bucket of the app usually is not: firebase creates it wherever the project
was set up, so a `europe-west9` database and a `us-west1` app bucket is the
normal case, and the export is refused. Hence a bucket of its own, and
`checkBucket()`:

```dart
// Creates gs://my_project-backup in the location of the database when it is
// missing, and throws when an existing bucket is in the wrong one.
await exporter.checkBucket();
var uri = await exporter.export();
```

`databaseLocation()` and `bucketLocation()` (null when the bucket does not
exist) report each side, `ensureBucket()` only creates, and
`bucketLocation:` in the options overrides the location a created bucket goes
in — a multi region (`eu`) to spread the backups of a regional database wider.

### What is already in the bucket

Exports are named after their date, so sorting them puts the latest last:

```dart
var names = await exporter.listExportNames(); // empty when there is none
var name = await exporter.latestExportName(); // or just the last one
if (name != null) {
  var uri = exporter.exportUri(name);
  var usage = await exporter.usageOf(uri); // file count and total size
  print('$uri: ${usage.fileCount} file(s), '
      '${usage.size} bytes (${storageSizeText(usage.size)})');
}
```

`usageOf` and `sizeOf` (the total alone) work on any `gs://` uri, so the whole
export folder (`options.uri`) is a bucket total. They walk the object listing,
so they take as long as there are objects under the uri, and they read nothing
from firestore — no billed read.

**How many documents an export holds is not in the bucket**: an export writes
a handful of opaque output files whatever the database holds. That count lives
in the firestore export operation:

```dart
var operation = await exporter.exportOperation(uri);
// null when firestore no longer lists that export
print(operation?.documentCount); // 201
print(operation?.state);         // SUCCESSFUL
```

Firestore only keeps its operations for a while, so an old export legitimately
has none — report it as unknown rather than as zero.
`listExportOperations()` gives them all.

`collectionIds:` restricts an export to some collection groups, `async: true`
returns as soon as the operation is started rather than waiting for it, and
`FirestoreExportOptions.firebaseFolder(path:)` reads the project id from a
`.firebaserc`. An import writes into the live database: every exported
document overwrites the one that has its id, and what is not in the export is
left alone — it is never a rollback.

## Menus

`menuFirebaseExplorerContent` declares the auth, firestore and storage
submenus over a context; `menuFirebaseEmulatorContent`,
`menuFirebaseProjectBuilderContent` and `menuFirestoreExportContent` do the
same for the emulator, the deploy commands and the export. The three explorer
submenus can also be declared on their own
(`menuFirebaseAuthExplorerContent`, `menuFirestoreExplorerContent`,
`menuStorageExplorerContent`), sharing a `FirebaseExplorerMenuState` so the
selected user and the name filter carry across them.

For the whole thing in one call, see `firebaseToolsMenuMain` in
`tekartik_firebase_tools`.

## Agent skills

The `skills/` folder holds the agent skills of this package, one per area:
`tekartik-firebase-tools-common-emulator`,
`tekartik-firebase-tools-common-deploy`,
`tekartik-firebase-tools-common-explorer` and
`tekartik-firebase-tools-common-export`. `dart run skills@ get` installs the
skills of every dependency into `.agents/skills/`.
