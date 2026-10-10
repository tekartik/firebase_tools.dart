---
name: tekartik-firebase-tools-common-manager
description: >-
  Use when managing the Firebase projects of an account from dart (cli, menu,
  Flutter app, web) with tekartik_firebase_tools_common: FirebaseManagerClient
  listing the projects, their hosting sites, the hosting release storage
  setting (maxVersions, number of previous releases kept) and setting or
  limiting it for many projects at once, the hosting versions and their
  size, the hosting storage usage from cloud monitoring, and the access token
  providers (Firebase CLI login, gcloud, application default credentials, a
  custom token).
---

# Managing Firebase projects with tekartik_firebase_tools_common

`FirebaseManagerClient` calls the Google REST APIs (Firebase Management v1beta1,
Firebase Hosting v1beta1, Cloud Monitoring v3) with an OAuth access token. It
holds the projects; the hosting and the usage are extensions on it, so new
areas can be added the same way.

## Guidelines

* Import `package:tekartik_firebase_tools_common/firebase_manager.dart` in code
  that must run on the web (a Flutter app), and
  `package:tekartik_firebase_tools_common/firebase_manager_io.dart` for the io
  token providers. Nothing here bundles credentials.
* Pick a `GoogleAccessTokenProvider`:
  * `FirebaseCliAccessTokenProvider`: the account of `firebase login`, read
    from `~/.config/configstore/firebase-tools.json` (never written).
    `FIREBASE_TOKEN` takes precedence. Refreshing needs the OAuth client of
    the Firebase CLI, which the caller supplies (`clientId`,
    `clientSecret`, or `FIREBASE_CLIENT_ID` / `FIREBASE_CLIENT_SECRET`):
    without it only the cached CLI token works, for an hour at most.
  * `GcloudAccessTokenProvider()`: `gcloud auth print-access-token`;
    `GcloudAccessTokenProvider(applicationDefault: true)` uses the application
    default credentials and sends their quota project as
    `x-goog-user-project`, which the Firebase APIs require for user ADC.
  * `GoogleAccessTokenProvider.function(() async => token)` for anything
    else (a web sign-in, tests).
  * `googleAccessTokenProviderFromName('firebase' | 'gcloud' | 'adc')` maps a
    command line option.
* Errors come as `FirebaseRestException` (status code and the API message).
  A project without hosting or without the Monitoring API enabled fails on
  its own: catch per project when looping over many.
* `listProjects()` returns the active projects sorted by id
  (`FirebaseProjectInfo`, with `toJson`/`fromJson` to cache them).
  `listHostingSites(projectId)` puts the default site first.
* `FirebaseHostingSiteConfig.maxVersions` is the console "number of previous
  releases to keep": `null` means unlimited (the default of a new site). The
  versions past it are deleted on the next deploy, not right away.
  `setHostingSiteMaxVersions(site, n)` takes `n >= 1` and only touches that
  field (`updateMask=maxVersions`).
* `firebaseHostingProjectsMaxVersions(client, projectIds:)` reads every site of
  the projects (concurrently, results in `projectIds` order); with
  `maxVersions:` it sets them, `limit: true` only lowers the unlimited or
  greater values, `dryRun: true` reports without writing. Show a dry run and
  ask before writing to many projects. `firebaseHostingProjectsMaxVersionsLog`
  writes one line per site and a summary.
* `listHostingVersions(site)` lists every version, most recent first, deleted
  ones included: `FirebaseHostingVersionsSummary` counts and sums the
  finalized ones (the ones kept in storage). A site with an unlimited setting
  can have hundreds, which costs one call per hundred.
* `getHostingUsage(projectId)` returns the storage per site id from Cloud
  Monitoring (`firebasehosting.googleapis.com/storage/total_bytes`, measured a
  few times a day) and the bytes sent this month when reported (often not).

## Examples

### Limit every site of the account to 2 versions

```dart
import 'dart:io';

import 'package:tekartik_firebase_tools_common/firebase_manager_io.dart';

Future<void> main(List<String> args) async {
  var client = FirebaseManagerClient(
    tokenProvider: googleAccessTokenProviderFromName('gcloud'),
  );
  try {
    var projectIds = (await client.listProjects())
        .map((project) => project.projectId)
        .toList();
    // Without --apply, only show what would change.
    await firebaseHostingProjectsMaxVersionsLog(
      client,
      projectIds: projectIds,
      maxVersions: 2,
      limit: true,
      dryRun: !args.contains('--apply'),
      log: stdout.writeln,
    );
  } finally {
    client.close();
  }
}
```

### Sites, setting, versions and storage of one project

```dart
import 'package:tekartik_firebase_tools_common/firebase_manager.dart';

Future<void> dumpHosting(FirebaseManagerClient client, String projectId) async {
  var usage = await client.getHostingUsage(projectId);
  for (var site in await client.listHostingSites(projectId)) {
    var config = await client.getHostingSiteConfig(site);
    var versions = FirebaseHostingVersionsSummary(
      await client.listHostingVersions(site),
    );
    print(
      '$site kept: ${firebaseHostingMaxVersionsText(config.maxVersions)}, '
      'versions: ${versions.finalizedCount} '
      '(${versions.finalizedBytes} bytes), '
      'storage: ${usage[site.siteId]?.storageBytes ?? '?'} bytes',
    );
  }
}
```

### Web app with its own token

```dart
import 'package:tekartik_firebase_tools_common/firebase_manager.dart';

FirebaseManagerClient webClient(Future<String> Function() signInToken) =>
    FirebaseManagerClient(
      tokenProvider: GoogleAccessTokenProvider.function(
        signInToken,
        description: 'google sign-in',
      ),
    );
```
