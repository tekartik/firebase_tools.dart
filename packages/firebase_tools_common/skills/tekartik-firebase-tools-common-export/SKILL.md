---
name: tekartik-firebase-tools-common-export
description: >-
  Use when exporting or backing up a firestore database to a cloud storage
  bucket, or importing one back, from a dart tool/ script or dev_build menu
  with tekartik_firebase_tools_common: FirestoreExporter and
  FirestoreExportOptions running gcloud firestore export / import, the
  destination bucket and dated folder of an export, creating that bucket in
  the location of the database (checkBucket, ensureBucket), exporting some
  collection groups only, a non default database, listing the exports already
  in the bucket and reporting their size, file count and document count,
  gs:// uri helpers, firestoreExportCommand.
---

# Exporting a firestore database with tekartik_firebase_tools_common

`FirestoreExporter` runs `gcloud firestore export` and `gcloud firestore
import` for one project. This is the *managed export* of the firestore admin
api, the one the console and the scheduled backups use: a consistent snapshot
in a format only firestore reads back, not a json dump. It is billed one read
per exported document.

## Guidelines

* Import `package:tekartik_firebase_tools_common/firestore_export.dart`. The
  `gcloud` cli must be installed and logged in (`gcloud auth login`) on an
  account allowed to export the project and to write to the bucket. Nothing
  here uses the admin sdk or the firebase cli, so it needs no
  `FirebaseToolsContext` — a project id is enough.
* Build the options once. `FirestoreExportOptions(projectId: 'my_project')`
  is all a whole-database export needs: the bucket defaults to
  `<projectId>-backup` (see `firestoreBackupBucket`) and the folder in it to
  `firestore-export`. `FirestoreExportOptions.firebaseFolder(path: 'deploy')`
  takes the project id from the folder's `.firebaserc` instead and throws a
  `StateError` when it has none. `copyWith` derives one set of options from
  another — it copies the *resolved* bucket, so pass a `bucket:` too when
  changing the `projectId`.
* **Firestore only exports to a bucket in the location of the database**, and
  the bucket of the app is usually not one: firebase creates it wherever the
  project was set up, so a `europe-west9` database next to a `us-west1`
  `<projectId>.firebasestorage.app` is the normal case and the export is
  refused outright. Hence the dedicated default bucket; only pass
  `bucket: firebaseDefaultStorageBucket(projectId)` when the locations are
  known to agree.
* Call `checkBucket()` before the first `export()` of a script or a menu
  item: it creates the bucket when it is missing, in the location of the
  database, and throws a `StateError` naming both locations when an existing
  bucket is in the wrong one — the same failure `gcloud` otherwise reports
  only after an export has been asked for. `ensureBucket()` only creates,
  `databaseLocation()` and `bucketLocation()` (null when the bucket does not
  exist) report each side, and `firestoreExportLocationMatches(bucketLocation:,
  databaseLocation:)` is the comparison on plain strings, multi regions (`eu`
  for `europe-*`, `us` for `us-*`) included.
* `bucketLocation:` in the options is where a *created* bucket goes, the
  location of the database by default; name a multi region (`eu`) to spread
  the backups of a regional database wider. An existing bucket is never
  moved. `bucketPath: ''` exports at the bucket root.
* `export()` writes to a *new dated sub folder* of
  `FirestoreExportOptions.uri` (`firestore-export/2026-09-22T10-30-00Z`, utc,
  see `firestoreExportName`) and returns its `gs://` uri: successive exports
  sit side by side and nothing is ever overwritten. Pass `name:` for a fixed
  folder instead, and keep the returned uri — it is what `importFrom` takes.
* `collectionIds` restricts an export to some collections, in the options for
  every export or per call. An id there is a collection *group*: `note`
  exports every `note` collection, at any depth. Null or empty exports the
  whole database.
* `export()` waits for the export to finish, which takes as long as the
  database is big. `async: true` returns as soon as the operation is started;
  follow it with `gcloud firestore operations list`. The exporter is verbose
  by default, since the command output is the only sign a long export lives.
* `importFrom(uri)` writes into the *live* database: every document of the
  export overwrites the one that has its id, and the documents that are not
  in the export are left alone. An import is never a rollback to the exported
  state — confirm it before running it, and prefer importing into a scratch
  project. `uri` is one export folder (the one holding
  `*.overall_export_metadata`), not the bucket root.
* `listExportNames()` gives the exports already in the bucket, sorted, and
  `latestExportName()` just the last one (`null` / empty when there is none,
  a missing bucket included). They are dates, so the latest sorts last;
  `exportUri(name)` turns one back into a `gs://` uri.
* `usageOf(uri)` is the file count and the total size in bytes of everything
  under a `gs://` uri — one export, or `options.uri` for every export at
  once; `sizeOf(uri)` is the total alone. They run `gcloud storage du`, which
  walks the object listing, so they take as long as there are objects; they
  read nothing from firestore and cost no read. `storageSizeText(bytes)`
  formats a size (`82.1 KiB`).
* **How many documents an export holds is not in the bucket**: an export
  writes a handful of opaque output files whatever the database holds, so
  `usageOf` counts files, never records. The document count is
  `exportOperation(uri)?.documentCount`, read from `gcloud firestore
  operations list`, along with `state` (`SUCCESSFUL`, `PROCESSING`, …) and
  `byteCount` (what firestore read out of the database, not the size in the
  bucket). Firestore keeps its operations for a while only, so
  `exportOperation` returns `null` for an old export: report it as unknown,
  not as zero. `listExportOperations()` gives them all.
* `database:` names a non default firestore database, on the options, for
  both directions.
* Command line helpers, for logs or a custom shell:
  `firestoreExportCommand(projectId:, uri:, collectionIds:, database:,
  async:)`, `firestoreImportCommand(...)`,
  `firestoreCollectionIdsArgument(ids)`, and `gsBucketUri(bucket, path)`
  which builds a `gs://` uri out of a bucket named with or without its
  scheme. `storageListCommand` / `storageSizeCommand` / `storageUsageCommand`
  / `firestoreOperationsListCommand` are the listing ones, with
  `storageListingNames`, `storageSizeFromDu`, `storageUsageFromDu` and
  `firestoreExportOperationsFromJson` parsing their output.
* In a `dev_build` menu, `menuFirestoreExportContent(exporter:)`
  (`package:tekartik_firebase_tools_common/menu.dart`) declares `bucket`,
  `create bucket`, `export`, `export collections`, `export async`, `last
  export uri`, `list exports`, `latest export size` and a confirmed
  `import`; every export calls `checkBucket()` first, and it remembers the
  last export of the session so the import needs no uri. It is the `export` submenu of the main menu of
  `tekartik_firebase_tools`.

## Examples

### Backup script

```dart
import 'dart:io';

import 'package:tekartik_firebase_tools_common/firestore_export.dart';

final exporter = FirestoreExporter(
  options: FirestoreExportOptions(projectId: 'my_project'),
);

Future<void> main(List<String> args) async {
  // Creates gs://my_project-backup in the location of the database the first
  // time, and refuses an existing bucket in the wrong one.
  await exporter.checkBucket();
  // gs://my_project-backup/firestore-export/2026-09-22T10-30-00Z
  var uri = await exporter.export(collectionIds: args);
  stdout.writeln('Exported to $uri');
}
```

### A dedicated bucket, some collections only

```dart
import 'package:tekartik_firebase_tools_common/firestore_export.dart';

final exporter = FirestoreExporter(
  options: FirestoreExportOptions(
    projectId: 'my_project',
    bucket: 'my-project-backup',
    bucketPath: '',
    // Created as a multi region rather than in the region of the database.
    bucketLocation: 'eu',
    collectionIds: ['note', 'user'],
  ),
);

Future<void> exportNotes() async {
  await exporter.checkBucket();
  // gs://my-project-backup/2026-09-22T10-30-00Z, the note and user
  // collection groups only, without waiting for it to finish.
  await exporter.export(async: true);
}
```

### Size, files and documents of the latest export

```dart
import 'dart:io';

import 'package:tekartik_firebase_tools_common/firestore_export.dart';

Future<void> main() async {
  var exporter = FirestoreExporter(
    options: FirestoreExportOptions(projectId: 'my_project'),
  );
  var name = await exporter.latestExportName();
  if (name == null) {
    stdout.writeln('No export yet in ${exporter.options.uri}');
    return;
  }
  var uri = exporter.exportUri(name);
  var usage = await exporter.usageOf(uri);
  stdout.writeln(uri);
  stdout.writeln('${usage.size} bytes (${storageSizeText(usage.size)})');
  stdout.writeln('${usage.fileCount} file(s)');
  // Not in the bucket: firestore remembers it, for a while.
  var operation = await exporter.exportOperation(uri);
  stdout.writeln('${operation?.documentCount ?? '<unknown>'} document(s)');
}
```

### Copying a project into a scratch one

```dart
import 'package:tekartik_firebase_tools_common/firestore_export.dart';

Future<void> main() async {
  var options = FirestoreExportOptions(
    projectId: 'my-app-prod',
    bucket: 'my-app-backup',
  );
  var prod = FirestoreExporter(options: options);
  await prod.checkBucket();
  var uri = await prod.export();

  // Same bucket, the dev project reading it back.
  var dev = FirestoreExporter(
    options: options.copyWith(
      projectId: 'my-app-dev',
      bucket: 'my-app-backup',
    ),
  );
  await dev.importFrom(uri);
}
```

### Menu over the export

```dart
import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_firebase_tools_common/firestore_export.dart';
import 'package:tekartik_firebase_tools_common/menu.dart';

Future<void> main(List<String> arguments) async {
  mainMenuConsole(arguments, () {
    menu('export', () {
      menuFirestoreExportContent(
        exporter: FirestoreExporter(
          options: FirestoreExportOptions(projectId: 'my_project'),
        ),
      );
    });
  });
}
```
