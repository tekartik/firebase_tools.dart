import 'package:pool/pool.dart';

import 'firebase_hosting_api.dart';
import 'firebase_manager_client.dart';

/// maxVersions of one site, before and after an update.
class FirebaseHostingSiteMaxVersions {
  /// Project id.
  final String projectId;

  /// Site, null when listing the project sites failed.
  final FirebaseHostingSiteInfo? site;

  /// Value before, null being unlimited.
  final int? before;

  /// Value after (or that would be set in dry run), null being unlimited.
  final int? after;

  /// True if the update was sent.
  final bool updated;

  /// Error reading or updating.
  final Object? error;

  /// maxVersions of one site.
  FirebaseHostingSiteMaxVersions({
    required this.projectId,
    this.site,
    this.before,
    this.after,
    this.updated = false,
    this.error,
  });

  /// True if the value changes (or would change in dry run).
  bool get changed => error == null && before != after;

  /// Site name (project/site).
  String get name => site?.toString() ?? projectId;

  /// One line description, [nameWidth] to align the values.
  String format({int nameWidth = 0}) {
    var buffer = StringBuffer(name.padRight(nameWidth));
    buffer.write('  ');
    if (error != null) {
      buffer.write('error: $error');
    } else {
      buffer.write(firebaseHostingMaxVersionsText(before));
      if (changed) {
        buffer.write(' -> ${firebaseHostingMaxVersionsText(after)}');
        if (!updated) {
          buffer.write(' (dry run)');
        }
      }
    }
    return buffer.toString();
  }

  @override
  String toString() => format();
}

/// The value to set for [current] (null being unlimited), [maxVersions] null
/// meaning read only.
///
/// When [limit] is true, only an unlimited or greater value is lowered.
int? firebaseHostingMaxVersionsTarget(
  int? current, {
  int? maxVersions,
  bool limit = false,
}) {
  if (maxVersions == null) {
    return current;
  }
  if (limit && current != null && current <= maxVersions) {
    return current;
  }
  return maxVersions;
}

/// Read and optionally update the maxVersions of all the hosting sites of
/// [projectIds].
///
/// [maxVersions] null only reads the current values. When [limit] is true,
/// only unlimited or greater values are lowered to [maxVersions]. Nothing is
/// written in [dryRun] mode.
///
/// [onProject] is called with the results of each project, in [projectIds]
/// order, as soon as available.
Future<List<FirebaseHostingSiteMaxVersions>> firebaseHostingProjectsMaxVersions(
  FirebaseManagerClient client, {
  required List<String> projectIds,
  int? maxVersions,
  bool limit = false,
  bool dryRun = false,
  int concurrency = 8,
  void Function(List<FirebaseHostingSiteMaxVersions> results)? onProject,
}) async {
  var pool = Pool(concurrency);
  try {
    var futures = projectIds
        .map(
          (projectId) => pool.withResource(
            () => _projectMaxVersions(
              client,
              projectId,
              maxVersions: maxVersions,
              limit: limit,
              dryRun: dryRun,
            ),
          ),
        )
        .toList();
    var allResults = <FirebaseHostingSiteMaxVersions>[];
    // Awaited in order while running concurrently.
    for (var future in futures) {
      var results = await future;
      onProject?.call(results);
      allResults.addAll(results);
    }
    return allResults;
  } finally {
    await pool.close();
  }
}

Future<List<FirebaseHostingSiteMaxVersions>> _projectMaxVersions(
  FirebaseManagerClient client,
  String projectId, {
  int? maxVersions,
  required bool limit,
  required bool dryRun,
}) async {
  List<FirebaseHostingSiteInfo> sites;
  try {
    sites = await client.listHostingSites(projectId);
  } catch (e) {
    return [FirebaseHostingSiteMaxVersions(projectId: projectId, error: e)];
  }
  var results = <FirebaseHostingSiteMaxVersions>[];
  for (var site in sites) {
    int? before;
    try {
      before = (await client.getHostingSiteConfig(site)).maxVersions;
      var target = firebaseHostingMaxVersionsTarget(
        before,
        maxVersions: maxVersions,
        limit: limit,
      );
      var after = target;
      var updated = false;
      if (target != null && target != before && !dryRun) {
        after = (await client.setHostingSiteMaxVersions(
          site,
          target,
        )).maxVersions;
        updated = true;
      }
      results.add(
        FirebaseHostingSiteMaxVersions(
          projectId: projectId,
          site: site,
          before: before,
          after: after,
          updated: updated,
        ),
      );
    } catch (e) {
      results.add(
        FirebaseHostingSiteMaxVersions(
          projectId: projectId,
          site: site,
          before: before,
          after: before,
          error: e,
        ),
      );
    }
  }
  return results;
}

/// [firebaseHostingProjectsMaxVersions] writing one line per site with [log],
/// then a summary.
Future<List<FirebaseHostingSiteMaxVersions>>
firebaseHostingProjectsMaxVersionsLog(
  FirebaseManagerClient client, {
  required List<String> projectIds,
  int? maxVersions,
  bool limit = false,
  bool dryRun = false,
  required void Function(String line) log,
}) async {
  var results = await firebaseHostingProjectsMaxVersions(
    client,
    projectIds: projectIds,
    maxVersions: maxVersions,
    limit: limit,
    dryRun: dryRun,
    onProject: (results) {
      for (var result in results) {
        log(result.format(nameWidth: 40));
      }
    },
  );
  log(firebaseHostingMaxVersionsSummary(results, dryRun: dryRun));
  return results;
}

String _countsText(Iterable<int?> values) {
  var counts = <int?, int>{};
  for (var value in values) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  // unlimited last
  var keys = counts.keys.toList()
    ..sort((a, b) {
      if (a == null || b == null) {
        return a == b ? 0 : (a == null ? 1 : -1);
      }
      return a.compareTo(b);
    });
  return keys
      .map((key) => '${firebaseHostingMaxVersionsText(key)}: ${counts[key]}')
      .join(', ');
}

/// Summary line of [results].
String firebaseHostingMaxVersionsSummary(
  List<FirebaseHostingSiteMaxVersions> results, {
  bool dryRun = false,
}) {
  var sites = results.where((result) => result.site != null).length;
  var changed = results.where((result) => result.changed).length;
  var errors = results.where((result) => result.error != null).length;
  var valid = results.where((result) => result.error == null).toList();
  var buffer = StringBuffer('$sites sites, errors $errors, ');
  if (changed == 0) {
    buffer.write('values (${_countsText(valid.map((r) => r.before))})');
  } else {
    buffer.write(
      '${dryRun ? 'would change' : 'changed'} $changed, '
      'before (${_countsText(valid.map((r) => r.before))}), '
      'after (${_countsText(valid.map((r) => r.after))})',
    );
  }
  return buffer.toString();
}
