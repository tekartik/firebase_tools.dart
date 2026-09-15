---
name: tekartik-firebase-tools-common-emulator
description: >-
  Use when starting, checking or stopping the Firebase emulator suite (auth,
  firestore, storage, functions, pubsub) of a firebase folder from a dart
  tool/ script, a test or a dev_build menu with tekartik_firebase_tools_common:
  FirebaseEmulatorService, FirebaseEmulatorOptions, EmulatorServiceStatus,
  FirebaseEmulator, menuFirebaseEmulatorContent, and skipping tests when the
  emulators are not running.
---

# Firebase emulators from dart with tekartik_firebase_tools_common

`FirebaseEmulatorService` drives `firebase emulators:start` for one firebase
folder (the one holding `firebase.json`) and queries the emulator hub to tell
whether emulators are already running. It is the api of
`tekartik_firebase_emulator`, aggregated here; `tekartik_firebase_tools`
re-exports it.

## Guidelines

* Import `package:tekartik_firebase_tools_common/firebase_emulator.dart` (or
  `firebase_tools_common.dart` for the whole api). In an app, add the package
  as a `dev_dependency`: it serves `tool/` scripts and tests, and pulls
  `dev_build`, `process_run` and the firebase abstractions.
* Build one `FirebaseEmulatorService(path: 'emulator')` per firebase folder.
  The folder needs a `firebase.json` and a `.firebaserc`: without the
  `.firebaserc` the service reports `EmulatorServiceNotSupportedStatus` and
  `start` throws an `UnsupportedError`, even when `projectId` is given. An
  emulator-only folder uses a `demo-` project id
  (`{"projects": {"default": "demo-my-app"}}`), which needs no credentials;
  when the repository does not commit `.firebaserc`, let the script write it
  from the shared project id constant before building the service.
* `isSupported()` / `checkStatus()` also require the firebase cli
  (`npm install -g firebase-tools`) 15.14+ on the path and, when
  `functions/package.json` exists, node 20+, firebase-admin 13.8+ and
  firebase-functions 7.2.5+. The reason of a failure is not reported, so a
  script that gets `false` should print what is needed (cli, `.firebaserc`).
* `start(options:)` runs `firebase --project <id> emulators:start [--only
  ...]` in the folder and returns once the cli prints `All emulators ready`
  (180 s timeout by default; pass `timeout:` for slow dart functions). If an
  emulator hub already answers on `localhost:4400` with every requested
  service, nothing is started and a `FirebaseRunningEmulator` comes back,
  whose `stop()` is a no-op: test `emulator is FirebaseRunningEmulator` when
  the script must report it. If the running hub lacks a requested service,
  `start` throws an `UnsupportedError`.
* `FirebaseEmulatorOptions`: `projectId` (else read from `.firebaserc` through
  `firebase -j use`, slower), `onlyAuth` / `onlyFirestore` / `onlyStorage` /
  `onlyFunctions` / `onlyPubsub` (combine them for `--only auth,firestore`;
  none means every emulator of `firebase.json`), `debug` (`--debug`),
  `persistPath` (`--import <path> --export-on-exit <path>`, keeps the data
  between runs), `processStartMode`. `copyWith` derives a variant.
* Always `await emulator.stop()` (sigint, then waits for the process) in a
  `tearDownAll` or before the script exits. A script that must stay up awaits
  `ProcessSignal.sigint.watch().first` then stops it; from a terminal Ctrl+C
  also reaches the `firebase` child, `stop()` then just waits for it.
* `checkStatus()` returns an `EmulatorServiceStatus`: `running` and
  `supported`, and for an `EmulatorServiceRunningStatus` the `authPort`,
  `firestorePort`, `storagePort`, `functionsPort` and `pubsubPort` actually
  served (`null` when that emulator is not up). Use it to skip a test suite
  rather than fail it when the emulators are down, or to pick the ports the
  client connects to. `checkStatus(force: true)` re-runs the setup checks,
  `verbose: true` prints the hub answer.
* In a `dev_build` menu, `menuFirebaseEmulatorContent(service:, options:)`
  (`package:tekartik_firebase_tools_common/menu.dart`) declares `status`,
  `project id`, `start`, `start auth only` / `firestore only` /
  `storage only` / `functions only` and `stop`; leaving the menu stops what
  it started.
* The ports are the ones of `firebase.json`; keep the client side (host,
  ports, project id) in one pure dart file shared by the app, the tests and
  the scripts rather than repeating the literals.

## Examples

### tool/start_emulator.dart

```dart
import 'dart:io';

import 'package:tekartik_firebase_tools_common/firebase_emulator.dart';

/// Starts the auth and firestore emulators of `emulator/` (Ctrl+C to stop).
Future<void> main() async {
  var service = FirebaseEmulatorService(path: 'emulator');
  if (!await service.isSupported()) {
    stderr.writeln(
      'firebase emulator not supported: needs the firebase cli 15.14+'
      ' and emulator/.firebaserc',
    );
    exit(1);
  }
  var emulator = await service.start(
    options: FirebaseEmulatorOptions(
      projectId: 'demo-my-app',
      onlyAuth: true,
      onlyFirestore: true,
    ),
  );
  if (emulator is FirebaseRunningEmulator) {
    stdout.writeln('emulators already running');
    return;
  }
  stdout.writeln('emulators ready, UI at http://localhost:4000, Ctrl+C to stop');
  await ProcessSignal.sigint.watch().first;
  await emulator.stop();
}
```

### Test skipped when the emulators are down

```dart
@TestOn('vm')
library;

import 'package:tekartik_firebase_tools_common/firebase_emulator.dart';
import 'package:test/test.dart';

Future<void> main() async {
  var status = await FirebaseEmulatorService(path: 'emulator').checkStatus();
  if (status is! EmulatorServiceRunningStatus || status.authPort == null) {
    test(
      'auth emulator',
      () {},
      skip: 'start it with `dart run tool/start_emulator.dart`',
    );
    return;
  }
  test('signs in on the emulator', () async {
    // Point the auth client at localhost:${status.authPort}.
  });
}
```

### Test suite starting its own emulator

```dart
late FirebaseEmulator emulator;

setUpAll(() async {
  emulator = await FirebaseEmulatorService(path: 'emulator').start(
    options: FirebaseEmulatorOptions(
      onlyFirestore: true,
      persistPath: '.data', // imported at start, exported on exit
    ),
  );
});
tearDownAll(() => emulator.stop());
```
