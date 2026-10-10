import 'dart:convert';

import 'package:http/http.dart' as http;

import 'google_access_token.dart';

/// Error returned by a Google REST API.
class FirebaseRestException implements Exception {
  /// HTTP status code.
  final int statusCode;

  /// Error message.
  final String message;

  /// Error returned by a Google REST API.
  FirebaseRestException(this.statusCode, this.message);

  @override
  String toString() => 'FirebaseRestException($statusCode): $message';
}

/// A Firebase project (Firebase Management API).
class FirebaseProjectInfo {
  /// Project id.
  final String projectId;

  /// Project number.
  final String? projectNumber;

  /// Display name.
  final String? displayName;

  /// Default hosting site id, null if hosting was never set up.
  final String? hostingSite;

  /// Default storage bucket.
  final String? storageBucket;

  /// Default realtime database instance.
  final String? realtimeDatabaseInstance;

  /// Default resources location (deprecated by the API but still returned).
  final String? locationId;

  /// ACTIVE or DELETED.
  final String? state;

  /// A Firebase project.
  FirebaseProjectInfo({
    required this.projectId,
    this.projectNumber,
    this.displayName,
    this.hostingSite,
    this.storageBucket,
    this.realtimeDatabaseInstance,
    this.locationId,
    this.state,
  });

  /// From the REST json.
  factory FirebaseProjectInfo.fromJson(Map<String, Object?> json) {
    var resources = (json['resources'] as Map?)?.cast<String, Object?>();
    return FirebaseProjectInfo(
      projectId: json['projectId'] as String,
      projectNumber: json['projectNumber'] as String?,
      displayName: json['displayName'] as String?,
      hostingSite: resources?['hostingSite'] as String?,
      storageBucket: resources?['storageBucket'] as String?,
      realtimeDatabaseInstance:
          resources?['realtimeDatabaseInstance'] as String?,
      locationId: resources?['locationId'] as String?,
      state: json['state'] as String?,
    );
  }

  /// The REST json (the fields known here).
  Map<String, Object?> toJson() => {
    'projectId': projectId,
    'projectNumber': ?projectNumber,
    'displayName': ?displayName,
    'resources': {
      'hostingSite': ?hostingSite,
      'storageBucket': ?storageBucket,
      'realtimeDatabaseInstance': ?realtimeDatabaseInstance,
      'locationId': ?locationId,
    },
    'state': ?state,
  };

  @override
  String toString() => displayName == null || displayName == projectId
      ? projectId
      : '$projectId ($displayName)';
}

/// Google REST APIs needed to manage Firebase projects: the client, the
/// authentication and the projects of the Firebase Management API.
///
/// The other areas are extensions: hosting (sites, configuration, versions)
/// and cloud monitoring (usage).
class FirebaseManagerClient {
  /// Firebase Management API url.
  static const managementUrl = 'https://firebase.googleapis.com/v1beta1';

  /// Firebase Hosting API url.
  static const hostingUrl = 'https://firebasehosting.googleapis.com/v1beta1';

  /// Cloud Monitoring API url.
  static const monitoringUrl = 'https://monitoring.googleapis.com/v3';

  /// Access token provider.
  final GoogleAccessTokenProvider tokenProvider;
  final http.Client _client;
  final bool _ownClient;

  /// Client authenticated by [tokenProvider], [client] defaults to a new one
  /// closed by [close].
  FirebaseManagerClient({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client(),
      _ownClient = client == null;

  /// Send a request and return the json response, throws a
  /// [FirebaseRestException] on error.
  Future<Map<String, Object?>> sendJson(
    String method,
    String url, {
    Map<String, Object?>? body,
  }) async {
    var request = http.Request(method, Uri.parse(url));
    request.headers['Authorization'] =
        'Bearer ${await tokenProvider.getAccessToken()}';
    var quotaProjectId = tokenProvider.quotaProjectId;
    if (quotaProjectId != null) {
      request.headers['x-goog-user-project'] = quotaProjectId;
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    var response = await http.Response.fromStream(await _client.send(request));
    Object? json;
    try {
      json = response.body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(response.body);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var error = json is Map ? json['error'] : null;
      var message =
          (error is Map ? error['message'] as String? : null) ?? response.body;
      throw FirebaseRestException(response.statusCode, message);
    }
    return (json as Map).cast<String, Object?>();
  }

  /// All the items of the [field] list of a paginated GET [url] (that can
  /// already have query parameters).
  Future<List<Map<String, Object?>>> listAll(
    String url,
    String field, {
    int pageSize = 100,
  }) async {
    var items = <Map<String, Object?>>[];
    var separator = url.contains('?') ? '&' : '?';
    String? pageToken;
    do {
      var map = await sendJson(
        'GET',
        '$url${separator}pageSize=$pageSize'
            '${pageToken == null ? '' : '&pageToken=${Uri.encodeQueryComponent(pageToken)}'}',
      );
      items.addAll(
        ((map[field] as List?) ?? const []).map(
          (item) => (item as Map).cast<String, Object?>(),
        ),
      );
      pageToken = map['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return items;
  }

  /// Active Firebase projects the account can access, sorted by id.
  Future<List<FirebaseProjectInfo>> listProjects() async {
    var projects = (await listAll(
      '$managementUrl/projects',
      'results',
    )).map(FirebaseProjectInfo.fromJson).toList();
    projects.sort((a, b) => a.projectId.compareTo(b.projectId));
    return projects;
  }

  /// One Firebase project.
  Future<FirebaseProjectInfo> getProject(String projectId) async =>
      FirebaseProjectInfo.fromJson(
        await sendJson('GET', '$managementUrl/projects/$projectId'),
      );

  /// Close the http client if created here.
  void close() {
    if (_ownClient) {
      _client.close();
    }
  }
}
