@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dev_build/shell.dart';
import 'package:synchronized/global_lock.dart';
import 'package:tekartik_firebase_tools_common/firebase_emulator.dart';
import 'package:tekartik_firebase_tools_common/src/emulator.dart';
import 'package:test/test.dart';

/// Unique to this run: never the real emulator lock, used by other processes.
final _runId = Random().nextInt(1000000);
var _lockCount = 0;
GlobalLock _newTestLock() =>
    GlobalLock('firebase_tools_common_test_${_runId}_${++_lockCount}');

/// True when [lock] can be acquired at once (then released).
Future<bool> _isFree(GlobalLock lock) async {
  try {
    await (await lock.acquire(timeout: Duration.zero)).release();
    return true;
  } on TimeoutException {
    return false;
  }
}

void main() {
  test('firebaseEmulatorLockName', () {
    expect(firebaseEmulatorLockName, 'tekartik_firebase_emulator');
    expect(firebaseEmulatorLockTimeout, const Duration(minutes: 10));
  });

  group('firebaseEmulatorLock', () {
    test('free', () async {
      var lock = _newTestLock();
      var handle = await firebaseEmulatorLock(lock: lock);
      expect(await _isFree(lock), isFalse);
      await handle.release();
      expect(await _isFree(lock), isTrue);
    });

    test('waits for the holder', () async {
      var lock = _newTestLock();
      var held = await lock.acquire();
      var acquired = false;
      var future =
          firebaseEmulatorLock(
            lock: lock,
            timeout: const Duration(seconds: 10),
          ).then((handle) {
            acquired = true;
            return handle;
          });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(acquired, isFalse);
      await held.release();
      await (await future).release();
      expect(acquired, isTrue);
    });

    test('timeout', () async {
      var lock = _newTestLock();
      var held = await lock.acquire();
      try {
        await firebaseEmulatorLock(
          lock: lock,
          timeout: const Duration(milliseconds: 100),
        );
        fail('should time out');
      } on TimeoutException catch (e) {
        expect(e.message, contains('Firebase emulator still used'));
        expect(e.duration, const Duration(milliseconds: 100));
      } finally {
        await held.release();
      }
    });
  });

  group('stop releases the lock', () {
    test('started emulator', () async {
      var lock = _newTestLock();
      var shell = Shell(verbose: false);
      var processCompleter = Completer<Process>();
      // Exits on the interrupt, as the firebase cli.
      var done = shell.run(
        'sh -c "trap \'exit 0\' INT; while true; do sleep 0.05; done"',
        onProcess: processCompleter.complete,
      );
      await processCompleter.future;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      var emulator = await createEmulator(
        path: '.',
        options: FirebaseEmulatorOptions(),
        shell: shell,
        done: done,
        projectId: 'test',
        process: processCompleter.future,
        lock: await lock.acquire(),
      );
      expect(await _isFree(lock), isFalse);
      await emulator.stop();
      expect(await _isFree(lock), isTrue);
      // Twice is fine.
      await emulator.stop();
    }, skip: Platform.isWindows ? 'sh' : null);

    test('running emulator', () async {
      var lock = _newTestLock();
      var emulator = createRunningEmulator(
        projectId: 'test',
        lock: await lock.acquire(),
      );
      expect(emulator.projectId, 'test');
      expect(await _isFree(lock), isFalse);
      await emulator.stop();
      expect(await _isFree(lock), isTrue);
    });

    test('public running emulator holds nothing', () async {
      await FirebaseRunningEmulator(projectId: 'test').stop();
    });
  });
}
