import 'dart:async';
import 'dart:io';

import 'package:dev_build/shell.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/global_lock.dart';
import 'emulator_options.dart';

/// The name of the [GlobalLock] held from `FirebaseEmulatorService.start` to
/// [FirebaseEmulator.stop], by the isolates and processes of the machine: the
/// emulator ports are those of the machine, two users of the emulator suite
/// would clash (one stopping the emulator of the other, a start failing on a
/// port in use, a running emulator with other options).
///
/// A tool starting the emulator suite on its own (`firebase emulators:exec`)
/// can hold it too.
const firebaseEmulatorLockName = 'tekartik_firebase_emulator';

/// The default wait for the emulator lock in `FirebaseEmulatorService.start`.
const firebaseEmulatorLockTimeout = Duration(minutes: 10);

/// Acquires the emulator [lock] ([firebaseEmulatorLockName] by default),
/// telling once on stderr when another isolate or process holds it, waiting
/// at most [timeout] ([firebaseEmulatorLockTimeout] by default).
@internal
Future<GlobalLockHandle> firebaseEmulatorLock({
  Duration? timeout,
  GlobalLock? lock,
}) async {
  lock ??= GlobalLock(firebaseEmulatorLockName);
  timeout ??= firebaseEmulatorLockTimeout;
  try {
    return await lock.acquire(timeout: Duration.zero);
  } on TimeoutException {
    stderr.writeln(
      'Waiting for the firebase emulator lock (${lock.name}), used by '
      'another process or isolate...',
    );
  }
  try {
    return await lock.acquire(timeout: timeout);
  } on TimeoutException catch (e) {
    throw TimeoutException(
      'Firebase emulator still used by another process or isolate after '
      '$timeout (${e.message})',
      timeout,
    );
  }
}

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

  /// The emulator lock, held until [stop].
  final GlobalLockHandle? _lock;

  FirebaseEmulator._({
    required this.path,
    required this.options,
    required this.projectId,
    required this._shell,
    required this._done,
    required this._process,
    required this._lock,
  });

  /// Stops the emulator: interrupts the firebase cli (its clean shutdown),
  /// waits for it to exit, the emulator ports free, then releases the
  /// emulator lock (see [firebaseEmulatorLockName]).
  Future<void> stop() async {
    try {
      await firebaseEmulatorStop(shell: _shell, done: _done, process: _process);
    } finally {
      await _lock?.release();
    }
  }
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
  GlobalLockHandle? lock,
}) async {
  return FirebaseEmulator._(
    path: path,
    options: options,
    projectId: projectId,
    shell: shell,
    done: done,
    process: process,
    lock: lock,
  );
}

/// An emulator already running, not started by us, [lock] (the emulator lock)
/// held until [FirebaseEmulator.stop].
@internal
FirebaseEmulator createRunningEmulator({
  required String projectId,
  GlobalLockHandle? lock,
}) => FirebaseRunningEmulator._(projectId: projectId, lock: lock);

/// A running Firebase emulator instance.
class FirebaseRunningEmulator implements FirebaseEmulator {
  @override
  Future<dynamic> get _done => throw UnimplementedError();

  @override
  Shell get _shell => throw UnimplementedError();

  @override
  Future<Process>? get _process => null;

  @override
  final GlobalLockHandle? _lock;

  @override
  FirebaseEmulatorOptions get options => throw UnimplementedError();

  @override
  String get path => throw UnimplementedError();

  @override
  final String projectId;

  /// Creates a new [FirebaseRunningEmulator] for the project at [path].
  FirebaseRunningEmulator({required this.projectId}) : _lock = null;

  FirebaseRunningEmulator._({required this.projectId, required this._lock});

  /// Leaves the emulator running (not started here), releases the emulator
  /// lock if held.
  @override
  Future<void> stop() async {
    await _lock?.release();
  }
}
