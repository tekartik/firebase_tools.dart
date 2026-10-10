import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tekartik_firebase_tools_common/firebase_manager.dart';
import 'package:test/test.dart';

/// Fake hosting with site configs per `<projectId>/<siteId>`.
class _FakeHosting {
  final configs = <String, Map<String, Object?>>{};
  final patches = <String>[];

  late final client = FirebaseManagerClient(
    tokenProvider: GoogleAccessTokenProvider.function(() async => 'token'),
    client: MockClient(_handle),
  );

  Future<http.Response> _handle(http.Request request) async {
    expect(request.headers['Authorization'], 'Bearer token');
    var path = request.url.path;
    http.Response json(Object body) => http.Response(jsonEncode(body), 200);
    if (request.url.host == 'monitoring.googleapis.com') {
      var filter = request.url.queryParameters['filter']!;
      if (filter.contains('storage/total_bytes')) {
        Map<String, Object?> point(String time, int value) => {
          'interval': {'endTime': time},
          'value': {'int64Value': '$value'},
        };
        return json({
          'timeSeries': [
            {
              'resource': {
                'labels': {'site_name': 'p1', 'domain_name': 'p1'},
              },
              'points': [
                point('2026-10-10T10:00:00Z', 3000),
                point('2026-10-10T02:00:00Z', 2000),
              ],
            },
            {
              'resource': {
                'labels': {'site_name': 'p1-b'},
              },
              'points': [point('2026-10-10T10:00:00Z', 1000)],
            },
          ],
        });
      }
      return json({});
    }
    if (path.endsWith('/versions')) {
      Map<String, Object?> version(String id, String status, int bytes) => {
        'name': 'projects/p1/sites/p1/versions/$id',
        'status': status,
        'createTime': '2026-10-0${id.substring(1)}T10:00:00Z',
        'finalizeTime': '2026-10-0${id.substring(1)}T10:00:05Z',
        'createUser': {'email': 'alex@example.com'},
        'fileCount': '3',
        'versionBytes': '$bytes',
      };
      if (request.url.queryParameters['pageToken'] == null) {
        return json({
          'versions': [version('v1', 'FINALIZED', 100)],
          'nextPageToken': 'next',
        });
      }
      return json({
        'versions': [
          version('v3', 'FINALIZED', 300),
          version('v2', 'DELETED', 200),
        ],
      });
    }
    if (path == '/v1beta1/projects') {
      // 2 pages
      if (request.url.queryParameters['pageToken'] == null) {
        return json({
          'results': [
            {
              'projectId': 'p2',
              'resources': {'hostingSite': 'p2'},
            },
          ],
          'nextPageToken': 'next',
        });
      }
      return json({
        'results': [
          {'projectId': 'p1', 'displayName': 'Project 1'},
        ],
      });
    }
    var segments = request.url.pathSegments;
    // v1beta1/projects/<projectId>/sites[/<siteId>/config]
    var projectId = segments[2];
    if (segments.length == 4) {
      if (projectId == 'error') {
        return http.Response(
          jsonEncode({
            'error': {'message': 'denied'},
          }),
          403,
        );
      }
      var sites = configs.keys
          .where((key) => key.startsWith('$projectId/'))
          .map((key) => key.split('/').last)
          .toList();
      return json({
        'sites': [
          for (var site in sites)
            {
              'name': 'projects/$projectId/sites/$site',
              'type': site == projectId ? 'DEFAULT_SITE' : 'USER_SITE',
            },
        ],
      });
    }
    var key = '$projectId/${segments[4]}';
    if (request.method == 'PATCH') {
      expect(request.url.queryParameters['updateMask'], 'maxVersions');
      var body = (jsonDecode(request.body) as Map).cast<String, Object?>();
      patches.add('$key ${body['maxVersions']}');
      configs[key] = {...configs[key]!, ...body};
    }
    return json(configs[key]!);
  }
}

void main() {
  group('firebase_manager', () {
    test('config fromJson', () {
      expect(
        FirebaseHostingSiteConfig.fromJson({'maxVersions': '2'}).maxVersions,
        2,
      );
      expect(FirebaseHostingSiteConfig.fromJson({}).maxVersions, isNull);
      expect(
        FirebaseHostingSiteConfig.fromJson({'maxVersions': '0'}).maxVersions,
        isNull,
      );
    });
    test('target', () {
      expect(firebaseHostingMaxVersionsTarget(5), 5);
      expect(firebaseHostingMaxVersionsTarget(null, maxVersions: 2), 2);
      expect(firebaseHostingMaxVersionsTarget(1, maxVersions: 2), 2);
      expect(
        firebaseHostingMaxVersionsTarget(1, maxVersions: 2, limit: true),
        1,
      );
      expect(
        firebaseHostingMaxVersionsTarget(5, maxVersions: 2, limit: true),
        2,
      );
      expect(
        firebaseHostingMaxVersionsTarget(null, maxVersions: 2, limit: true),
        2,
      );
    });
    test('listProjects', () async {
      var hosting = _FakeHosting();
      var projects = await hosting.client.listProjects();
      expect(projects.map((project) => project.toString()), [
        'p1 (Project 1)',
        'p2',
      ]);
      expect(projects[1].hostingSite, 'p2');
    });
    test('getProject json', () {
      var project = FirebaseProjectInfo.fromJson({
        'projectId': 'p1',
        'projectNumber': '123',
        'displayName': 'Project 1',
        'resources': {'hostingSite': 'p1', 'storageBucket': 'p1.appspot.com'},
        'state': 'ACTIVE',
      });
      expect(project.storageBucket, 'p1.appspot.com');
      expect(
        FirebaseProjectInfo.fromJson(project.toJson()).toJson(),
        project.toJson(),
      );
    });
    test('listHostingVersions', () async {
      var hosting = _FakeHosting();
      var versions = await hosting.client.listHostingVersions(
        FirebaseHostingSiteInfo(projectId: 'p1', siteId: 'p1'),
      );
      expect(versions.map((version) => version.versionId), ['v3', 'v2', 'v1']);
      expect(versions.first.versionBytes, 300);
      expect(versions.first.createUserEmail, 'alex@example.com');
      var summary = FirebaseHostingVersionsSummary(versions);
      expect(summary.finalizedCount, 2);
      expect(summary.finalizedBytes, 400);
      expect(summary.lastFinalizeTime, DateTime.utc(2026, 10, 3, 10, 0, 5));
    });
    test('getHostingUsage', () async {
      var hosting = _FakeHosting();
      var usage = await hosting.client.getHostingUsage('p1');
      expect(usage.keys, ['p1', 'p1-b']);
      expect(usage['p1']!.storageBytes, 3000);
      expect(usage['p1']!.storageTime, DateTime.utc(2026, 10, 10, 10));
      expect(usage['p1']!.monthlySentBytes, isNull);
      expect(usage['p1-b']!.storageBytes, 1000);
    });
    test('limit, dry run and errors', () async {
      var hosting = _FakeHosting();
      hosting.configs.addAll({
        'p1/p1-b': {'maxVersions': '1'},
        'p1/p1': {},
        'p2/p2': {'maxVersions': '10', 'cloudLoggingEnabled': true},
      });
      var sites = await hosting.client.listHostingSites('p1');
      expect(sites.map((site) => site.siteId), ['p1', 'p1-b']);

      var lines = <String>[];
      var results = await firebaseHostingProjectsMaxVersionsLog(
        hosting.client,
        projectIds: ['p1', 'error', 'p2'],
        maxVersions: 2,
        limit: true,
        dryRun: true,
        log: lines.add,
      );
      expect(hosting.patches, isEmpty);
      expect(results.map((result) => result.name), [
        'p1/p1',
        'p1/p1-b',
        'error',
        'p2/p2',
      ]);
      expect(results.where((result) => result.changed).length, 2);
      expect(lines.first, startsWith('p1/p1 '));
      expect(lines.first, endsWith('unlimited -> 2 (dry run)'));
      expect(lines[2], contains('403'));
      expect(
        lines.last,
        '3 sites, errors 1, would change 2, '
        'before (1: 1, 10: 1, unlimited: 1), after (1: 1, 2: 2)',
      );

      results = await firebaseHostingProjectsMaxVersions(
        hosting.client,
        projectIds: ['p1', 'p2'],
        maxVersions: 2,
        limit: true,
      );
      expect(hosting.patches, ['p1/p1 2', 'p2/p2 2']);
      expect(results.where((result) => result.updated).length, 2);
      expect(hosting.configs['p2/p2']!['cloudLoggingEnabled'], isTrue);

      // Read only
      results = await firebaseHostingProjectsMaxVersions(
        hosting.client,
        projectIds: ['p1', 'p2'],
      );
      expect(results.map((result) => result.before), [2, 1, 2]);
      expect(results.where((result) => result.changed), isEmpty);
      expect(hosting.patches.length, 2);
    });
  });
}
