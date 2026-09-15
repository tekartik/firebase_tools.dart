# tekartik_firebase_tools

Firebase developer tools for dart, bound to the admin sdk. **This is the
package to depend on.**

It re-exports the whole of
[`tekartik_firebase_tools_common`](../firebase_tools_common) — the emulator
suite, the `firebase` cli deploy commands, the auth/firestore/storage explorer
and their `dev_build` menus — and adds the two things that need a real firebase
implementation:

- **building a context that reaches a real project**, by id, by service account
  or from a firebase folder;
- **listing the firestore documents that do not exist** but hold sub
  collections, which only the admin sdk native instance can do;

plus **the main menu entry point**, `firebaseToolsMenuMain`.

The admin sdk talks to the project with full privileges: it reads and creates
auth users, which a client auth cannot, and bypasses the firestore rules. This
belongs in a dev tool, never in an app.

## Setup

```yaml
dependencies:
  tekartik_firebase_tools:
    git:
      url: https://github.com/tekartik/firebase_tools.dart
      path: packages/firebase_tools
```

## Entry points

| Import | Holds |
| --- | --- |
| `package:tekartik_firebase_tools/firebase_tools.dart` | the common api plus the admin sdk context builders |
| `package:tekartik_firebase_tools/menu.dart` | the common menus plus `firebaseToolsMenuMain` |

## The main menu

One call gives the whole tool for a firebase folder — emulator, deploy and
explorer submenus, with the project id read from its `.firebaserc`:

```dart
import 'package:tekartik_firebase_tools/menu.dart';

Future<void> main(List<String> arguments) =>
    firebaseToolsMenuMain(arguments, path: 'deploy');
```

`menuFirebaseToolsContent` declares the same inside a menu you own, and takes
the same parameters: `path`, `projectId`, a `context` of your own, and
`withEmulator` / `withProject` / `withExplorer` to drop a submenu. See
[`example/`](example) for both.

## Reaching a project

```dart
import 'package:tekartik_firebase_tools/firebase_tools.dart';

// Ambient credentials (`gcloud auth application-default login`). Pass no
// project id at all to let the environment decide which project is reached.
var context = newFirebaseToolsContextAdminSdk(projectId: 'my_project');

// ...or the project a firebase folder deploys to, from its `.firebaserc`.
var folderContext = newFirebaseToolsContextFirebaseFolder(path: 'deploy');

// ...or a service account json, for credentials checked in a private repo.
var serviceAccountContext = newFirebaseToolsContextServiceAccountMap(map);
```

All three build the app on first use, so declaring a menu over one costs no
network call and no credential lookup, and all three wire
`firestoreAdminSdkDocumentIdsLister` in — so a firestore collection listing
reports the ids that exist only because something hangs below them, the way the
firestore console shows them in italics.

What to do with a context is the common package's business; see
[its README](../firebase_tools_common/README.md#exploring-a-project) for the
auth, firestore and storage explorers and the path helpers.

## Agent skills

The `skills/` folder holds `tekartik-firebase-tools-dev-menu`, the agent skill
of this package (the main menu and the admin sdk contexts); the common package
has one per area (emulator, deploy, explorer). `dart run skills@ get` installs
the skills of every dependency into `.agents/skills/`.
