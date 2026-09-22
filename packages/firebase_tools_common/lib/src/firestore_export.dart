import 'package:dev_build/shell.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_common_utils/map_utils.dart';

import 'firebase_project.dart';
import 'storage_path.dart';

/// The `gs://` scheme a cloud storage uri starts with.
const _gsScheme = 'gs://';

/// The default cloud storage bucket of the firebase project [projectId], i.e.
/// `<projectId>.firebasestorage.app`, the one firebase creates with the
/// project.
///
/// Projects created before october 2024 got `<projectId>.appspot.com` instead;
/// name that one explicitly.
///
/// Rarely the right destination for a firestore export: firebase creates it
/// wherever the project was set up, which is often not a location the
/// firestore database can export to. See [firestoreBackupBucket].
String firebaseDefaultStorageBucket(String projectId) =>
    '$projectId.firebasestorage.app';

/// The conventional backup bucket of the project [projectId], i.e.
/// `<projectId>-backup`, the default destination of a [FirestoreExporter].
///
/// A bucket of its own, created in the location of the firestore database (see
/// [FirestoreExporterExt.ensureBucket]), because firestore only exports to a
/// bucket in its own location and the bucket of an app rarely is one.
String firestoreBackupBucket(String projectId) => '$projectId-backup';

/// The `gs://` uri of [path] in [bucket].
///
/// [bucket] is a bucket name, with or without its `gs://` scheme and with or
/// without a base folder (`my-bucket`, `gs://my-bucket`,
/// `gs://my-bucket/backup` all work). [path] is a folder inside it, the bucket
/// root when null or empty. Slashes are normalized, so no argument has to
/// worry about a leading or trailing one.
///
/// Throws an [ArgumentError] when [bucket] holds no name.
String gsBucketUri(String bucket, [String? path]) {
  var location = storagePathNormalize(
    bucket.startsWith(_gsScheme) ? bucket.substring(_gsScheme.length) : bucket,
  );
  if (location.isEmpty) {
    throw ArgumentError.value(bucket, 'bucket', 'no bucket name');
  }
  return '$_gsScheme${storagePathJoin(location, path ?? '')}';
}

/// The folder name of one export, from its date [when] (the current time by
/// default): `2026-09-22T10-30-00Z`.
///
/// Utc, so exports run from two machines sort in the order they happened, and
/// `-` rather than `:` so the folder survives a download to any file system.
String firestoreExportName([DateTime? when]) {
  var utc = (when ?? DateTime.now()).toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}-${two(utc.minute)}-${two(utc.second)}Z';
}

/// The `--collection-ids` argument exporting or importing [collectionIds]
/// needs, i.e. `' --collection-ids=a,b'`, or the empty string for the whole
/// database when [collectionIds] is null or empty.
String firestoreCollectionIdsArgument(List<String>? collectionIds) =>
    (collectionIds == null || collectionIds.isEmpty)
    ? ''
    : ' --collection-ids=${collectionIds.join(',')}';

/// The `gcloud firestore export` command line writing the database of
/// [projectId] to [uri] (a `gs://` folder, see [gsBucketUri]).
///
/// [collectionIds] restricts the export to those collections (every collection
/// *group* of that id, at any depth), the whole database when null or empty.
/// [database] names a non default firestore database. [async] adds `--async`,
/// which returns as soon as the operation is started instead of waiting for it
/// to finish.
String firestoreExportCommand({
  required String projectId,
  required String uri,
  List<String>? collectionIds,
  String? database,
  bool? async,
}) =>
    'gcloud firestore export ${shellArgument(uri)}'
    ' --project $projectId'
    '${firestoreCollectionIdsArgument(collectionIds)}'
    '${database == null ? '' : ' --database=$database'}'
    '${async == true ? ' --async' : ''}';

/// The `gcloud firestore import` command line reading [uri] back into the
/// database of [projectId].
///
/// [uri] is the folder one export wrote, i.e. what
/// [FirestoreExporterExt.export] returned — the one holding the
/// `*.overall_export_metadata` file, not the bucket root.
///
/// The other parameters are the ones of [firestoreExportCommand].
String firestoreImportCommand({
  required String projectId,
  required String uri,
  List<String>? collectionIds,
  String? database,
  bool? async,
}) =>
    'gcloud firestore import ${shellArgument(uri)}'
    ' --project $projectId'
    '${firestoreCollectionIdsArgument(collectionIds)}'
    '${database == null ? '' : ' --database=$database'}'
    '${async == true ? ' --async' : ''}';

/// The `gcloud firestore databases describe` command line printing the
/// location of the database of [projectId], e.g. `europe-west9`.
///
/// [database] names a non default firestore database.
String firestoreDatabaseLocationCommand({
  required String projectId,
  String? database,
}) =>
    'gcloud firestore databases describe'
    ' --project $projectId'
    '${database == null ? '' : ' --database=$database'}'
    ' --format=value(locationId)';

/// The `gcloud storage buckets describe` command line printing the location of
/// [bucket], e.g. `EUROPE-WEST9`.
///
/// It fails when the bucket does not exist, which is how
/// [FirestoreExporterExt.bucketLocation] tells.
String storageBucketLocationCommand({
  required String bucket,
  required String projectId,
}) =>
    'gcloud storage buckets describe ${shellArgument(gsBucketUri(bucket))}'
    ' --project $projectId'
    ' --format=value(location)';

/// The `gcloud storage buckets create` command line creating [bucket] in
/// [location] (a region or a multi region, e.g. `europe-west9` or `eu`).
String storageBucketCreateCommand({
  required String bucket,
  required String projectId,
  required String location,
}) =>
    'gcloud storage buckets create ${shellArgument(gsBucketUri(bucket))}'
    ' --project $projectId'
    ' --location=$location';

/// The `gcloud storage ls` command line listing what [uri] directly holds.
///
/// It fails when nothing matches [uri], an empty or missing folder included,
/// which is how [FirestoreExporterExt.listExportNames] tells.
String storageListCommand({required String uri, required String projectId}) =>
    'gcloud storage ls ${shellArgument(uri)} --project $projectId';

/// The `gcloud storage du --summarize` command line printing the total size in
/// bytes of everything under [uri].
String storageSizeCommand({required String uri, required String projectId}) =>
    'gcloud storage du --summarize ${shellArgument(uri)}'
    ' --project $projectId';

/// The names of the folders in the `gcloud storage ls` output [output], sorted.
///
/// A listing prints one `gs://…` uri per line, a folder with a trailing `/`;
/// only the last segment is kept. The export names are dates (see
/// [firestoreExportName]), so sorting them puts the latest export last.
List<String> storageListingNames(String output) {
  var names = <String>[];
  for (var line in LineSplitter.split(output)) {
    var trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith(_gsScheme)) {
      continue;
    }
    // `gs://bucket/a/b/` and `gs://bucket/a/b` both give `b`; the bucket
    // itself (`gs://bucket/`) gives nothing to keep.
    var parts = storagePathParts(trimmed.substring(_gsScheme.length));
    if (parts.length < 2) {
      continue;
    }
    names.add(parts.last);
  }
  names.sort();
  return names;
}

/// The `gcloud storage du` command line printing the size of every object
/// under [uri], one per line.
///
/// Unlike [storageSizeCommand] it lists each object, which is what counting
/// them needs — and what makes it grow with the content of [uri].
String storageUsageCommand({required String uri, required String projectId}) =>
    'gcloud storage du ${shellArgument(uri)} --project $projectId';

/// How many objects a folder of a bucket holds, and their total size.
class StorageUsage {
  /// The number of objects, directories excluded.
  final int fileCount;

  /// Their total size in bytes.
  final int size;

  /// Creates a usage of [fileCount] objects totalling [size] bytes.
  const StorageUsage({required this.fileCount, required this.size});

  @override
  String toString() =>
      'StorageUsage($fileCount file(s), $size bytes, '
      '${storageSizeText(size)})';
}

/// The object count and total size in the `gcloud storage du` output [output].
///
/// `du` prints one line per object, then one cumulative line per directory it
/// walked through and one for the listed folder itself. Only the object lines
/// count: the directory ones are those whose uri ends with `/`, and summing
/// them in would count every object several times.
///
/// An object whose own name ends with `/` — a directory placeholder, which an
/// export never writes — is left out along with them.
StorageUsage storageUsageFromDu(String output) {
  var fileCount = 0;
  var size = 0;
  for (var line in LineSplitter.split(output)) {
    var parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      continue;
    }
    var bytes = int.tryParse(parts.first);
    var uri = parts.last;
    if (bytes == null || !uri.startsWith(_gsScheme) || uri.endsWith('/')) {
      continue;
    }
    fileCount++;
    size += bytes;
  }
  return StorageUsage(fileCount: fileCount, size: size);
}

/// The byte count in the `gcloud storage du --summarize` output [output],
/// whose only line is the size followed by the uri it covers.
///
/// Returns `null` when nothing could be read, an empty output included — `du`
/// prints nothing at all for a folder that holds no object.
int? storageSizeFromDu(String output) {
  for (var line in LineSplitter.split(output)) {
    var size = int.tryParse(line.trim().split(RegExp(r'\s+')).first);
    if (size != null) {
      return size;
    }
  }
  return null;
}

/// [bytes] as a short human readable size, the way `gcloud --readable-sizes`
/// writes it: `0 B`, `821 B`, `82.1 KiB`, `1.5 GiB`.
///
/// Powers of 1024, one decimal below 100 and none above, because a size is
/// read, not computed with — [storageSizeFromDu] keeps the exact byte count.
String storageSizeText(int bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value.abs() >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  var text = (unit == 0 || value.abs() >= 100)
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// The `gcloud firestore operations list` command line, as json.
///
/// [limit] caps how many operations come back, 100 like `gcloud` itself when
/// null. [database] names a non default firestore database.
String firestoreOperationsListCommand({
  required String projectId,
  String? database,
  int? limit,
}) =>
    'gcloud firestore operations list'
    ' --project $projectId'
    '${database == null ? '' : ' --database=$database'}'
    '${limit == null ? '' : ' --limit $limit'}'
    ' --format=json';

/// What firestore remembers of one export operation: where it wrote, whether
/// it succeeded, and how many documents it exported.
///
/// This is the only place the document count of an export lives — the bucket
/// holds opaque output files, not a record count. Firestore keeps the
/// operations for a while only, so an old export has none any more.
class FirestoreExportOperation {
  /// The `gs://` folder the export wrote to, i.e. what
  /// [FirestoreExporterExt.export] returned.
  final String uri;

  /// `SUCCESSFUL`, `PROCESSING`, `FAILED` or `CANCELLED`.
  final String state;

  /// How many documents were exported, null when firestore did not say.
  final int? documentCount;

  /// How many bytes firestore read out of the database, null when it did not
  /// say.
  ///
  /// Not the size of the export in the bucket, which is what
  /// [FirestoreExporterExt.usageOf] measures: the output files are encoded
  /// and compressed differently.
  final int? byteCount;

  /// Whether the export finished and succeeded.
  bool get successful => state == 'SUCCESSFUL';

  /// Creates an operation record.
  const FirestoreExportOperation({
    required this.uri,
    required this.state,
    this.documentCount,
    this.byteCount,
  });

  @override
  String toString() =>
      'FirestoreExportOperation($uri, $state, $documentCount document(s))';
}

/// The export operations in the json [output] of
/// [firestoreOperationsListCommand], newest first is not guaranteed.
///
/// Anything that is not an export operation (an import, an index build) has no
/// `outputUriPrefix` and is left out, as is a malformed output — a tool
/// reporting on an export would rather say it does not know.
List<FirestoreExportOperation> firestoreExportOperationsFromJson(
  String output,
) {
  Object? decoded;
  try {
    decoded = jsonDecode(output);
  } catch (_) {
    return [];
  }
  if (decoded is! List) {
    return [];
  }
  var operations = <FirestoreExportOperation>[];
  for (var item in decoded) {
    if (item is! Map) {
      continue;
    }
    var uri = mapValueFromParts<Object>(item, [
      'metadata',
      'outputUriPrefix',
    ])?.toString();
    if (uri == null || uri.isEmpty) {
      continue;
    }
    operations.add(
      FirestoreExportOperation(
        uri: uri,
        state:
            mapValueFromParts<Object>(item, [
              'metadata',
              'operationState',
            ])?.toString() ??
            'UNKNOWN',
        // Sent as json strings, e.g. `"completedWork": "201"`.
        documentCount: parseInt(
          mapValueFromParts<Object>(item, [
            'metadata',
            'progressDocuments',
            'completedWork',
          ]),
        ),
        byteCount: parseInt(
          mapValueFromParts<Object>(item, [
            'metadata',
            'progressBytes',
            'completedWork',
          ]),
        ),
      ),
    );
  }
  return operations;
}

/// The cloud storage multi region holding the firestore location [location]
/// (`eu` for `europe-west9` or `eur3`, `us` for `us-west1` or `nam5`), or
/// `null` for a location none of them covers.
String? _locationMultiRegion(String location) {
  if (location == 'eur3' || location.startsWith('europe-')) {
    return 'eu';
  }
  if (location == 'nam5' || location.startsWith('us-')) {
    return 'us';
  }
  if (location.startsWith('asia-')) {
    return 'asia';
  }
  return null;
}

/// Whether firestore accepts exporting a database in [databaseLocation] to a
/// bucket in [bucketLocation].
///
/// An export only writes to a bucket in the location of the database: the same
/// location, or the multi region holding it (`eu` for a `europe-*` database,
/// `us` for a `us-*` one). Case is ignored, since `gcloud` prints a bucket
/// location in upper case and a database location in lower case.
///
/// A best effort check, run before an export to fail with something better
/// than what `gcloud` says once the export is already asked for; `gcloud`
/// stays the authority.
bool firestoreExportLocationMatches({
  required String bucketLocation,
  required String databaseLocation,
}) {
  var bucket = bucketLocation.trim().toLowerCase();
  var database = databaseLocation.trim().toLowerCase();
  if (bucket.isEmpty || database.isEmpty) {
    return false;
  }
  return bucket == database || bucket == _locationMultiRegion(database);
}

/// What the firestore export and import of one project act on: the project,
/// the destination bucket and folder, and which part of the database moves.
class FirestoreExportOptions {
  /// The google cloud (firebase) project id the database belongs to, passed as
  /// `--project`.
  final String projectId;

  /// The destination bucket, with or without its `gs://` scheme.
  ///
  /// Defaults to `<projectId>-backup` (see [firestoreBackupBucket]).
  ///
  /// Firestore only exports to a bucket **in the location of the database**,
  /// so this is a bucket of its own rather than the bucket of the app, which
  /// firebase creates wherever the project was set up.
  /// [FirestoreExporterExt.ensureBucket] creates it in the right location.
  final String bucket;

  /// The folder inside [bucket] holding the exports, `'firestore-export'` by
  /// default, the bucket root when empty.
  ///
  /// One export goes in a sub folder of it named after its date (see
  /// [firestoreExportName]), so the successive exports of a project sit side
  /// by side and nothing is ever overwritten.
  final String bucketPath;

  /// The collections to export, every collection of the database when null or
  /// empty.
  ///
  /// An id here is a collection *group*: `note` exports every `note`
  /// collection, at any depth.
  final List<String>? collectionIds;

  /// The firestore database id, the `(default)` one when null.
  final String? database;

  /// The location [FirestoreExporterExt.ensureBucket] creates [bucket] in, a
  /// region or a multi region (`europe-west9`, `eu`).
  ///
  /// Defaults to the location of the firestore database itself, the one
  /// location an export is allowed to write to. Name a multi region here to
  /// keep the backups of a regional database spread wider.
  final String? bucketLocation;

  /// Creates the options of the project [projectId].
  ///
  /// Every other parameter has a sensible default, so exporting a whole
  /// project is `FirestoreExportOptions(projectId: 'my_project')`. See each
  /// field for what it means.
  FirestoreExportOptions({
    required this.projectId,
    String? bucket,
    this.bucketPath = 'firestore-export',
    this.collectionIds,
    this.database,
    this.bucketLocation,
  }) : bucket = bucket ?? firestoreBackupBucket(projectId);

  /// Creates the options of the project the firebase folder at [path] deploys
  /// to, i.e. the `default` project of its `.firebaserc`.
  ///
  /// [path] defaults to the current directory. See [firebaseFolderProjectId]
  /// for what is read and when it throws; the other parameters are the ones of
  /// the default constructor.
  factory FirestoreExportOptions.firebaseFolder({
    String? path,
    String? bucket,
    String bucketPath = 'firestore-export',
    List<String>? collectionIds,
    String? database,
    String? bucketLocation,
  }) => FirestoreExportOptions(
    projectId: firebaseFolderProjectId(path: path),
    bucket: bucket,
    bucketPath: bucketPath,
    collectionIds: collectionIds,
    database: database,
    bucketLocation: bucketLocation,
  );

  /// The `gs://` uri the exports of these options go under, i.e. [bucketPath]
  /// in [bucket].
  String get uri => gsBucketUri(bucket, bucketPath);

  /// Returns a copy of these options, overriding the given fields while
  /// keeping the rest unchanged.
  FirestoreExportOptions copyWith({
    String? projectId,
    String? bucket,
    String? bucketPath,
    List<String>? collectionIds,
    String? database,
    String? bucketLocation,
  }) => FirestoreExportOptions(
    projectId: projectId ?? this.projectId,
    bucket: bucket ?? this.bucket,
    bucketPath: bucketPath ?? this.bucketPath,
    collectionIds: collectionIds ?? this.collectionIds,
    database: database ?? this.database,
    bucketLocation: bucketLocation ?? this.bucketLocation,
  );

  @override
  String toString() => 'FirestoreExportOptions($projectId, $uri)';
}

/// Exports the firestore database described by [options] to a cloud storage
/// bucket, and imports it back, through the `gcloud` cli.
///
/// The operations live on [FirestoreExporterExt].
///
/// This is the managed export of the firestore admin api, the one the console
/// and the scheduled backups use: a consistent snapshot of the database (or of
/// some of its collections) in a format only firestore reads, not a json dump.
/// It is billed one read per exported document and it counts against the
/// project quotas.
///
/// The `gcloud` cli must be installed and logged in (`gcloud auth login`) on an
/// account allowed to export the project and to write to the bucket — nothing
/// here uses the admin sdk or the firebase cli.
class FirestoreExporter {
  /// What is exported, and where to.
  final FirestoreExportOptions options;

  /// Whether the `gcloud` commands log their output.
  final bool verbose;

  /// Creates an exporter for [options]. [verbose] defaults to true: an export
  /// is a long running command, and its progress is the only sign it lives.
  FirestoreExporter({required this.options, bool? verbose})
    : verbose = verbose ?? true;
}

/// The export and import operations of a [FirestoreExporter].
extension FirestoreExporterExt on FirestoreExporter {
  Shell get _shell => Shell(verbose: verbose, commandVerbose: true);

  /// A shell for the small `describe` queries, quiet whatever [verbose] says:
  /// their output is the returned value, not something to read.
  Shell get _queryShell => Shell(verbose: false);

  /// The location of the firestore database, e.g. `europe-west9`.
  ///
  /// The one location an export of it may write to, hence the location
  /// [ensureBucket] creates the bucket in.
  Future<String> databaseLocation() async {
    var result = await _queryShell.run(
      firestoreDatabaseLocationCommand(
        projectId: options.projectId,
        database: options.database,
      ),
    );
    return result.outText.trim();
  }

  /// The location of [FirestoreExportOptions.bucket], e.g. `EUROPE-WEST9`, or
  /// `null` when the bucket does not exist.
  ///
  /// Returning `null` also covers an existing bucket that cannot be read at
  /// all, which is the same thing for a tool about to export into it.
  Future<String?> bucketLocation() async {
    try {
      var result = await _queryShell.run(
        storageBucketLocationCommand(
          bucket: options.bucket,
          projectId: options.projectId,
        ),
      );
      var location = result.outText.trim();
      return location.isEmpty ? null : location;
    } on ShellException catch (_) {
      return null;
    }
  }

  /// Makes sure [FirestoreExportOptions.bucket] exists, creating it when it
  /// does not, and returns its location.
  ///
  /// A created bucket goes in [FirestoreExportOptions.bucketLocation], the
  /// location of the database by default ([databaseLocation]) — the one an
  /// export is allowed to write to.
  ///
  /// An existing bucket is left alone, wherever it is: a bucket already
  /// holding backups is not something a dev tool moves. Its location comes
  /// back so the caller can tell that an export to it will be refused; see
  /// [checkBucket] for the check itself.
  Future<String> ensureBucket() async {
    var location = await bucketLocation();
    if (location != null) {
      return location;
    }
    var createLocation = options.bucketLocation ?? await databaseLocation();
    await _shell.run(
      storageBucketCreateCommand(
        bucket: options.bucket,
        projectId: options.projectId,
        location: createLocation,
      ),
    );
    return createLocation;
  }

  /// Makes sure the bucket exists ([ensureBucket]) and that firestore will
  /// accept exporting to it, i.e. that it is in the location of the database.
  ///
  /// Returns the location of the bucket. Throws a [StateError] naming both
  /// locations when they do not match, which is the failure `gcloud` reports
  /// only once an export has already been asked for.
  ///
  /// The comparison ignores case (`gcloud` prints a bucket location in upper
  /// case) and accepts the multi region holding the database (`eu` for a
  /// `europe-*` database, `us` for a `us-*` one), the way firestore does.
  Future<String> checkBucket() async {
    var location = await ensureBucket();
    var database = await databaseLocation();
    if (!firestoreExportLocationMatches(
      bucketLocation: location,
      databaseLocation: database,
    )) {
      throw StateError(
        'bucket ${options.bucket} is in $location, but the firestore database'
        ' of ${options.projectId} is in $database and only exports to a'
        ' bucket in its own location: name another bucket, or create one'
        ' there',
      );
    }
    return location;
  }

  /// The `gs://` uri the export [name] writes to, i.e. [name] under
  /// [FirestoreExportOptions.uri].
  String exportUri(String name) =>
      gsBucketUri(options.bucket, storagePathJoin(options.bucketPath, name));

  /// Exports the database to a new folder of the bucket and returns its
  /// `gs://` uri, the one [importFrom] takes back.
  ///
  /// [name] is that folder, named after the current date by default (see
  /// [firestoreExportName]) so two exports never collide. [collectionIds]
  /// overrides [FirestoreExportOptions.collectionIds] for this export only.
  ///
  /// Waits for the export to finish, which takes as long as the database is
  /// big, unless [async] is true: `gcloud` then returns as soon as the
  /// operation is started and prints its name, to be followed with
  /// `gcloud firestore operations list`.
  Future<String> export({
    String? name,
    List<String>? collectionIds,
    bool? async,
  }) async {
    var uri = exportUri(name ?? firestoreExportName());
    await _shell.run(
      firestoreExportCommand(
        projectId: options.projectId,
        uri: uri,
        collectionIds: collectionIds ?? options.collectionIds,
        database: options.database,
        async: async,
      ),
    );
    return uri;
  }

  /// The names of the exports already in the bucket, sorted, the latest last.
  ///
  /// Empty when the bucket, the export folder or its content does not exist —
  /// nothing to list and no bucket at all are the same answer to a tool about
  /// to show what has been exported so far.
  Future<List<String>> listExportNames() async {
    try {
      var result = await _queryShell.run(
        storageListCommand(
          uri: '${options.uri}/',
          projectId: options.projectId,
        ),
      );
      return storageListingNames(result.outText);
    } on ShellException catch (_) {
      return [];
    }
  }

  /// The name of the latest export in the bucket, `null` when there is none.
  ///
  /// The exports are named after their date, so the latest is simply the last
  /// of [listExportNames]. [exportUri] turns it back into a `gs://` uri.
  Future<String?> latestExportName() async {
    var names = await listExportNames();
    return names.isEmpty ? null : names.last;
  }

  /// The total size in bytes of everything under [uri], typically one export.
  ///
  /// Returns 0 for a folder holding no object. This walks the object listing,
  /// so it takes as long as there are objects under [uri]. Use [usageOf] to
  /// get the file count out of the same walk.
  Future<int> sizeOf(String uri) async {
    var result = await _queryShell.run(
      storageSizeCommand(uri: uri, projectId: options.projectId),
    );
    return storageSizeFromDu(result.outText) ?? 0;
  }

  /// How many files there are under [uri] and their total size, typically for
  /// one export.
  ///
  /// The same walk as [sizeOf], listing every object rather than only its
  /// total, so it costs one call for both numbers. An empty or missing folder
  /// is 0 file and 0 byte.
  ///
  /// Files, not documents: an export writes a handful of opaque output files
  /// whatever the database holds. The document count is
  /// [FirestoreExportOperation.documentCount], from [exportOperation].
  Future<StorageUsage> usageOf(String uri) async {
    try {
      var result = await _queryShell.run(
        storageUsageCommand(uri: uri, projectId: options.projectId),
      );
      return storageUsageFromDu(result.outText);
    } on ShellException catch (_) {
      return const StorageUsage(fileCount: 0, size: 0);
    }
  }

  /// The export operations firestore still remembers, newest last.
  ///
  /// Empty when none can be read. [limit] caps how many come back.
  Future<List<FirestoreExportOperation>> listExportOperations({
    int? limit,
  }) async {
    try {
      var result = await _queryShell.run(
        firestoreOperationsListCommand(
          projectId: options.projectId,
          database: options.database,
          limit: limit,
        ),
      );
      return firestoreExportOperationsFromJson(result.outText);
    } on ShellException catch (_) {
      return [];
    }
  }

  /// What firestore remembers of the export that wrote [uri], `null` when it
  /// remembers none.
  ///
  /// This is where the document count of an export comes from. Firestore only
  /// keeps its operations for a while, so an old export legitimately has
  /// none: report it as unknown rather than as zero.
  Future<FirestoreExportOperation?> exportOperation(
    String uri, {
    int? limit,
  }) async {
    var wanted = storagePathNormalize(uri);
    for (var operation in await listExportOperations(limit: limit)) {
      if (storagePathNormalize(operation.uri) == wanted) {
        return operation;
      }
    }
    return null;
  }

  /// Imports the export at [uri] back into the database, [uri] being what
  /// [export] returned.
  ///
  /// This writes into the live database: every document of the export
  /// overwrites the one that has its id, and the documents that are not in the
  /// export are left alone — an import is never a rollback to the exported
  /// state. [collectionIds] restricts it to some of the exported collections.
  ///
  /// The other parameters are the ones of [export].
  Future<void> importFrom(
    String uri, {
    List<String>? collectionIds,
    bool? async,
  }) async {
    await _shell.run(
      firestoreImportCommand(
        projectId: options.projectId,
        uri: uri,
        collectionIds: collectionIds ?? options.collectionIds,
        database: options.database,
        async: async,
      ),
    );
  }
}
