import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';

/// Lets callers cancel an in-progress [FirebaseProjectBuilder] action
/// (deploy, serve, etc).
class FirebaseProjectActionController {
  Shell? _shell;

  /// Kills the underlying `firebase` shell command, aborting the action it
  /// was passed to.
  void cancel() {
    _shell?.kill();
  }
}

/// Private extension to set the shell
extension FirebaseProjectActionControllerPrvExt
    on FirebaseProjectActionController {
  /// Set the shell
  set shell(Shell shell) {
    _shell = shell;
  }
}

/// The firebase project id a firebase folder deploys to, i.e. the `default`
/// project of its `.firebaserc`.
///
/// [path] is the firebase folder, defaulting to the current directory.
///
/// Returns the project id. Throws a [StateError] when the folder is not a
/// firebase folder (no `firebase.json`), when it has no `.firebaserc`, or when
/// no default project is set in it — running an admin tool against the wrong
/// project is worse than not running it.
String firebaseFolderProjectId({String? path}) {
  var folder = normalize(absolute(path ?? '.'));
  if (!File(join(folder, 'firebase.json')).existsSync()) {
    throw StateError('no firebase.json in $folder');
  }
  var firebaseRcFile = File(join(folder, '.firebaserc'));
  if (!firebaseRcFile.existsSync()) {
    throw StateError('no .firebaserc in $folder');
  }
  return firebaseRcContentProjectId(
    firebaseRcFile.readAsStringSync(),
    context: firebaseRcFile.path,
  );
}

/// The `default` project id of the `.firebaserc` content [content].
///
/// [content] is the raw json text of a `.firebaserc` file. [context] is only
/// used in the error message, to name what was read (the file path, typically).
///
/// Returns the `projects.default` entry. Throws a [StateError] when the content
/// is not a json object or has no non-empty default project.
String firebaseRcContentProjectId(String content, {String? context}) {
  var where = context ?? '.firebaserc';
  Object? decoded;
  try {
    decoded = jsonDecode(content);
  } catch (e) {
    throw StateError('invalid json in $where ($e)');
  }
  if (decoded is! Map) {
    throw StateError('invalid content in $where');
  }
  var projectId = ((decoded['projects'] as Map?)?['default'])?.toString();
  if (projectId == null || projectId.isEmpty) {
    throw StateError('no default project in $where');
  }
  return projectId;
}

/// Identifies a Firebase project and its default deploy functions, used by
/// [FirebaseProjectBuilder].
class FirebaseProjectOptions {
  /// Firebase project ID (used with `firebase --project`).
  final String projectId;

  /// Absolute, normalized working directory containing `firebase.json`.
  late final String path;

  /// Default function names to deploy when
  /// [FirebaseProjectBuilder.deployFunctions] is called without its own
  /// `functions` argument, e.g. `['commanddartv2dev',
  /// 'callcommanddartv2dev']`. If `null`/empty, all functions are
  /// deployed.
  final List<String>? functions;

  /// The functions source folder relative to [path], i.e. the `source` of
  /// the `functions` entry of `firebase.json`.
  ///
  /// Only used to compile dart cloud functions, see
  /// [FirebaseProjectBuilder.compileFunctions].
  final String functionsSource;

  /// The dart entry point compiled to an executable, relative to
  /// [functionsSource].
  final String functionsEntryPoint;

  /// `--target-os` of `dart compile exe`, the os the firebase dart runtime
  /// runs the compiled functions on.
  final String functionsTargetOs;

  /// `--target-arch` of `dart compile exe`.
  final String functionsTargetArch;

  /// Creates options for [projectId], rooted at [path] (defaults to the
  /// current directory), with [functions] as the default deploy target
  /// list (defaults to `null`, meaning all functions).
  ///
  /// The `functions*` defaults match the `*_dartff` layout used across the
  /// projects: a `functions` folder with a `bin/server.dart` entry point,
  /// compiled for linux x64.
  FirebaseProjectOptions({
    required this.projectId,
    String? path,
    this.functions,
    this.functionsSource = 'functions',
    this.functionsEntryPoint = 'bin/server.dart',
    this.functionsTargetOs = 'linux',
    this.functionsTargetArch = 'x64',
  }) {
    this.path = normalize(absolute(path ?? '.'));
  }

  /// Creates options for the firebase folder at [path] (defaults to the
  /// current directory), reading the project id from its `.firebaserc`.
  ///
  /// See [firebaseFolderProjectId] for what is read and when it throws. The
  /// other parameters are the ones of the default constructor.
  factory FirebaseProjectOptions.firebaseFolder({
    String? path,
    List<String>? functions,
    String functionsSource = 'functions',
    String functionsEntryPoint = 'bin/server.dart',
    String functionsTargetOs = 'linux',
    String functionsTargetArch = 'x64',
  }) {
    return FirebaseProjectOptions(
      projectId: firebaseFolderProjectId(path: path),
      path: path,
      functions: functions,
      functionsSource: functionsSource,
      functionsEntryPoint: functionsEntryPoint,
      functionsTargetOs: functionsTargetOs,
      functionsTargetArch: functionsTargetArch,
    );
  }

  /// Absolute path of the functions source folder.
  String get functionsSourcePath => normalize(join(path, functionsSource));

  /// Returns a copy of these options, overriding the given fields while
  /// keeping the rest unchanged.
  FirebaseProjectOptions copyWith({
    String? projectId,
    String? path,
    List<String>? functions,
    String? functionsSource,
    String? functionsEntryPoint,
    String? functionsTargetOs,
    String? functionsTargetArch,
  }) {
    return FirebaseProjectOptions(
      projectId: projectId ?? this.projectId,
      path: path ?? this.path,
      functions: functions ?? this.functions,
      functionsSource: functionsSource ?? this.functionsSource,
      functionsEntryPoint: functionsEntryPoint ?? this.functionsEntryPoint,
      functionsTargetOs: functionsTargetOs ?? this.functionsTargetOs,
      functionsTargetArch: functionsTargetArch ?? this.functionsTargetArch,
    );
  }

  @override
  String toString() => 'FirebaseProjectOptions($projectId, $path)';
}

/// The `--only` filter deploying [functions] needs.
///
/// `functions` when [functions] is null or empty (every function of the
/// project), `functions:a,functions:b` otherwise. A name already prefixed with
/// `functions:` is left alone.
String firebaseFunctionsDeployOnly(List<String>? functions) {
  if (functions == null || functions.isEmpty) {
    return 'functions';
  }
  return functions
      .map((name) => name.startsWith('functions:') ? name : 'functions:$name')
      .join(',');
}

/// The `firebase deploy` command line for [projectId], restricted to [only]
/// (a raw comma-separated target list, e.g. `'functions:a,firestore:rules'`)
/// when given, with `--force` when [force] is true.
///
/// `--force` skips the interactive confirmations of the firebase cli: the
/// cloud functions or firestore indexes no longer in the source are deleted
/// without asking, and the automatic functions runtime upgrade checks are
/// bypassed. It has no effect on targets that never prompt (rules, hosting).
String firebaseDeployCommand({
  required String projectId,
  String? only,
  bool? force,
}) {
  var onlyArg = only == null ? '' : ' --only $only';
  var forceArg = force == true ? ' --force' : '';
  return 'firebase deploy$onlyArg --project $projectId$forceArg';
}

/// Runs `firebase` CLI deploy/serve commands for the project described by
/// [options].
///
/// Every deploy method takes an optional [FirebaseProjectActionController]
/// wired to the underlying shell so that
/// [FirebaseProjectActionController.cancel] can abort the deploy, and a
/// `force` flag adding `--force` to the command (see
/// [firebaseDeployCommand]).
class FirebaseProjectBuilder {
  /// The project this builder targets.
  final FirebaseProjectOptions options;

  /// The absolute working directory the `firebase` commands run in, i.e.
  /// [FirebaseProjectOptions.path].
  String get path => options.path;

  /// Creates a builder for the project described by [options].
  FirebaseProjectBuilder({required this.options});

  /// Runs `firebase deploy` in [path], restricted to [only] when given,
  /// with `--force` when [force] is true.
  Future<void> _deploy(
    String? only,
    FirebaseProjectActionController? controller, {
    bool? force,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run(
      firebaseDeployCommand(
        projectId: options.projectId,
        only: only,
        force: force,
      ),
    );
  }

  /// Deploys Firestore security rules via
  /// `firebase deploy --only firestore:rules`. If [controller] is given,
  /// it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  /// [force] adds `--force`, see [firebaseDeployCommand].
  Future<void> deployFirestoreRules({
    FirebaseProjectActionController? controller,
    bool? force,
  }) => _deploy('firestore:rules', controller, force: force);

  /// Deploys Firestore indexes via
  /// `firebase deploy --only firestore:indexes`. If [controller] is given,
  /// it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  /// [force] adds `--force`, deleting the indexes no longer in the source
  /// without confirmation, see [firebaseDeployCommand].
  Future<void> deployFirestoreIndexes({
    FirebaseProjectActionController? controller,
    bool? force,
  }) => _deploy('firestore:indexes', controller, force: force);

  /// Deploys the Firestore rules and indexes at once via
  /// `firebase deploy --only firestore`.
  /// [force] adds `--force`, see [firebaseDeployCommand].
  Future<void> deployFirestore({
    FirebaseProjectActionController? controller,
    bool? force,
  }) => _deploy('firestore', controller, force: force);

  /// Deploys Storage security rules via `firebase deploy --only storage`.
  /// If [controller] is given, it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  /// [force] adds `--force`, see [firebaseDeployCommand].
  Future<void> deployStorageRules({
    FirebaseProjectActionController? controller,
    bool? force,
  }) => _deploy('storage', controller, force: force);

  /// Deploys Cloud Functions via `firebase deploy --only functions[:name,...]`.
  ///
  /// [functions] overrides [FirebaseProjectOptions.functions] as the list
  /// of function names to deploy; if both are `null`/empty, all functions
  /// are deployed. If [controller] is given, it's wired to the underlying
  /// shell so [FirebaseProjectActionController.cancel] can abort the
  /// deploy. [force] adds `--force`, deleting the functions no longer in
  /// the source and bypassing the runtime upgrade checks without
  /// confirmation, see [firebaseDeployCommand].
  Future<void> deployFunctions({
    List<String>? functions,
    FirebaseProjectActionController? controller,
    bool? force,
  }) => _deploy(
    firebaseFunctionsDeployOnly(functions ?? options.functions),
    controller,
    force: force,
  );

  /// Compiles the dart cloud functions server to an executable, i.e.
  /// `dart compile exe <functionsEntryPoint>` in the functions source folder,
  /// for the os/arch the firebase dart runtime expects.
  ///
  /// See [FirebaseProjectOptions.functionsSource] and friends for what is
  /// compiled and how.
  Future<void> compileFunctions() async {
    var shell = Shell(workingDirectory: options.functionsSourcePath);
    await shell.run(
      'dart compile exe ${options.functionsEntryPoint}'
      ' --target-os=${options.functionsTargetOs}'
      ' --target-arch=${options.functionsTargetArch}',
    );
  }

  /// Runs [compileFunctions] followed by [deployFunctions].
  Future<void> compileAndDeployFunctions({
    List<String>? functions,
    FirebaseProjectActionController? controller,
    bool? force,
  }) async {
    await compileFunctions();
    await deployFunctions(
      functions: functions,
      controller: controller,
      force: force,
    );
  }

  /// Deploys via `firebase deploy --only [only]`, where [only] is a raw
  /// comma-separated target list (e.g. `'hosting,firestore:rules'`). If
  /// [controller] is given, it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  /// [force] adds `--force`, see [firebaseDeployCommand].
  Future<void> deployOnly(
    String only, {
    FirebaseProjectActionController? controller,
    bool? force,
  }) => _deploy(only, controller, force: force);

  /// Deploys every configured target via a plain `firebase deploy`. If
  /// [controller] is given, it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  /// [force] adds `--force`, see [firebaseDeployCommand].
  Future<void> deploy({
    FirebaseProjectActionController? controller,
    bool? force,
  }) => _deploy(null, controller, force: force);

  /// Starts the Firebase emulators via `firebase emulators:start`.
  ///
  /// [only], if given, is passed through as a raw `--only` target list
  /// (e.g. `'hosting,firestore'`); otherwise all configured emulators are
  /// started. If [controller] is given, it's wired to the underlying
  /// shell so [FirebaseProjectActionController.cancel] can stop it.
  Future<void> serve({
    String? only,
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    var onlyArg = only != null ? ' --only $only' : '';
    await shell.run(
      'firebase emulators:start --project ${options.projectId}$onlyArg',
    );
  }
}
