import 'package:tekartik_firebase_firestore/firestore.dart';

import 'firestore_path.dart';

/// Lists every document id of [collectionRef], the documents that do not exist
/// included.
///
/// Firestore keeps a document id alive as soon as something hangs below it, so
/// `app/<appId>` routinely has sub collections while the document itself was
/// never written. A query never returns those, which is why the firestore
/// console shows them in italics; only a `listDocuments` call does.
///
/// Returns the document ids, in whatever order the backend gives them.
typedef FirestoreCollectionDocumentIdsLister =
    Future<List<String>> Function(CollectionReference collectionRef);

/// The [FirestoreCollectionDocumentIdsLister] [firestore] supports natively, or
/// `null` when its implementation cannot enumerate the documents that do not
/// exist.
///
/// The tekartik abstraction has no `listDocuments`, so only an implementation
/// exposing its native instance can serve one — the admin sdk does, see
/// `firestoreAdminSdkDocumentIdsLister` in `tekartik_firebase_tools`. This
/// package knows of no such implementation on its own, which is why a resolver
/// is passed in rather than looked up.
typedef FirestoreDocumentIdsListerResolver =
    FirestoreCollectionDocumentIdsLister? Function(Firestore firestore);

/// One document as the explorer sees it, existing or not.
class FirestoreExplorerDocument {
  /// The full path of the document, e.g. `app/my_app`.
  final String path;

  /// Whether the document itself exists.
  ///
  /// False for the ids that only exist because something hangs below them, see
  /// [FirestoreCollectionDocumentIdsLister].
  final bool exists;

  /// The document content, or `null` when it does not exist.
  final Map<String, Object?>? data;

  /// The ids of the sub collections of the document.
  ///
  /// Empty when they were not fetched, which is what listing a collection does
  /// — see [FirestoreExplorer.getDocument] to get them.
  final List<String> collectionIds;

  /// Creates a document description, see each field.
  FirestoreExplorerDocument({
    required this.path,
    required this.exists,
    this.data,
    this.collectionIds = const [],
  });

  /// The document id, i.e. the last segment of [path].
  String get id => firestorePathId(path);

  @override
  String toString() =>
      '$id${exists ? '' : ' (no document)'}'
      '${collectionIds.isEmpty ? '' : ' [${collectionIds.join(', ')}]'}';
}

/// What a firestore path holds: sub collections for the root and for a
/// document, documents for a collection.
class FirestoreExplorerListing {
  /// The path that was listed, `''` for the root.
  final String path;

  /// What [path] points to.
  final FirestorePathKind kind;

  /// The ids of the collections directly under [path], for a root or document
  /// path. Empty for a collection.
  final List<String> collectionIds;

  /// The documents of [path], for a collection path. Empty otherwise.
  final List<FirestoreExplorerDocument> documents;

  /// Creates a listing, see each field.
  FirestoreExplorerListing({
    required this.path,
    required this.kind,
    this.collectionIds = const [],
    this.documents = const [],
  });

  /// Whether nothing was found under [path].
  bool get isEmpty => collectionIds.isEmpty && documents.isEmpty;

  @override
  String toString() =>
      'FirestoreExplorerListing($path, collections: $collectionIds, '
      'documents: $documents)';
}

/// Browses a firestore database as a tree, keeping a current [path] the way a
/// shell keeps a current directory.
///
/// Paths alternate collection and document segments, and the root (`''`) and
/// every document hold collections while every collection holds documents —
/// see [FirestorePathKind].
///
/// A document that does not exist but holds sub collections is reachable all
/// the same: entering an arbitrary path always works, and listing a collection
/// reports those ids too when a [documentIdsLister] is in place — the admin sdk
/// flavour of this package wires one in, see `tekartik_firebase_tools`.
class FirestoreExplorer {
  /// The database being browsed.
  final Firestore firestore;

  /// Lists the document ids of a collection, missing documents included.
  ///
  /// `null` when nothing can enumerate them, in which case only the documents a
  /// query returns (the existing ones) are listed.
  final FirestoreCollectionDocumentIdsLister? documentIdsLister;

  String _path;

  /// Browses [firestore], starting at [path] (the root by default).
  ///
  /// [documentIdsLister] is how the document ids of a collection are
  /// enumerated, missing documents included; leave it `null` to list only the
  /// documents that exist. [documentIdsListerResolver] is asked for one instead
  /// when [documentIdsLister] is omitted, which is how an implementation aware
  /// caller passes what it can do without deciding it here.
  FirestoreExplorer(
    this.firestore, {
    String? path,
    FirestoreCollectionDocumentIdsLister? documentIdsLister,
    FirestoreDocumentIdsListerResolver? documentIdsListerResolver,
  }) : _path = firestorePathNormalize(path ?? ''),
       documentIdsLister =
           documentIdsLister ?? documentIdsListerResolver?.call(firestore);

  /// The path currently browsed, `''` for the root.
  String get path => _path;

  /// What [path] points to.
  FirestorePathKind get kind => firestorePathKind(_path);

  /// Whether the missing documents of a collection can be listed, i.e. whether
  /// a [documentIdsLister] is in place.
  bool get supportsMissingDocuments => documentIdsLister != null;

  /// Moves to [target], the way `cd` does: absolute when it starts with `/`,
  /// relative otherwise, `..` going one level up.
  ///
  /// Nothing is fetched and no check is made, so entering a document that does
  /// not exist (yet) is fine — that is the point.
  ///
  /// Returns the new [path].
  String cd(String target) => _path = firestorePathResolve(_path, target);

  /// Moves one level up, i.e. `cd('..')`.
  ///
  /// Returns `false` when already at the root, `true` otherwise.
  bool up() {
    if (_path.isEmpty) {
      return false;
    }
    cd('..');
    return true;
  }

  /// The ids of the collections directly under [documentPath], defaulting to
  /// the current [path].
  ///
  /// [documentPath] must be the root (`''`) or a document path. Returns the
  /// sorted collection ids, empty when there is none.
  ///
  /// Throws an [ArgumentError] when [documentPath] points to a collection, and
  /// a [StateError] when the backing firestore cannot list collections.
  Future<List<String>> listCollectionIds([String? documentPath]) async {
    var path = firestorePathNormalize(documentPath ?? _path);
    if (firestorePathIsCollection(path)) {
      throw ArgumentError.value(
        path,
        'documentPath',
        'is a collection, not a document',
      );
    }
    if (!firestore.service.supportsListCollections) {
      throw StateError(
        'this firestore cannot list collections, '
        'build the context with the admin sdk',
      );
    }
    var refs = path.isEmpty
        ? await firestore.listCollections()
        : await firestore.doc(path).listCollections();
    return refs.map((ref) => ref.id).toList()..sort();
  }

  /// The documents of the collection [collectionPath], defaulting to the
  /// current [path], at most [limit] of them.
  ///
  /// The documents that do not exist but hold sub collections are listed too
  /// when [supportsMissingDocuments] is true, with
  /// [FirestoreExplorerDocument.exists] false and no data.
  ///
  /// Returns the documents sorted by id.
  ///
  /// Throws an [ArgumentError] when [collectionPath] does not point to a
  /// collection.
  Future<List<FirestoreExplorerDocument>> listDocuments([
    String? collectionPath,
    int? limit,
  ]) async {
    var path = firestorePathNormalize(collectionPath ?? _path);
    if (!firestorePathIsCollection(path)) {
      throw ArgumentError.value(path, 'collectionPath', 'is not a collection');
    }
    var collectionRef = firestore.collection(path);
    Query query = collectionRef;
    if (limit != null) {
      query = query.limit(limit);
    }
    var snapshot = await query.get();
    var documents = <String, FirestoreExplorerDocument>{};
    for (var doc in snapshot.docs) {
      documents[doc.ref.id] = FirestoreExplorerDocument(
        path: doc.ref.path,
        exists: true,
        data: doc.data,
      );
    }
    var lister = documentIdsLister;
    if (lister != null) {
      for (var id in await lister(collectionRef)) {
        if (limit != null && documents.length >= limit) {
          break;
        }
        documents.putIfAbsent(
          id,
          () => FirestoreExplorerDocument(
            path: firestorePathJoin(path, id),
            exists: false,
          ),
        );
      }
    }
    var ids = documents.keys.toList()..sort();
    return [for (var id in ids) documents[id]!];
  }

  /// The document at [documentPath], defaulting to the current [path], with its
  /// content and the ids of its sub collections.
  ///
  /// A document that was never written still comes back, with
  /// [FirestoreExplorerDocument.exists] false and no data, its sub collections
  /// listed all the same — which is the whole point of entering it.
  ///
  /// Throws an [ArgumentError] when [documentPath] does not point to a
  /// document.
  Future<FirestoreExplorerDocument> getDocument([String? documentPath]) async {
    var path = firestorePathNormalize(documentPath ?? _path);
    if (!firestorePathIsDocument(path)) {
      throw ArgumentError.value(path, 'documentPath', 'is not a document');
    }
    var ref = firestore.doc(path);
    var snapshot = await ref.get();
    var collectionIds = <String>[];
    if (firestore.service.supportsListCollections) {
      collectionIds = (await ref.listCollections()).map((e) => e.id).toList()
        ..sort();
    }
    return FirestoreExplorerDocument(
      path: path,
      exists: snapshot.exists,
      data: snapshot.exists ? snapshot.data : null,
      collectionIds: collectionIds,
    );
  }

  /// What [path] (defaulting to the current one) holds: its sub collections for
  /// the root and for a document, its documents for a collection.
  ///
  /// [limit] caps the number of documents of a collection listing and is
  /// ignored otherwise.
  Future<FirestoreExplorerListing> list({String? path, int? limit}) async {
    var target = firestorePathNormalize(path ?? _path);
    var kind = firestorePathKind(target);
    switch (kind) {
      case FirestorePathKind.root:
      case FirestorePathKind.document:
        return FirestoreExplorerListing(
          path: target,
          kind: kind,
          collectionIds: await listCollectionIds(target),
        );
      case FirestorePathKind.collection:
        return FirestoreExplorerListing(
          path: target,
          kind: kind,
          documents: await listDocuments(target, limit),
        );
    }
  }

  /// Deletes the document at [documentPath], defaulting to the current [path].
  ///
  /// Its sub collections are left untouched — deleting a document never deletes
  /// what hangs below it, which is exactly how an id keeps showing up as a
  /// missing document afterwards.
  ///
  /// Throws an [ArgumentError] when [documentPath] does not point to a
  /// document.
  Future<void> deleteDocument([String? documentPath]) async {
    var path = firestorePathNormalize(documentPath ?? _path);
    if (!firestorePathIsDocument(path)) {
      throw ArgumentError.value(path, 'documentPath', 'is not a document');
    }
    await firestore.doc(path).delete();
  }
}
