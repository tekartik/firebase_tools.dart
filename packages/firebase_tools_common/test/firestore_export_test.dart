@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_firebase_tools_common/firestore_export.dart';
import 'package:test/test.dart';

/// A firebase folder under the test out directory, holding [files].
String _newFirebaseFolder(String name, Map<String, String> files) {
  var path = join('.dart_tool', 'tekartik_firebase_tools', 'test', name);
  var directory = Directory(path);
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
  directory.createSync(recursive: true);
  files.forEach((fileName, content) {
    File(join(path, fileName))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  });
  return path;
}

void main() {
  test('firebaseDefaultStorageBucket', () {
    expect(
      firebaseDefaultStorageBucket('my_project'),
      'my_project.firebasestorage.app',
    );
  });

  test('firestoreBackupBucket', () {
    expect(firestoreBackupBucket('my_project'), 'my_project-backup');
  });

  group('firestoreExportLocationMatches', () {
    bool matches(String bucket, String database) =>
        firestoreExportLocationMatches(
          bucketLocation: bucket,
          databaseLocation: database,
        );

    test('the same location', () {
      expect(matches('europe-west9', 'europe-west9'), isTrue);
    });

    test('gcloud prints the bucket location in upper case', () {
      expect(matches('EUROPE-WEST9', 'europe-west9'), isTrue);
      expect(matches(' EUROPE-WEST9 ', 'europe-west9'), isTrue);
    });

    test('the multi region holding the database', () {
      expect(matches('eu', 'europe-west9'), isTrue);
      expect(matches('EU', 'eur3'), isTrue);
      expect(matches('us', 'us-west1'), isTrue);
      expect(matches('US', 'nam5'), isTrue);
      expect(matches('asia', 'asia-east1'), isTrue);
    });

    test('another location does not match', () {
      // The playelio case: the default firebase bucket in us-west1, the
      // database in europe-west9.
      expect(matches('US-WEST1', 'europe-west9'), isFalse);
      expect(matches('europe-west1', 'europe-west9'), isFalse);
      expect(matches('eu', 'us-west1'), isFalse);
      expect(matches('us', 'europe-west9'), isFalse);
    });

    test('a region is not the multi region of another one', () {
      expect(matches('europe-west9', 'eu'), isFalse);
    });

    test('an empty location never matches', () {
      expect(matches('', 'europe-west9'), isFalse);
      expect(matches('eu', ''), isFalse);
    });
  });

  group('location and bucket commands', () {
    test('firestoreDatabaseLocationCommand', () {
      expect(
        firestoreDatabaseLocationCommand(projectId: 'my_project'),
        'gcloud firestore databases describe --project my_project'
        ' --format=value(locationId)',
      );
      expect(
        firestoreDatabaseLocationCommand(
          projectId: 'my_project',
          database: 'other',
        ),
        'gcloud firestore databases describe --project my_project'
        ' --database=other --format=value(locationId)',
      );
    });

    test('storageBucketLocationCommand', () {
      expect(
        storageBucketLocationCommand(
          bucket: 'my-backup',
          projectId: 'my_project',
        ),
        'gcloud storage buckets describe gs://my-backup'
        ' --project my_project --format=value(location)',
      );
      expect(
        storageBucketLocationCommand(
          bucket: 'gs://my-backup',
          projectId: 'my_project',
        ),
        'gcloud storage buckets describe gs://my-backup'
        ' --project my_project --format=value(location)',
      );
    });

    test('storageListCommand', () {
      expect(
        storageListCommand(
          uri: 'gs://my-backup/firestore-export/',
          projectId: 'my_project',
        ),
        'gcloud storage ls gs://my-backup/firestore-export/'
        ' --project my_project',
      );
    });

    test('storageSizeCommand', () {
      expect(
        storageSizeCommand(
          uri: 'gs://my-backup/firestore-export/one',
          projectId: 'my_project',
        ),
        'gcloud storage du --summarize gs://my-backup/firestore-export/one'
        ' --project my_project',
      );
    });

    test('storageUsageCommand', () {
      expect(
        storageUsageCommand(
          uri: 'gs://my-backup/firestore-export/one',
          projectId: 'my_project',
        ),
        'gcloud storage du gs://my-backup/firestore-export/one'
        ' --project my_project',
      );
    });

    test('firestoreOperationsListCommand', () {
      expect(
        firestoreOperationsListCommand(projectId: 'my_project'),
        'gcloud firestore operations list --project my_project --format=json',
      );
      expect(
        firestoreOperationsListCommand(
          projectId: 'my_project',
          database: 'other',
          limit: 10,
        ),
        'gcloud firestore operations list --project my_project'
        ' --database=other --limit 10 --format=json',
      );
    });

    test('storageBucketCreateCommand', () {
      expect(
        storageBucketCreateCommand(
          bucket: 'my-backup',
          projectId: 'my_project',
          location: 'europe-west9',
        ),
        'gcloud storage buckets create gs://my-backup'
        ' --project my_project --location=europe-west9',
      );
    });
  });

  group('storageListingNames', () {
    test('the folders of a listing, sorted', () {
      // What `gcloud storage ls gs://playelio-backup/firestore-export/`
      // prints.
      expect(
        storageListingNames(
          'gs://playelio-backup/firestore-export/2026-09-22T09-34-25Z/\n'
          'gs://playelio-backup/firestore-export/2026-09-22T09-31-19Z/\n',
        ),
        ['2026-09-22T09-31-19Z', '2026-09-22T09-34-25Z'],
      );
    });

    test('the dates sort so the latest export is last', () {
      var names = storageListingNames(
        'gs://b/p/2026-01-02T03-04-05Z/\n'
        'gs://b/p/2026-09-22T09-31-19Z/\n'
        'gs://b/p/2025-12-31T23-59-59Z/\n',
      );
      expect(names.last, '2026-09-22T09-31-19Z');
      expect(names.first, '2025-12-31T23-59-59Z');
    });

    test('a file, with no trailing slash, counts too', () {
      expect(storageListingNames('gs://b/p/one'), ['one']);
    });

    test('the bucket itself is not a name', () {
      expect(storageListingNames('gs://b/'), isEmpty);
      expect(storageListingNames('gs://b'), isEmpty);
    });

    test('empty and non uri lines are ignored', () {
      expect(storageListingNames('\n  \ngs://b/p/one/\nnot a uri\n'), ['one']);
      expect(storageListingNames(''), isEmpty);
    });
  });

  group('storageSizeFromDu', () {
    test('the byte count of a summarized du', () {
      // What `gcloud storage du --summarize` prints.
      expect(
        storageSizeFromDu(
          '84045        gs://playelio-backup/firestore-export/'
          '2026-09-22T09-31-19Z\n',
        ),
        84045,
      );
    });

    test('a folder holding nothing prints nothing', () {
      expect(storageSizeFromDu(''), isNull);
      expect(storageSizeFromDu('\n  \n'), isNull);
    });

    test('a line that is no size is skipped', () {
      expect(storageSizeFromDu('WARNING: something\n12 gs://b/p\n'), 12);
    });
  });

  group('storageUsageFromDu', () {
    // What `gcloud storage du <export>` prints: one line per object, then a
    // cumulative line per directory walked through, the listed folder
    // included.
    const output = '''
97           gs://b/p/2026-09-22T09-34-25Z/2026-09-22T09-34-25Z.overall_export_metadata
115          gs://b/p/2026-09-22T09-34-25Z/all_namespaces/all_kinds/all_namespaces_all_kinds.export_metadata
6157         gs://b/p/2026-09-22T09-34-25Z/all_namespaces/all_kinds/output-0
49034        gs://b/p/2026-09-22T09-34-25Z/all_namespaces/all_kinds/output-1
21795        gs://b/p/2026-09-22T09-34-25Z/all_namespaces/all_kinds/output-2
6847         gs://b/p/2026-09-22T09-34-25Z/all_namespaces/all_kinds/output-3
83948        gs://b/p/2026-09-22T09-34-25Z/all_namespaces/all_kinds/
83948        gs://b/p/2026-09-22T09-34-25Z/all_namespaces/
84045        gs://b/p/2026-09-22T09-34-25Z/
''';

    test('counts the objects, not the directories', () {
      var usage = storageUsageFromDu(output);
      expect(usage.fileCount, 6);
    });

    test('the total matches the summarized du', () {
      // The directory lines are cumulative: summing them in would count
      // every object several times.
      expect(storageUsageFromDu(output).size, 84045);
      expect(storageSizeFromDu('84045   gs://b/p/2026-09-22T09-34-25Z'), 84045);
    });

    test('an empty folder is no file and no byte', () {
      var usage = storageUsageFromDu('');
      expect(usage.fileCount, 0);
      expect(usage.size, 0);
    });

    test('a line that is no object is skipped', () {
      // `--total` adds a `total` line with no uri.
      var usage = storageUsageFromDu(
        'WARNING: something\n12 gs://b/p/one\n12        total\n',
      );
      expect(usage.fileCount, 1);
      expect(usage.size, 12);
    });
  });

  group('firestoreExportOperationsFromJson', () {
    // What `gcloud firestore operations list --format=json` prints.
    const output = '''
[
  {
    "done": true,
    "metadata": {
      "@type": "type.googleapis.com/google.firestore.admin.v1.ExportDocumentsMetadata",
      "endTime": "2026-09-22T09:32:01.071825Z",
      "operationState": "SUCCESSFUL",
      "outputUriPrefix": "gs://playelio-backup/firestore-export/2026-09-22T09-31-19Z",
      "progressBytes": {"completedWork": "82419", "estimatedWork": "75487"},
      "progressDocuments": {"completedWork": "201", "estimatedWork": "201"},
      "startTime": "2026-09-22T09:31:19.773243Z"
    },
    "name": "projects/playelio/databases/(default)/operations/abc"
  }
]
''';

    test('reads the export of one operation', () {
      var operations = firestoreExportOperationsFromJson(output);
      expect(operations, hasLength(1));
      var operation = operations.first;
      expect(
        operation.uri,
        'gs://playelio-backup/firestore-export/2026-09-22T09-31-19Z',
      );
      expect(operation.state, 'SUCCESSFUL');
      expect(operation.successful, isTrue);
      // Sent as json strings.
      expect(operation.documentCount, 201);
      expect(operation.byteCount, 82419);
    });

    test('an operation that is no export is left out', () {
      expect(
        firestoreExportOperationsFromJson(
          '[{"metadata": {"operationState": "PROCESSING"}}]',
        ),
        isEmpty,
      );
    });

    test('a running export is not successful', () {
      var operations = firestoreExportOperationsFromJson(
        '[{"metadata": {"operationState": "PROCESSING",'
        ' "outputUriPrefix": "gs://b/p/one"}}]',
      );
      expect(operations.single.state, 'PROCESSING');
      expect(operations.single.successful, isFalse);
      expect(operations.single.documentCount, isNull);
    });

    test('a malformed output is no operation rather than a throw', () {
      expect(firestoreExportOperationsFromJson('not json'), isEmpty);
      expect(firestoreExportOperationsFromJson('{}'), isEmpty);
      expect(firestoreExportOperationsFromJson('[]'), isEmpty);
      expect(firestoreExportOperationsFromJson('[1, "a"]'), isEmpty);
    });
  });

  group('storageSizeText', () {
    test('bytes', () {
      expect(storageSizeText(0), '0 B');
      expect(storageSizeText(1), '1 B');
      expect(storageSizeText(1023), '1023 B');
    });

    test('one decimal below 100, none above', () {
      expect(storageSizeText(84045), '82.1 KiB');
      expect(storageSizeText(1024), '1.0 KiB');
      expect(storageSizeText(1024 * 100), '100 KiB');
      expect(storageSizeText(1024 * 1024), '1.0 MiB');
      expect(storageSizeText(1024 * 1024 * 1024 * 3 ~/ 2), '1.5 GiB');
    });

    test('stops at the largest unit', () {
      expect(storageSizeText(1 << 50), '1.0 PiB');
    });
  });

  group('gsBucketUri', () {
    test('the bucket alone', () {
      expect(gsBucketUri('my-bucket'), 'gs://my-bucket');
      expect(gsBucketUri('gs://my-bucket'), 'gs://my-bucket');
    });

    test('a path in the bucket', () {
      expect(gsBucketUri('my-bucket', 'a/b'), 'gs://my-bucket/a/b');
      expect(gsBucketUri('gs://my-bucket', 'a/b'), 'gs://my-bucket/a/b');
    });

    test('an empty path is the bucket root', () {
      expect(gsBucketUri('my-bucket', ''), 'gs://my-bucket');
      expect(gsBucketUri('my-bucket', '/'), 'gs://my-bucket');
      expect(gsBucketUri('my-bucket', null), 'gs://my-bucket');
    });

    test('slashes are normalized', () {
      expect(gsBucketUri('my-bucket/', '/a//b/'), 'gs://my-bucket/a/b');
      expect(gsBucketUri('gs://my-bucket/base', 'a'), 'gs://my-bucket/base/a');
    });

    test('throws without a bucket name', () {
      expect(() => gsBucketUri(''), throwsArgumentError);
      expect(() => gsBucketUri('gs://'), throwsArgumentError);
    });
  });

  group('firestoreExportName', () {
    test('is the utc date, file system safe', () {
      expect(
        firestoreExportName(DateTime.utc(2026, 9, 22, 10, 30)),
        '2026-09-22T10-30-00Z',
      );
      expect(
        firestoreExportName(DateTime.utc(2026, 1, 2, 3, 4, 5)),
        '2026-01-02T03-04-05Z',
      );
    });

    test('a local date is converted to utc', () {
      var local = DateTime.utc(2026, 9, 22, 10, 30).toLocal();
      expect(firestoreExportName(local), '2026-09-22T10-30-00Z');
    });
  });

  group('firestoreCollectionIdsArgument', () {
    test('null or empty exports everything', () {
      expect(firestoreCollectionIdsArgument(null), '');
      expect(firestoreCollectionIdsArgument([]), '');
    });

    test('joins the ids', () {
      expect(firestoreCollectionIdsArgument(['a']), ' --collection-ids=a');
      expect(
        firestoreCollectionIdsArgument(['a', 'b']),
        ' --collection-ids=a,b',
      );
    });
  });

  group('firestoreExportCommand', () {
    test('exports the whole database', () {
      expect(
        firestoreExportCommand(
          projectId: 'my_project',
          uri: 'gs://my-bucket/firestore-export/2026-09-22T10-30-00Z',
        ),
        'gcloud firestore export '
        'gs://my-bucket/firestore-export/2026-09-22T10-30-00Z '
        '--project my_project',
      );
    });

    test('restricts to collections', () {
      expect(
        firestoreExportCommand(
          projectId: 'my_project',
          uri: 'gs://my-bucket',
          collectionIds: ['note', 'user'],
        ),
        'gcloud firestore export gs://my-bucket --project my_project'
        ' --collection-ids=note,user',
      );
    });

    test('names a database and goes async', () {
      expect(
        firestoreExportCommand(
          projectId: 'my_project',
          uri: 'gs://my-bucket',
          database: 'other',
          async: true,
        ),
        'gcloud firestore export gs://my-bucket --project my_project'
        ' --database=other --async',
      );
      expect(
        firestoreExportCommand(
          projectId: 'my_project',
          uri: 'gs://my-bucket',
          async: false,
        ),
        'gcloud firestore export gs://my-bucket --project my_project',
      );
    });
  });

  group('firestoreImportCommand', () {
    test('imports one export folder', () {
      expect(
        firestoreImportCommand(
          projectId: 'my_project',
          uri: 'gs://my-bucket/firestore-export/2026-09-22T10-30-00Z',
        ),
        'gcloud firestore import '
        'gs://my-bucket/firestore-export/2026-09-22T10-30-00Z '
        '--project my_project',
      );
    });

    test('restricts to collections', () {
      expect(
        firestoreImportCommand(
          projectId: 'my_project',
          uri: 'gs://my-bucket/one',
          collectionIds: ['note'],
        ),
        'gcloud firestore import gs://my-bucket/one --project my_project'
        ' --collection-ids=note',
      );
    });
  });

  group('FirestoreExportOptions', () {
    test('defaults to the backup bucket of the project', () {
      var options = FirestoreExportOptions(projectId: 'my_project');
      expect(options.projectId, 'my_project');
      expect(options.bucket, 'my_project-backup');
      expect(options.bucketPath, 'firestore-export');
      expect(options.collectionIds, isNull);
      expect(options.database, isNull);
      expect(options.bucketLocation, isNull);
      expect(options.uri, 'gs://my_project-backup/firestore-export');
    });

    test('a bucket of its own, at the root', () {
      var options = FirestoreExportOptions(
        projectId: 'my_project',
        bucket: 'gs://my-backup',
        bucketPath: '',
      );
      expect(options.uri, 'gs://my-backup');
    });

    test('copyWith overrides only what it is given', () {
      var options = FirestoreExportOptions(
        projectId: 'my_project',
        bucketPath: 'backup',
        collectionIds: ['note'],
        bucketLocation: 'eu',
      );
      var copy = options.copyWith(projectId: 'other');
      expect(copy.projectId, 'other');
      // The bucket was resolved from the first project id, and kept.
      expect(copy.bucket, 'my_project-backup');
      expect(copy.bucketPath, 'backup');
      expect(copy.collectionIds, ['note']);
      expect(copy.bucketLocation, 'eu');
    });

    test('firebaseFolder reads the project id', () {
      var path = _newFirebaseFolder('export_options', {
        'firebase.json': '{}',
        '.firebaserc': '{"projects": {"default": "my_project"}}',
      });
      var options = FirestoreExportOptions.firebaseFolder(
        path: path,
        bucketLocation: 'eu',
      );
      expect(options.projectId, 'my_project');
      expect(options.bucketLocation, 'eu');
      expect(options.uri, 'gs://my_project-backup/firestore-export');
    });

    test('firebaseFolder throws without a default project', () {
      var path = _newFirebaseFolder('export_options_no_project', {
        'firebase.json': '{}',
      });
      expect(
        () => FirestoreExportOptions.firebaseFolder(path: path),
        throwsStateError,
      );
    });
  });

  group('FirestoreExporter', () {
    test('exportUri is the name under the export folder', () {
      var exporter = FirestoreExporter(
        options: FirestoreExportOptions(projectId: 'my_project'),
      );
      expect(
        exporter.exportUri('2026-09-22T10-30-00Z'),
        'gs://my_project-backup/firestore-export/2026-09-22T10-30-00Z',
      );
    });

    test('exportUri of a bucket root', () {
      var exporter = FirestoreExporter(
        options: FirestoreExportOptions(
          projectId: 'my_project',
          bucket: 'my-backup',
          bucketPath: '',
        ),
      );
      expect(exporter.exportUri('one'), 'gs://my-backup/one');
    });

    test('is verbose by default', () {
      var options = FirestoreExportOptions(projectId: 'my_project');
      expect(FirestoreExporter(options: options).verbose, isTrue);
      expect(
        FirestoreExporter(options: options, verbose: false).verbose,
        isFalse,
      );
    });
  });
}
