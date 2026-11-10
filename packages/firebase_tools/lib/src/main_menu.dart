import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_firebase_tools_common/firebase_tools_common.dart';
import 'package:tekartik_firebase_tools_common/menu.dart';

import 'firebase_admin_sdk_context.dart';

/// Declares the whole firebase tools menu for one firebase project: its
/// emulator suite, its `firebase` cli deploy commands, the explorer of its
/// auth users, firestore database and storage bucket, and the export of its
/// firestore database to a cloud storage bucket.
///
/// [path] is the firebase folder, i.e. the one holding `firebase.json`,
/// defaulting to the current directory. [projectId] names the project to reach;
/// it defaults to the `default` project of the `.firebaserc` of [path] — pass
/// one explicitly to act on another project, or pass [context] to decide
/// entirely for yourself. The `.firebaserc` is only read when a submenu left
/// to its default options needs it (a [StateError] without one): a tool
/// passing [context] and the options of the submenus it keeps needs no
/// firebase folder.
///
/// The default emulator options start the emulators on that project id: a
/// function the emulator runs reaches, in production, the services that are
/// not emulated. Pass [emulatorOptions] with a `demo-` project id to keep
/// everything local.
///
/// [context] is what the explorer acts on, the ambient admin sdk credentials of
/// [projectId] by default (see [newFirebaseToolsContextAdminSdk]).
/// [emulatorOptions], [projectOptions] and [exportOptions] likewise override
/// what the emulator, deploy and export submenus use.
///
/// [withEmulator], [withProject], [withExplorer] and [withExport] each drop
/// their submenu when set to `false`, for a tool that only wants some of it.
///
/// Everything the explorer does goes through privileged credentials: it reads
/// and creates auth users, and bypasses the firestore rules. This belongs in a
/// dev tool, never in an app.
void menuFirebaseToolsContent({
  String? path,
  String? projectId,
  FirebaseToolsContext? context,
  FirebaseEmulatorOptions? emulatorOptions,
  FirebaseProjectOptions? projectOptions,
  FirestoreExportOptions? exportOptions,
  bool withEmulator = true,
  bool withProject = true,
  bool withExplorer = true,
  bool withExport = true,
}) {
  var folderPath = path ?? '.';
  // Read once and only when a submenu needs it (one left to its default
  // options): reading it twice would report the same failure twice, and a
  // tool whose submenus all have their own options or context needs no
  // firebase folder.
  String? readProjectId;
  String folderProjectId() => readProjectId ??=
      projectId ??
      projectOptions?.projectId ??
      exportOptions?.projectId ??
      firebaseFolderProjectId(path: folderPath);

  if (withEmulator) {
    menu('emulator', () {
      menuFirebaseEmulatorContent(
        service: FirebaseEmulatorService(path: folderPath),
        options:
            emulatorOptions ??
            FirebaseEmulatorOptions(projectId: folderProjectId()),
      );
    });
  }

  if (withProject) {
    menu('project', () {
      menuFirebaseProjectBuilderContent(
        builder: FirebaseProjectBuilder(
          options:
              projectOptions ??
              FirebaseProjectOptions(
                projectId: folderProjectId(),
                path: folderPath,
              ),
        ),
      );
    });
  }

  if (withExplorer) {
    menu('explore', () {
      menuFirebaseExplorerContent(
        context:
            context ??
            newFirebaseToolsContextAdminSdk(projectId: folderProjectId()),
      );
    });
  }

  if (withExport) {
    menu('export', () {
      menuFirestoreExportContent(
        exporter: FirestoreExporter(
          options:
              exportOptions ??
              FirestoreExportOptions(projectId: folderProjectId()),
        ),
      );
    });
  }
}

/// Runs the whole firebase tools console menu of one firebase project, i.e.
/// [menuFirebaseToolsContent] wrapped in a `dev_build` console.
///
/// This is the one-liner a `tool/` script needs:
///
/// ```dart
/// Future<void> main(List<String> arguments) =>
///     firebaseToolsMenuMain(arguments, path: 'deploy');
/// ```
///
/// [arguments] are the ones of `main`, passed on to the menu console. Every
/// other parameter is the one of [menuFirebaseToolsContent].
Future<void> firebaseToolsMenuMain(
  List<String> arguments, {
  String? path,
  String? projectId,
  FirebaseToolsContext? context,
  FirebaseEmulatorOptions? emulatorOptions,
  FirebaseProjectOptions? projectOptions,
  FirestoreExportOptions? exportOptions,
  bool withEmulator = true,
  bool withProject = true,
  bool withExplorer = true,
  bool withExport = true,
}) async {
  mainMenuConsole(arguments, () {
    menuFirebaseToolsContent(
      path: path,
      projectId: projectId,
      context: context,
      emulatorOptions: emulatorOptions,
      projectOptions: projectOptions,
      exportOptions: exportOptions,
      withEmulator: withEmulator,
      withProject: withProject,
      withExplorer: withExplorer,
      withExport: withExport,
    );
  });
}
