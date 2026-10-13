@TestOn('vm')
library;

import 'dart:async';

import 'package:process_run/shell.dart' show stringToArguments;
import 'package:tekartik_firebase_tools_common/firebase_emulator.dart';
import 'package:tekartik_firebase_tools_common/src/emulator_service.dart';
import 'package:test/test.dart';

/// The arguments of the start command, as the shell splits them.
List<String> _startArguments(FirebaseEmulatorOptions options) =>
    stringToArguments(
      firebaseEmulatorStartCommand(projectId: 'my-project', options: options),
    );

void main() {
  group('firebaseEmulatorStartCommand', () {
    test('default', () {
      expect(_startArguments(FirebaseEmulatorOptions()), [
        'firebase',
        '--project',
        'my-project',
        'emulators:start',
      ]);
    });

    test('debug and only', () {
      expect(
        _startArguments(
          FirebaseEmulatorOptions(
            debug: true,
            onlyAuth: true,
            onlyFunctions: true,
            onlyHosting: true,
          ),
        ),
        [
          'firebase',
          '--project',
          'my-project',
          '--debug',
          'emulators:start',
          '--only',
          'functions,auth,hosting',
        ],
      );
    });

    test('empty persistPath means no persist', () {
      expect(
        _startArguments(FirebaseEmulatorOptions(persistPath: '')),
        isNot(contains('--import')),
      );
    });

    test('persistPath is a single argument', () {
      expect(
        _startArguments(
          FirebaseEmulatorOptions(persistPath: '.local/my data'),
        ).sublist(4),
        ['--import', '.local/my data', '--export-on-exit', '.local/my data'],
      );
    });
  });

  group('firebaseEmulatorWaitReady', () {
    const longTimeout = Duration(seconds: 30);

    test('ready', () async {
      await firebaseEmulatorWaitReady(
        ready: Future.value(true),
        done: Completer<void>().future,
        timeout: longTimeout,
      );
    });

    test('process failing before ready fails at once', () async {
      var sw = Stopwatch()..start();
      // Fails on the next event loop, with nobody else listening: what the
      // shell run does when the firebase cli exits with an error.
      var done = Future<void>.delayed(
        Duration.zero,
        () => throw StateError('cli failed'),
      );
      await expectLater(
        firebaseEmulatorWaitReady(
          ready: Completer<bool>().future,
          done: done,
          timeout: longTimeout,
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'cli failed'),
        ),
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('process exiting normally before ready fails at once', () async {
      var sw = Stopwatch()..start();
      await expectLater(
        firebaseEmulatorWaitReady(
          ready: Completer<bool>().future,
          done: Future<void>.delayed(Duration.zero),
          timeout: longTimeout,
        ),
        throwsStateError,
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('process ending after ready is ignored', () async {
      var ready = Completer<bool>();
      var done = Completer<void>();
      var future = firebaseEmulatorWaitReady(
        ready: ready.future,
        done: done.future,
        timeout: longTimeout,
      );
      ready.complete(true);
      await future;
      done.completeError(StateError('killed'));
      // Still awaited later by the emulator, as its done future.
      await expectLater(done.future, throwsStateError);
    });

    test('timeout', () async {
      await expectLater(
        firebaseEmulatorWaitReady(
          ready: Completer<bool>().future,
          done: Completer<void>().future,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
