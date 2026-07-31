import 'package:dev_build/menu/menu.dart';
import 'package:path/path.dart';

import 'emulator.dart';
import 'emulator_options.dart';
import 'emulator_service.dart';

/// Registers dev-menu items driving the firebase emulator suite of the firebase
/// folder [service] points at: checking its status, starting it (all services
/// or one of them) and stopping it.
///
/// [options] are the options every start item uses as a base, the `only*` flags
/// of the per-service items aside; leave it `null` for the defaults.
void menuFirebaseEmulatorContent({
  required FirebaseEmulatorService service,
  FirebaseEmulatorOptions? options,
}) {
  var baseOptions = options ?? FirebaseEmulatorOptions();
  FirebaseEmulator? emulator;

  enter(() async {
    write('Firebase folder: ${absolute(service.path)}');
    write('Emulator: ${emulator == null ? '<not started here>' : 'started'}');
  });

  Future<void> start(FirebaseEmulatorOptions options) async {
    if (emulator != null) {
      write('already started, stop it first');
      return;
    }
    emulator = await service.start(options: options);
    write('started $options');
  }

  item('status', () async {
    write('${await service.checkStatus(force: true, verbose: true)}');
  });

  item('project id', () async {
    write(await service.getProjectId(verbose: true));
  });

  item('start', () async {
    await start(baseOptions);
  });

  item('start auth only', () async {
    await start(baseOptions.copyWith(onlyAuth: true));
  });

  item('start firestore only', () async {
    await start(baseOptions.copyWith(onlyFirestore: true));
  });

  item('start storage only', () async {
    await start(baseOptions.copyWith(onlyStorage: true));
  });

  item('start functions only', () async {
    await start(baseOptions.copyWith(onlyFunctions: true));
  });

  item('stop', () async {
    var startedEmulator = emulator;
    if (startedEmulator == null) {
      write('not started here, nothing to stop');
      return;
    }
    await startedEmulator.stop();
    emulator = null;
    write('stopped');
  });

  leave(() async {
    await emulator?.stop();
    emulator = null;
  });
}
