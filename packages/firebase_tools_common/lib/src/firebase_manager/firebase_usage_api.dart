import 'firebase_manager_client.dart';

/// Hosting usage of a site, from cloud monitoring.
class FirebaseHostingSiteUsage {
  /// Site id.
  final String siteId;

  /// Storage used (all the versions kept), null if not reported.
  final int? storageBytes;

  /// Time of [storageBytes] (measured a few times a day).
  final DateTime? storageTime;

  /// Bytes sent this month, null if not reported.
  final int? monthlySentBytes;

  /// Hosting usage of a site.
  FirebaseHostingSiteUsage({
    required this.siteId,
    this.storageBytes,
    this.storageTime,
    this.monthlySentBytes,
  });

  FirebaseHostingSiteUsage _copyWith({
    int? storageBytes,
    DateTime? storageTime,
    int? monthlySentBytes,
  }) => FirebaseHostingSiteUsage(
    siteId: siteId,
    storageBytes: storageBytes ?? this.storageBytes,
    storageTime: storageTime ?? this.storageTime,
    monthlySentBytes: monthlySentBytes ?? this.monthlySentBytes,
  );
}

/// Latest value per site of a time series list (points are newest first).
Map<String, ({int value, DateTime? time})> _latestPerSite(
  Map<String, Object?> json,
) {
  var values = <String, ({int value, DateTime? time})>{};
  for (var series in (json['timeSeries'] as List?) ?? const []) {
    var map = (series as Map).cast<String, Object?>();
    var labels = ((map['resource'] as Map?)?['labels'] as Map?)
        ?.cast<String, Object?>();
    var siteId = (labels?['site_name'] ?? labels?['domain_name']) as String?;
    var points = (map['points'] as List?) ?? const [];
    if (siteId == null || points.isEmpty) {
      continue;
    }
    var point = (points.first as Map).cast<String, Object?>();
    var value = int.tryParse(
      (point['value'] as Map?)?['int64Value']?.toString() ?? '',
    );
    if (value == null) {
      continue;
    }
    var time = DateTime.tryParse(
      (point['interval'] as Map?)?['endTime']?.toString() ?? '',
    );
    var existing = values[siteId];
    if (existing == null ||
        (time != null &&
            (existing.time == null || time.isAfter(existing.time!)))) {
      values[siteId] = (value: value, time: time);
    }
  }
  return values;
}

/// Cloud Monitoring REST API (v3), the usage metrics of Firebase.
extension FirebaseManagerClientUsageExt on FirebaseManagerClient {
  /// Time series of a metric type for a project, between [start] and now.
  Future<Map<String, Object?>> getMetricTimeSeries(
    String projectId,
    String metricType, {
    required DateTime start,
  }) {
    var query = Uri(
      queryParameters: {
        'filter': 'metric.type = "$metricType"',
        'interval.startTime': start.toUtc().toIso8601String(),
        'interval.endTime': DateTime.now().toUtc().toIso8601String(),
      },
    ).query;
    return sendJson(
      'GET',
      '${FirebaseManagerClient.monitoringUrl}/projects/$projectId/timeSeries?$query',
    );
  }

  /// Hosting usage per site id: the storage (latest measure of the last 3
  /// days) and the bytes sent this month when reported.
  Future<Map<String, FirebaseHostingSiteUsage>> getHostingUsage(
    String projectId,
  ) async {
    var now = DateTime.now().toUtc();
    var storage = _latestPerSite(
      await getMetricTimeSeries(
        projectId,
        'firebasehosting.googleapis.com/storage/total_bytes',
        start: now.subtract(const Duration(days: 3)),
      ),
    );
    var sent = _latestPerSite(
      await getMetricTimeSeries(
        projectId,
        'firebasehosting.googleapis.com/network/monthly_sent',
        start: DateTime.utc(now.year, now.month),
      ),
    );
    var usages = <String, FirebaseHostingSiteUsage>{};
    for (var entry in storage.entries) {
      usages[entry.key] = FirebaseHostingSiteUsage(
        siteId: entry.key,
        storageBytes: entry.value.value,
        storageTime: entry.value.time,
      );
    }
    for (var entry in sent.entries) {
      usages[entry.key] =
          (usages[entry.key] ?? FirebaseHostingSiteUsage(siteId: entry.key))
              ._copyWith(monthlySentBytes: entry.value.value);
    }
    return usages;
  }
}
