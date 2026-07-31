@TestOn('vm')
library;

import 'dart:io';

import 'package:tekartik_firebase_tools_common/firebase_emulator.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseEmulatorOptions', () {
    test('defaults are all unset', () {
      var options = FirebaseEmulatorOptions();
      expect(options.projectId, isNull);
      expect(options.onlyAuth, isNull);
      expect(options.onlyFirestore, isNull);
      expect(options.onlyStorage, isNull);
      expect(options.onlyFunctions, isNull);
      expect(options.debug, isNull);
      expect(options.persistPath, isNull);
      expect(options.processStartMode, isNull);
    });

    test('copyWith overrides only what it is given', () {
      var options = FirebaseEmulatorOptions(
        projectId: 'my_project',
        onlyAuth: true,
        persistPath: '.local/emulator',
        processStartMode: ProcessStartMode.inheritStdio,
      );
      var copy = options.copyWith(onlyFirestore: true);
      expect(copy.projectId, 'my_project');
      expect(copy.onlyAuth, isTrue);
      expect(copy.onlyFirestore, isTrue);
      expect(copy.persistPath, '.local/emulator');
      expect(copy.processStartMode, ProcessStartMode.inheritStdio);
      expect(copy.onlyStorage, isNull);
    });

    test('toString names every field', () {
      var text = FirebaseEmulatorOptions(projectId: 'my_project').toString();
      expect(text, contains('my_project'));
      expect(text, contains('onlyAuth'));
    });
  });

  group('FirebaseEmulatorService', () {
    test('is not supported outside a firebase folder', () async {
      var service = FirebaseEmulatorService(path: '.dart_tool');
      var status = await service.checkStatus(force: true);
      expect(status.supported, isFalse);
      expect(status.running, isFalse);
      expect(await service.isSupported(force: true), isFalse);
    });
  });

  group('EmulatorServiceStatus', () {
    test('not running', () {
      var status = EmulatorServiceNotRunningStatus();
      expect(status.supported, isTrue);
      expect(status.running, isFalse);
    });

    test('not supported', () {
      var status = EmulatorServiceNotSupportedStatus();
      expect(status.supported, isFalse);
      expect(status.running, isFalse);
    });

    test('running carries the ports', () {
      var status = EmulatorServiceRunningStatus(
        firestorePort: 8080,
        authPort: 9099,
        storagePort: null,
        functionsPort: null,
      );
      expect(status.supported, isTrue);
      expect(status.running, isTrue);
      expect(status.firestorePort, 8080);
      expect(status.authPort, 9099);
      expect(status.storagePort, isNull);
      expect('$status', contains('8080'));
    });
  });

  test('FirebaseRunningEmulator stops without doing anything', () async {
    var emulator = FirebaseRunningEmulator(projectId: 'my_project');
    expect(emulator.projectId, 'my_project');
    await emulator.stop();
  });
}
