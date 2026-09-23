import 'dart:io';

/// Options for starting a Firebase emulator.
class FirebaseEmulatorOptions {
  /// The Firebase project ID. If null, it is read from `.firebaserc`.
  final String? projectId;

  /// If true, only the Functions emulator is started.
  bool? onlyFunctions;

  /// If true, only auth is started
  bool? onlyAuth;

  /// If true, only firestore is started
  bool? onlyFirestore;

  /// If true, only storage is started
  bool? onlyStorage;

  /// If true, only pubsub is started
  bool? onlyPubsub;

  /// If true, only hosting is started (serving the hosting targets of
  /// `firebase.json`, their function rewrites reaching the functions
  /// emulator when [onlyFunctions] is set too).
  bool? onlyHosting;

  /// If true, the emulator is started in debug mode.
  bool? debug;

  /// Persist path (i.e. not only in memory)
  /// empty means no persist too
  String? persistPath;

  /// Process start mode
  final ProcessStartMode? processStartMode;

  /// Creates a new [FirebaseEmulatorOptions].
  FirebaseEmulatorOptions({
    this.projectId,
    this.onlyFunctions,
    this.debug,
    this.onlyAuth,
    this.onlyFirestore,
    this.onlyStorage,
    this.onlyPubsub,
    this.onlyHosting,
    this.persistPath,
    this.processStartMode,
  });

  /// Creates a copy of this [FirebaseEmulatorOptions] but with the given fields replaced with the new values.
  FirebaseEmulatorOptions copyWith({
    String? projectId,
    bool? onlyFunctions,
    bool? onlyAuth,
    bool? onlyFirestore,
    bool? onlyStorage,
    bool? onlyPubsub,
    bool? onlyHosting,
    bool? debug,
    String? persistPath,
    ProcessStartMode? processStartMode,
  }) {
    return FirebaseEmulatorOptions(
      projectId: projectId ?? this.projectId,
      onlyFunctions: onlyFunctions ?? this.onlyFunctions,
      onlyAuth: onlyAuth ?? this.onlyAuth,
      onlyFirestore: onlyFirestore ?? this.onlyFirestore,
      onlyStorage: onlyStorage ?? this.onlyStorage,
      onlyPubsub: onlyPubsub ?? this.onlyPubsub,
      onlyHosting: onlyHosting ?? this.onlyHosting,
      debug: debug ?? this.debug,
      persistPath: persistPath ?? this.persistPath,
      processStartMode: processStartMode ?? this.processStartMode,
    );
  }

  @override
  String toString() {
    return 'FirebaseEmulatorOptions(projectId: $projectId, onlyFunctions: $onlyFunctions, onlyAuth: $onlyAuth, onlyFirestore: $onlyFirestore, onlyStorage: $onlyStorage, onlyPubsub: $onlyPubsub, onlyHosting: $onlyHosting, debug: $debug, persistPath: $persistPath, processStartMode: $processStartMode)';
  }
}
