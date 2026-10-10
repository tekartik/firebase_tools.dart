import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:process_run/shell.dart';

import 'google_access_token.dart';

String get _homePath {
  var env = Platform.environment;
  return env['HOME'] ?? env['USERPROFILE'] ?? '.';
}

/// Uses the account the Firebase CLI is logged in with (`firebase login`).
///
/// Reads `~/.config/configstore/firebase-tools.json` (never writes it) and
/// refreshes the access token with the OAuth client of the Firebase CLI, the
/// one that issued its refresh token. That client is not part of this
/// package: pass [clientId] and [clientSecret] or set `FIREBASE_CLIENT_ID`
/// and `FIREBASE_CLIENT_SECRET`. `FIREBASE_TOKEN` (a refresh token from
/// `firebase login:ci`) takes precedence over the login when set.
class FirebaseCliAccessTokenProvider implements GoogleAccessTokenProvider {
  static const _tokenUrl = 'https://www.googleapis.com/oauth2/v3/token';

  /// OAuth client id of the Firebase CLI.
  final String? clientId;

  /// OAuth client secret of the Firebase CLI.
  final String? clientSecret;

  /// Optional http client.
  final http.Client? client;

  /// Firebase CLI configuration file path.
  final String configPath;

  GoogleAccessToken? _cached;

  /// Uses the Firebase CLI login, [configPath] defaults to
  /// [firebaseCliConfigPath].
  FirebaseCliAccessTokenProvider({
    String? clientId,
    String? clientSecret,
    this.client,
    String? configPath,
  }) : clientId = clientId ?? Platform.environment['FIREBASE_CLIENT_ID'],
       clientSecret =
           clientSecret ?? Platform.environment['FIREBASE_CLIENT_SECRET'],
       configPath = configPath ?? firebaseCliConfigPath;

  /// Default Firebase CLI configuration file path.
  static String get firebaseCliConfigPath {
    var configHome =
        Platform.environment['XDG_CONFIG_HOME'] ?? join(_homePath, '.config');
    return join(configHome, 'configstore', 'firebase-tools.json');
  }

  @override
  String? get quotaProjectId => null;

  Future<Map<String, Object?>> _readConfig() async {
    var file = File(configPath);
    if (!file.existsSync()) {
      throw StateError('$configPath not found, run `firebase login`');
    }
    return (jsonDecode(await file.readAsString()) as Map)
        .cast<String, Object?>();
  }

  @override
  Future<String> getAccountDescription() async {
    if (Platform.environment['FIREBASE_TOKEN'] != null) {
      return 'FIREBASE_TOKEN';
    }
    var config = await _readConfig();
    var email = (config['user'] as Map?)?['email'] as String?;
    return 'firebase cli ${email ?? '(unknown account)'}';
  }

  @override
  Future<String> getAccessToken() async {
    var cached = _cached;
    if (cached != null && cached.isValid) {
      return cached.token;
    }
    var refreshToken = Platform.environment['FIREBASE_TOKEN'];
    if (refreshToken == null) {
      var tokens = ((await _readConfig())['tokens'] as Map?)
          ?.cast<String, Object?>();
      refreshToken = tokens?['refresh_token'] as String?;
      if (refreshToken == null) {
        throw StateError('No refresh token in $configPath, run firebase login');
      }
      // Reuse the CLI access token while still valid.
      var accessToken = tokens?['access_token'] as String?;
      var expiresAt = tokens?['expires_at'] as num?;
      if (accessToken != null && expiresAt != null) {
        cached = GoogleAccessToken(
          accessToken,
          DateTime.fromMillisecondsSinceEpoch(expiresAt.toInt()),
        );
        if (cached.isValid) {
          return (_cached = cached).token;
        }
      }
    }
    var clientId = this.clientId;
    var clientSecret = this.clientSecret;
    if (clientId == null || clientSecret == null) {
      throw StateError(
        'Firebase CLI OAuth client unknown, pass clientId and clientSecret '
        'or set FIREBASE_CLIENT_ID and FIREBASE_CLIENT_SECRET',
      );
    }
    var client = this.client ?? http.Client();
    try {
      var response = await client.post(
        Uri.parse(_tokenUrl),
        body: {
          'refresh_token': refreshToken,
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
        },
      );
      if (response.statusCode != 200) {
        throw StateError(
          'Token refresh failed (${response.statusCode}), '
          'run `firebase login --reauth`: ${response.body}',
        );
      }
      var map = (jsonDecode(response.body) as Map).cast<String, Object?>();
      var expiresIn = (map['expires_in'] as num?)?.toInt() ?? 3600;
      var token = GoogleAccessToken(
        map['access_token'] as String,
        DateTime.now().add(Duration(seconds: expiresIn)),
      );
      _cached = token;
      return token.token;
    } finally {
      if (this.client == null) {
        client.close();
      }
    }
  }
}

/// Uses `gcloud auth [application-default] print-access-token`.
class GcloudAccessTokenProvider implements GoogleAccessTokenProvider {
  /// True for the application default credentials.
  final bool applicationDefault;
  GoogleAccessToken? _cached;
  String? _quotaProjectId;

  /// Uses the gcloud login, or the application default credentials when
  /// [applicationDefault] is true.
  GcloudAccessTokenProvider({this.applicationDefault = false}) {
    if (applicationDefault) {
      _quotaProjectId = _readAdcQuotaProjectId();
    }
  }

  String? _readAdcQuotaProjectId() {
    try {
      var path =
          Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'] ??
          join(
            _homePath,
            '.config',
            'gcloud',
            'application_default_credentials.json',
          );
      var map = jsonDecode(File(path).readAsStringSync()) as Map;
      return map['quota_project_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// User credentials of the application default credentials need a quota
  /// project for the Firebase APIs.
  @override
  String? get quotaProjectId => _quotaProjectId;

  String get _authCommand =>
      applicationDefault ? 'gcloud auth application-default' : 'gcloud auth';

  @override
  Future<String> getAccountDescription() async {
    if (applicationDefault) {
      return 'gcloud application default credentials'
          '${_quotaProjectId != null ? ' (quota project $_quotaProjectId)' : ''}';
    }
    var result = await Shell(
      verbose: false,
    ).run('gcloud config get-value account');
    return 'gcloud ${result.outText.trim()}';
  }

  @override
  Future<String> getAccessToken() async {
    var cached = _cached;
    if (cached != null && cached.isValid) {
      return cached.token;
    }
    var result = await Shell(
      verbose: false,
      throwOnError: false,
    ).run('$_authCommand print-access-token');
    var token = result.outText.trim();
    if (result.first.exitCode != 0 || token.isEmpty) {
      throw StateError(
        '$_authCommand print-access-token failed, '
        'run `$_authCommand login`: ${result.errText.trim()}',
      );
    }
    // gcloud does not tell the remaining lifetime, keep it a short time.
    _cached = GoogleAccessToken(
      token,
      DateTime.now().add(const Duration(minutes: 10)),
    );
    return token;
  }
}

/// Access token provider from a name: `firebase` (default, Firebase CLI
/// login, see [FirebaseCliAccessTokenProvider] for [firebaseCliClientId] and
/// [firebaseCliClientSecret]), `gcloud` or `adc` (application default
/// credentials).
GoogleAccessTokenProvider googleAccessTokenProviderFromName(
  String? name, {
  String? firebaseCliClientId,
  String? firebaseCliClientSecret,
}) {
  switch (name) {
    case null:
    case 'firebase':
      return FirebaseCliAccessTokenProvider(
        clientId: firebaseCliClientId,
        clientSecret: firebaseCliClientSecret,
      );
    case 'gcloud':
      return GcloudAccessTokenProvider();
    case 'adc':
      return GcloudAccessTokenProvider(applicationDefault: true);
  }
  throw ArgumentError.value(name, 'name', 'firebase, gcloud or adc expected');
}
