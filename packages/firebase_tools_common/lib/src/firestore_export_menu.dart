import 'package:dev_build/menu/menu.dart';

import 'firestore_export.dart';

/// The `prompt` answer [value], trimmed, or `null` when it was left empty —
/// which every item takes as a cancellation.
String? _promptValue(String value) {
  var trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// The collection ids of the comma separated [value].
List<String> _collectionIds(String value) => value
    .split(',')
    .map((id) => id.trim())
    .where((id) => id.isNotEmpty)
    .toList();

/// Registers the dev-menu items exporting the firestore database [exporter]
/// points at to its bucket, and importing an export back.
///
/// Everything runs the `gcloud` cli, which must be logged in on an account
/// allowed to export the project and to write to the bucket. Every export
/// checks the bucket first and creates it when it is missing, since firestore
/// only exports to a bucket in the location of the database. The last export
/// of the session is remembered, so `import` needs no uri, and `list exports`
/// shows the ones already in the bucket whoever wrote them.
void menuFirestoreExportContent({required FirestoreExporter exporter}) {
  var options = exporter.options;
  String? lastUri;

  enter(() async {
    write('Firestore of ${options.projectId}');
    write('Exports to: ${options.uri}/<date>');
    write('Collections: ${options.collectionIds?.join(', ') ?? '<all>'}');
    if (options.database != null) {
      write('Database: ${options.database}');
    }
    write('Last export: ${lastUri ?? '<none this session>'}');
  });

  Future<void> exportTo({List<String>? collectionIds, bool? async}) async {
    // Creates the bucket when missing, and reports a location mismatch as
    // such rather than as a failed export.
    await exporter.checkBucket();
    var uri = await exporter.export(collectionIds: collectionIds, async: async);
    lastUri = uri;
    write(async == true ? 'started, exporting to $uri' : 'exported to $uri');
  }

  item('bucket', () async {
    write('Database location: ${await exporter.databaseLocation()}');
    var location = await exporter.bucketLocation();
    write(
      location == null
          ? '${options.bucket} does not exist yet, `create bucket` makes it'
          : '${options.bucket} is in $location',
    );
  });

  item('create bucket', () async {
    write('${options.bucket} is in ${await exporter.checkBucket()}');
  });

  item('export', () async {
    await exportTo();
  });

  item('export collections', () async {
    var value = _promptValue(await prompt('collection ids, comma separated'));
    if (value == null) {
      write('cancelled');
      return;
    }
    await exportTo(collectionIds: _collectionIds(value));
  });

  item('export async', () async {
    await exportTo(async: true);
    write('follow it with `gcloud firestore operations list`');
  });

  item('last export uri', () async {
    write(lastUri ?? 'nothing exported from this menu yet');
  });

  item('list exports', () async {
    var names = await exporter.listExportNames();
    if (names.isEmpty) {
      write('no export yet in ${options.uri}');
      return;
    }
    for (var name in names) {
      write(name);
    }
    write('${names.length} export(s), the latest last');
  });

  item('latest export size', () async {
    var name = await exporter.latestExportName();
    if (name == null) {
      write('no export yet in ${options.uri}');
      return;
    }
    var uri = exporter.exportUri(name);
    var usage = await exporter.usageOf(uri);
    write(uri);
    write('${usage.size} bytes (${storageSizeText(usage.size)})');
    write('${usage.fileCount} file(s)');
    var operation = await exporter.exportOperation(uri);
    write(
      operation == null
          // Firestore only keeps its operations for a while.
          ? 'documents: <unknown, firestore no longer lists that export>'
          : 'documents: ${operation.documentCount ?? '<unknown>'}'
                ' (${operation.state})',
    );
  });

  item('import', () async {
    var uri =
        _promptValue(
          await prompt(
            'export uri (gs://…)${lastUri == null ? '' : ', empty for $lastUri'}',
          ),
        ) ??
        lastUri;
    if (uri == null) {
      write('cancelled');
      return;
    }
    var answer = _promptValue(
      await prompt(
        'import $uri into ${options.projectId}? '
        'every exported document overwrites the live one. '
        'type the project id to confirm',
      ),
    );
    if (answer != options.projectId) {
      write('cancelled');
      return;
    }
    await exporter.importFrom(uri);
    write('imported $uri');
  });
}
