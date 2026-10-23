@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:dev_build/shell.dart';
import 'package:tekartik_firebase_tools_common/src/emulator.dart';
import 'package:test/test.dart';

/// Runs the sh [script] as the firebase cli would be run: the shell, its run
/// and its process.
({Shell shell, Future<Object?> done, Future<Process> process}) _run(
  String script,
) {
  var shell = Shell(verbose: false);
  var processCompleter = Completer<Process>();
  var done = shell.run(
    'sh -c "$script"',
    onProcess: (process) => processCompleter.complete(process),
  );
  return (shell: shell, done: done, process: processCompleter.future);
}

void main() {
  group('firebaseEmulatorStop', () {
    test('waits for the process to exit after the interrupt', () async {
      // Exits a second after the interrupt, as the firebase cli shutting
      // the emulators down.
      var run = _run(
        "trap 'sleep 1; exit 0' INT; while true; do sleep 0.05; done",
      );
      var process = await run.process;
      // The trap set.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      var sw = Stopwatch()..start();
      await firebaseEmulatorStop(
        shell: run.shell,
        done: run.done,
        process: run.process,
      );
      expect(sw.elapsed, greaterThan(const Duration(milliseconds: 800)));
      expect(await process.exitCode, 0);
    }, skip: Platform.isWindows ? 'sh' : null);

    test('kills a process ignoring the interrupt after the timeout', () async {
      var run = _run("trap '' INT; while true; do sleep 0.05; done");
      var process = await run.process;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await firebaseEmulatorStop(
        shell: run.shell,
        done: run.done,
        process: run.process,
        timeout: const Duration(milliseconds: 500),
      );
      expect(await process.exitCode, isNot(0));
    }, skip: Platform.isWindows ? 'sh' : null);
  });
}
