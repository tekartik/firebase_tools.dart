import 'firebase_manager_client.dart';

/// A Firebase Hosting site.
class FirebaseHostingSiteInfo {
  /// Project id.
  final String projectId;

  /// Site id.
  final String siteId;

  /// Default url (`https://<siteId>.web.app`).
  final String? defaultUrl;

  /// DEFAULT_SITE or USER_SITE.
  final String? type;

  /// A Firebase Hosting site.
  FirebaseHostingSiteInfo({
    required this.projectId,
    required this.siteId,
    this.defaultUrl,
    this.type,
  });

  /// From the REST json, name is `projects/<projectId>/sites/<siteId>`.
  factory FirebaseHostingSiteInfo.fromJson(
    String projectId,
    Map<String, Object?> json,
  ) => FirebaseHostingSiteInfo(
    projectId: projectId,
    siteId: (json['name'] as String).split('/').last,
    defaultUrl: json['defaultUrl'] as String?,
    type: json['type'] as String?,
  );

  /// True for the project default site.
  bool get isDefault => type == 'DEFAULT_SITE';

  @override
  String toString() => '$projectId/$siteId';
}

/// Hosting site configuration.
class FirebaseHostingSiteConfig {
  /// Number of finalized versions kept, null when unlimited (the default).
  final int? maxVersions;

  /// Whether the requests are logged with Cloud Logging.
  final bool? cloudLoggingEnabled;

  /// Hosting site configuration.
  FirebaseHostingSiteConfig({this.maxVersions, this.cloudLoggingEnabled});

  /// From the REST json, maxVersions is an int64 sent as a string.
  factory FirebaseHostingSiteConfig.fromJson(Map<String, Object?> json) {
    var maxVersions = int.tryParse(json['maxVersions']?.toString() ?? '');
    return FirebaseHostingSiteConfig(
      // 0 or missing means unlimited.
      maxVersions: (maxVersions ?? 0) > 0 ? maxVersions : null,
      cloudLoggingEnabled: json['cloudLoggingEnabled'] as bool?,
    );
  }

  @override
  String toString() =>
      'maxVersions: ${firebaseHostingMaxVersionsText(maxVersions)}'
      '${cloudLoggingEnabled == null ? '' : ', cloudLogging: $cloudLoggingEnabled'}';
}

/// A deployed hosting version.
class FirebaseHostingVersionInfo {
  /// Version id.
  final String versionId;

  /// CREATED, FINALIZED, DELETED, ABANDONED, EXPIRED or CLONING.
  final String? status;

  /// Creation time.
  final DateTime? createTime;

  /// Finalization time.
  final DateTime? finalizeTime;

  /// Email of the user who created it.
  final String? createUserEmail;

  /// Number of files.
  final int? fileCount;

  /// Total size of the files.
  final int? versionBytes;

  /// A deployed hosting version.
  FirebaseHostingVersionInfo({
    required this.versionId,
    this.status,
    this.createTime,
    this.finalizeTime,
    this.createUserEmail,
    this.fileCount,
    this.versionBytes,
  });

  /// From the REST json, name is `.../versions/<versionId>`.
  factory FirebaseHostingVersionInfo.fromJson(Map<String, Object?> json) {
    DateTime? time(String key) =>
        DateTime.tryParse(json[key]?.toString() ?? '');
    int? integer(String key) => int.tryParse(json[key]?.toString() ?? '');
    return FirebaseHostingVersionInfo(
      versionId: (json['name'] as String).split('/').last,
      status: json['status'] as String?,
      createTime: time('createTime'),
      finalizeTime: time('finalizeTime'),
      createUserEmail: (json['createUser'] as Map?)?['email'] as String?,
      fileCount: integer('fileCount'),
      versionBytes: integer('versionBytes'),
    );
  }

  /// True if finalized (deployed, kept in storage).
  bool get isFinalized => status == 'FINALIZED';
}

/// Summary of the versions of a site.
class FirebaseHostingVersionsSummary {
  /// Finalized versions count (the ones kept in storage).
  final int finalizedCount;

  /// Total size of the finalized versions.
  final int finalizedBytes;

  /// Most recent finalized version time.
  final DateTime? lastFinalizeTime;

  /// Summary of [versions].
  factory FirebaseHostingVersionsSummary(
    Iterable<FirebaseHostingVersionInfo> versions,
  ) {
    var finalized = versions.where((version) => version.isFinalized).toList();
    DateTime? last;
    for (var version in finalized) {
      var time = version.finalizeTime ?? version.createTime;
      if (time != null && (last == null || time.isAfter(last))) {
        last = time;
      }
    }
    return FirebaseHostingVersionsSummary._(
      finalized.length,
      finalized.fold(0, (sum, version) => sum + (version.versionBytes ?? 0)),
      last,
    );
  }

  FirebaseHostingVersionsSummary._(
    this.finalizedCount,
    this.finalizedBytes,
    this.lastFinalizeTime,
  );
}

/// maxVersions for display, null being unlimited.
String firebaseHostingMaxVersionsText(int? maxVersions) =>
    maxVersions?.toString() ?? 'unlimited';

/// Firebase Hosting REST API (v1beta1).
extension FirebaseManagerClientHostingExt on FirebaseManagerClient {
  /// Hosting sites of a project, default site first.
  Future<List<FirebaseHostingSiteInfo>> listHostingSites(
    String projectId,
  ) async {
    var sites =
        (await listAll(
              '${FirebaseManagerClient.hostingUrl}/projects/$projectId/sites',
              'sites',
            ))
            .map((json) => FirebaseHostingSiteInfo.fromJson(projectId, json))
            .toList();
    sites.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return a.siteId.compareTo(b.siteId);
    });
    return sites;
  }

  String _siteUrl(FirebaseHostingSiteInfo site) =>
      '${FirebaseManagerClient.hostingUrl}/projects/${site.projectId}/sites/${site.siteId}';

  /// Site configuration.
  Future<FirebaseHostingSiteConfig> getHostingSiteConfig(
    FirebaseHostingSiteInfo site,
  ) async => FirebaseHostingSiteConfig.fromJson(
    await sendJson('GET', '${_siteUrl(site)}/config'),
  );

  /// Set the number of finalized versions kept (>= 1), older ones are
  /// deleted on the next deploy.
  Future<FirebaseHostingSiteConfig> setHostingSiteMaxVersions(
    FirebaseHostingSiteInfo site,
    int maxVersions,
  ) async {
    if (maxVersions < 1) {
      throw ArgumentError.value(maxVersions, 'maxVersions', 'must be >= 1');
    }
    return FirebaseHostingSiteConfig.fromJson(
      await sendJson(
        'PATCH',
        '${_siteUrl(site)}/config?updateMask=maxVersions',
        body: {'maxVersions': maxVersions.toString()},
      ),
    );
  }

  /// All the versions of a site, most recent first.
  Future<List<FirebaseHostingVersionInfo>> listHostingVersions(
    FirebaseHostingSiteInfo site,
  ) async {
    var versions = (await listAll(
      '${_siteUrl(site)}/versions',
      'versions',
    )).map(FirebaseHostingVersionInfo.fromJson).toList();
    var epoch = DateTime.fromMillisecondsSinceEpoch(0);
    versions.sort(
      (a, b) => (b.createTime ?? epoch).compareTo(a.createTime ?? epoch),
    );
    return versions;
  }
}
