---
name: tekartik-firebase-tools-common-explorer
description: >-
  Use when a dart dev tool must inspect or fix the data of a firebase project
  with tekartik_firebase_tools_common: FirebaseToolsContext over a firebase
  app, FirebaseAuthExplorer (find, list, create, delete auth users),
  FirestoreExplorer (cd, list, get, delete documents and sub collections,
  missing documents), StorageExplorer (list, read, write, delete bucket
  files), the firestorePath* and storagePath* helpers, and the dev_build
  explorer menus.
---

# Exploring a firebase project with tekartik_firebase_tools_common

A `FirebaseToolsContext` names a project and builds its auth, firestore and
storage on first use; its three explorers browse them the way a shell browses
directories. Everything works on the tekartik abstractions, so the same code
runs on the admin sdk (a real project) and on the in-memory implementations
(tests).

## Guidelines

* Import `package:tekartik_firebase_tools_common/firebase_explorer.dart`.
  This package only builds a context over services you already have,
  `FirebaseToolsContext.services(FirebaseToolsServices(firebaseApp:,
  authService:, firestoreService:, storageService:))`, or over a
  `servicesBuilder` callback. Reaching a real project is
  `newFirebaseToolsContextAdminSdk` and friends of `tekartik_firebase_tools`
  (its skill): client credentials can neither list users nor read past the
  rules.
* Declaring a context costs nothing: the app is built on the first
  `context.auth` / `firestore` / `storage` / `bucket()` / `*Explorer` access
  and kept, so a menu can be declared over it freely. `projectId` and
  `storageBucket` are what the tool reports; the credentials decide what is
  really reached.
* `context.authExplorer`: `findUserByEmail(email)` and `findUser(uid)`
  return `null` when unknown; `listUsers(maxResults:, pageToken:)` needs an
  implementation that can enumerate users, check `supportsListUsers` or
  catch its `StateError`; `createUserWithEmailAndPassword(email:, password:,
  displayName:)` and `deleteUser(uid)` need the admin api (`StateError`
  otherwise). `firebaseUserText(user)` formats a user as `email (uid)` for
  logs and menus.
* `context.firestoreExplorer` keeps a current `path` (`''` is the root) and
  is the same instance on every access. Paths alternate collection and
  document segments: the root and every document hold collections, every
  collection holds documents. `cd('app/x')` is relative, `cd('/app')`
  absolute, `..` goes up, `up()` too; `firestorePathResolve`,
  `firestorePathKind`, `firestorePathIsCollection`, `firestorePathParent`
  and `firestorePathId` are the pure helpers behind it.
* `list(path:, limit:)` returns a `FirestoreExplorerListing`: `collectionIds`
  for the root or a document, `documents` for a collection, `kind` telling
  which. `listCollectionIds([documentPath])`, `listDocuments([collectionPath,
  limit])`, `getDocument([documentPath])` and `deleteDocument([documentPath])`
  default to the current path. `getDocument` on a missing document works and
  reports `exists` false with its `collectionIds`: firestore keeps an id
  alive as soon as something hangs below it.
* Missing documents show up in a collection listing only when
  `supportsMissingDocuments` is true, i.e. when the context got a
  `documentIdsListerResolver` (`firestoreAdminSdkDocumentIdsLister` of
  `tekartik_firebase_tools`); otherwise only the existing documents are
  listed. Listing collections needs an implementation with
  `supportsListCollections` (admin sdk, sembast), else a `StateError`.
* Print what a destructive item is about to delete and prompt before doing
  it; a `deleteDocument` on a real project goes through privileged
  credentials and past the rules.
* `context.storageExplorer` browses `context.bucket()` (the default bucket,
  or `storageBucket`). Directories are inferred from the `/` of the file
  names, so an empty directory does not exist. `list(path:, filter:,
  maxResults:)` gives `directories` and `files` one level deep, `listAll` the
  flat recursive files; `entry.path` is the full name, `entry.relativeTo(dir)`
  the name under a directory, `entry.size` / `dateUpdated` / `contentType`
  come with the listing. `metadata`, `exists`, `readAsString`,
  `readAsBytes`, `writeAsString` and `delete` take a path relative to the
  current directory (`fullPath` resolves it).
* A filter holding `*` or `?` is an anchored glob, any other filter a
  case-insensitive contains; both match a name, never a whole path. The pure
  helpers are exported: `storagePathJoin`, `storagePathRelative`,
  `storagePathResolve`, `storageNameMatchesFilter`,
  `storageDirectoryNamesFromPaths`.
* Test a tool on the in-memory implementations (dev dependencies
  `tekartik_firebase_local`, `tekartik_firebase_auth_sembast`,
  `tekartik_firebase_firestore_sembast`, `tekartik_firebase_storage_fs`), see
  the example; keep the admin sdk out of `lib/`.
* Menus (`package:tekartik_firebase_tools_common/menu.dart`):
  `menuFirebaseExplorerContent(context:)` declares the `auth`, `firestore`
  and `storage` submenus; `menuFirebaseAuthExplorerContent`,
  `menuFirestoreExplorerContent` and `menuStorageExplorerContent` declare one
  each and share a `FirebaseExplorerMenuState` (the `user` selected by
  `find user by email`, the `storageFilter`, the listing `limit`, 100 by
  default) so the selected user carries across them. A prompt left empty
  cancels the item.

## Examples

### Script dumping the private items of a user

```dart
import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';

Future<void> dumpUserItems(FirebaseToolsContext context, String email) async {
  var auth = await context.authExplorer;
  var user = await auth.findUserByEmail(email);
  if (user == null) {
    throw StateError('no user $email');
  }
  var firestore = await context.firestoreExplorer;
  firestore.cd('/users/${user.uid}/items');
  for (var document in await firestore.listDocuments()) {
    print('${document.id}: ${document.data}');
  }
}
```

### Listing a bucket directory

```dart
Future<void> listImages(FirebaseToolsContext context) async {
  var storage = await context.storageExplorer;
  storage.cd('image');
  var listing = await storage.list(filter: '*.png');
  for (var directory in listing.directories) {
    print('${directory.relativeTo(storage.path)}/');
  }
  for (var file in listing.files) {
    print('${file.relativeTo(storage.path)} ${file.size} ${file.contentType}');
  }
}
```

### Test over the in-memory implementations

```dart
import 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_firebase_storage_fs/storage_fs.dart';
import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';
import 'package:test/test.dart';

FirebaseToolsContext newMemoryContext() {
  var firebaseApp = newFirebaseMemory().initializeApp(
    options: FirebaseAppOptions(projectId: 'test_project'),
  );
  return FirebaseToolsContext.services(
    FirebaseToolsServices(
      firebaseApp: firebaseApp,
      authService: newFirebaseAuthServiceMemory(),
      firestoreService: newFirestoreServiceMemory(),
      storageService: newStorageServiceMemory(),
    ),
  );
}

void main() {
  test('lists what the tool wrote', () async {
    var context = newMemoryContext();
    var firestore = await context.firestore;
    await firestore.doc('app/my_app/items/a').set({'name': 'a'});

    var explorer = await context.firestoreExplorer;
    explorer.cd('app/my_app/items');
    var listing = await explorer.list();
    expect(listing.documents.map((document) => document.id), ['a']);
  });
}
```
