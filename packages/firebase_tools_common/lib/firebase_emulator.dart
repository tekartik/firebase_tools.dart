/// Starting and querying the firebase emulator suite of a firebase folder.
///
/// The same api as `package:tekartik_firebase_emulator/firebase_emulator.dart`,
/// aggregated here so a tool only needs `tekartik_firebase_tools`.
library;

export 'src/emulator.dart' show FirebaseEmulator, FirebaseRunningEmulator;
export 'src/emulator_options.dart' show FirebaseEmulatorOptions;
export 'src/emulator_service.dart'
    show
        FirebaseEmulatorService,
        EmulatorServiceStatus,
        EmulatorServiceRunningStatus,
        EmulatorServiceNotRunningStatus,
        EmulatorServiceNotSupportedStatus;
