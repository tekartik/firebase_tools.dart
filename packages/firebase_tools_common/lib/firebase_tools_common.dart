/// Firebase developer tools, on the firebase abstractions only: the emulator
/// suite, the `firebase` cli deploy commands, and an explorer for the auth
/// users, the firestore database and the storage bucket of a project.
///
/// Nothing here picks a firebase implementation. `tekartik_firebase_tools`
/// binds all of it to the admin sdk and adds the main dev menu.
///
/// This is the whole api but the menus, which live in `menu.dart` so a package
/// that only needs the plumbing does not pull `dev_build`'s menu in.
library;

export 'firebase_emulator.dart';
export 'firebase_explorer.dart';
export 'firebase_project.dart';
