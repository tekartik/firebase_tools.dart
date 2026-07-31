// A dev menu over one firebase project: its emulator suite, its deploy
// commands, and an explorer for its auth users, firestore and storage.
//
// Run it from a firebase folder (the one holding `firebase.json`), or name one:
//
//     dart run example/firebase_tools_menu.dart [path]
//
// Reaching the real project needs the ambient admin credentials, i.e.
// `gcloud auth application-default login`.
import 'package:tekartik_firebase_tools/menu.dart';

Future<void> main(List<String> arguments) => firebaseToolsMenuMain(
  arguments,
  path: arguments.isEmpty ? '.' : arguments.first,
);
