import 'dart:async';
import 'dart:io';

import 'package:dev_build/shell.dart';
import 'package:meta/meta.dart';
import 'emulator_options.dart';

/// A running Firebase emulator instance.
class FirebaseEmulator {
  /// The path to the Firebase project directory.
  final String path;

  /// The options used to start the emulator.
  final FirebaseEmulatorOptions options;

  /// The Firebase project ID.
  final String projectId;
  final Shell _shell;
  final Future _done;
  final Future<Process>? _process;

  FirebaseEmulator._({
    required this.path,
    required this.options,
    required this.projectId,
    required this._shell,
    required this._done,
    required this._process,
  });

  /// Stops the emulator: interrupts the firebase cli (its clean shutdown) and
  /// waits for it to exit, the emulator ports free.
  Future<void> stop() =>
      firebaseEmulatorStop(shell: _shell, done: _done, process: _process);
}

/// Stops an emulator started by [shell] ([done] its run): interrupts the
/// firebase cli, then waits for [process] to exit, killed after [timeout]
/// (30s by default).
///
/// The shell gives up on a killed run at once, while the firebase cli is still
/// shutting the emulators down: another start right after would find them
/// still answering, take them as running, and talk to emulators about to exit.
@internal
Future<void> firebaseEmulatorStop({
  required Shell shell,
  required Future done,
  Future<Process>? process,
  Duration? timeout,
}) async {
  timeout ??= const Duration(seconds: 30);
  try {
    shell.kill(ProcessSignal.sigint);
    await done;
  } catch (_) {}
  if (process != null) {
    var started = await process;
    try {
      await started.exitCode.timeout(timeout);
    } on TimeoutException {
      started.kill(ProcessSignal.sigkill);
      await started.exitCode;
    }
  }
}

@internal
Future<FirebaseEmulator> createEmulator({
  required String path,
  required FirebaseEmulatorOptions options,
  required Shell shell,
  required Future done,
  required String projectId,
  Future<Process>? process,
}) async {
  return FirebaseEmulator._(
    path: path,
    options: options,
    projectId: projectId,
    shell: shell,
    done: done,
    process: process,
  );
}

/// A running Firebase emulator instance.
class FirebaseRunningEmulator implements FirebaseEmulator {
  @override
  Future<dynamic> get _done => throw UnimplementedError();

  @override
  Shell get _shell => throw UnimplementedError();

  @override
  Future<Process>? get _process => null;

  @override
  FirebaseEmulatorOptions get options => throw UnimplementedError();

  @override
  String get path => throw UnimplementedError();

  @override
  final String projectId;

  /// Creates a new [FirebaseRunningEmulator] for the project at [path].
  FirebaseRunningEmulator({required this.projectId});

  @override
  Future<void> stop() async {
    // no-op
  }
}
