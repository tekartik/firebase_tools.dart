import 'package:cv/cv_json.dart';
import 'package:dev_build/menu/menu.dart';
import 'package:tekartik_firebase_auth/auth.dart';

import 'auth_explorer.dart';
import 'firebase_context.dart';
import 'firestore_explorer.dart';
import 'firestore_path.dart';
import 'storage_explorer.dart';
import 'storage_path.dart';

/// Remembers what the menu items act on between two of them, so a user is found
/// once and every following item applies to it.
class FirebaseExplorerMenuState {
  /// The selected user, `null` until one is found.
  UserRecord? user;

  /// The name filter the storage listing applies, `null` for none.
  String? storageFilter;

  /// How many entries a listing shows at most.
  int limit = 100;

  /// The selected user id, or a [StateError] naming what to do about it.
  String get userId {
    var user = this.user;
    if (user == null) {
      throw StateError('no user selected, use \'find user by email\' first');
    }
    return user.uid;
  }
}

/// The `prompt` answer [value], trimmed, or `null` when it was left empty —
/// which every item takes as a cancellation.
String? _promptValue(String value) {
  var trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Registers the whole explorer menu of [context]: its auth users, its
/// firestore database and its storage bucket, each in its own submenu.
///
/// Everything goes through the admin sdk by default, so it reads and creates
/// auth users and bypasses the firestore rules: this belongs in a dev tool,
/// never in an app.
void menuFirebaseExplorerContent({required FirebaseToolsContext context}) {
  var state = FirebaseExplorerMenuState();

  enter(() async {
    write('Firebase project: ${context.projectId ?? '<ambient>'}');
    var user = state.user;
    write('User: ${user == null ? '<none selected>' : firebaseUserText(user)}');
  });

  item('limit', () async {
    var value = _promptValue(await prompt('max entries (${state.limit})'));
    if (value == null) {
      write('cancelled');
      return;
    }
    var limit = int.tryParse(value);
    if (limit == null || limit <= 0) {
      write('not a positive number: $value');
      return;
    }
    state.limit = limit;
    write('limit is now ${state.limit}');
  });

  menu('auth', () {
    menuFirebaseAuthExplorerContent(context: context, state: state);
  });

  menu('firestore', () {
    menuFirestoreExplorerContent(context: context, state: state);
  });

  menu('storage', () {
    menuStorageExplorerContent(context: context, state: state);
  });
}

/// Registers the dev-menu items acting on the auth users of [context]: listing
/// them, finding one by email or uid, creating and deleting one.
///
/// [state] carries the selected user across items; a fresh one is used when it
/// is omitted.
void menuFirebaseAuthExplorerContent({
  required FirebaseToolsContext context,
  FirebaseExplorerMenuState? state,
}) {
  var menuState = state ?? FirebaseExplorerMenuState();

  void select(UserRecord user) {
    menuState.user = user;
    write('selected ${firebaseUserText(user)}');
  }

  enter(() async {
    write('The auth users of ${context.projectId ?? 'the project'}.');
    var user = menuState.user;
    write('User: ${user == null ? '<none selected>' : firebaseUserText(user)}');
  });

  item('list users', () async {
    var explorer = await context.authExplorer;
    var users = await explorer.listUsers(maxResults: menuState.limit);
    if (users.isEmpty) {
      write('no user');
      return;
    }
    for (var user in users) {
      write(firebaseUserText(user));
    }
    write('${users.length} user(s)');
  });

  item('find user by email', () async {
    var email = _promptValue(await prompt('email'));
    if (email == null) {
      write('cancelled');
      return;
    }
    var explorer = await context.authExplorer;
    var user = await explorer.findUserByEmail(email);
    if (user == null) {
      write('no user found for $email');
      return;
    }
    select(user);
  });

  item('find user by uid', () async {
    var uid = _promptValue(await prompt('uid'));
    if (uid == null) {
      write('cancelled');
      return;
    }
    var explorer = await context.authExplorer;
    var user = await explorer.findUser(uid);
    if (user == null) {
      write('no user found for $uid');
      return;
    }
    select(user);
  });

  item('show selected user', () async {
    var user = menuState.user;
    if (user == null) {
      write('no user selected');
      return;
    }
    write(firebaseUserText(user));
    write('display name: ${user.displayName ?? '<none>'}');
    write('email verified: ${user.emailVerified}');
    write('disabled: ${user.disabled}');
  });

  item('create user (email/password)', () async {
    var email = _promptValue(await prompt('email'));
    if (email == null) {
      write('cancelled');
      return;
    }
    var password = _promptValue(await prompt('password'));
    if (password == null) {
      write('cancelled');
      return;
    }
    var explorer = await context.authExplorer;
    var user = await explorer.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    write('created');
    select(user);
  });

  item('delete selected user', () async {
    var user = menuState.user;
    if (user == null) {
      write('no user selected');
      return;
    }
    var answer = _promptValue(
      await prompt('delete ${firebaseUserText(user)}? type the uid to confirm'),
    );
    if (answer != user.uid) {
      write('cancelled');
      return;
    }
    var explorer = await context.authExplorer;
    await explorer.deleteUser(user.uid);
    menuState.user = null;
    write('deleted');
  });
}

/// Registers the dev-menu items browsing the firestore database of [context]:
/// listing what the current path holds, entering any path (a document that does
/// not exist but holds sub collections included) and showing a document.
///
/// [state] carries the listing limit across items; a fresh one is used when it
/// is omitted.
void menuFirestoreExplorerContent({
  required FirebaseToolsContext context,
  FirebaseExplorerMenuState? state,
}) {
  var menuState = state ?? FirebaseExplorerMenuState();

  /// Writes the listing of the current path.
  Future<void> writeListing(FirestoreExplorer explorer) async {
    var listing = await explorer.list(limit: menuState.limit);
    if (listing.isEmpty) {
      write('nothing under /${listing.path}');
      return;
    }
    for (var id in listing.collectionIds) {
      write('$id/');
    }
    for (var document in listing.documents) {
      write('$document');
    }
  }

  enter(() async {
    write('Firestore of ${context.projectId ?? 'the project'}.');
    write(
      'A path alternates collections and documents: '
      '`app` is a collection, `app/my_app` a document.',
    );
  });

  item('where', () async {
    var explorer = await context.firestoreExplorer;
    write('/${explorer.path} (${explorer.kind.name})');
    if (!explorer.supportsMissingDocuments) {
      write(
        'note: this firestore only lists the documents that exist, '
        'the ones that merely hold sub collections stay hidden',
      );
    }
  });

  item('list', () async {
    var explorer = await context.firestoreExplorer;
    write('/${explorer.path}');
    await writeListing(explorer);
  });

  item('enter path', () async {
    var path = _promptValue(
      await prompt('path (absolute with a leading /, .. to go up)'),
    );
    if (path == null) {
      write('cancelled');
      return;
    }
    var explorer = await context.firestoreExplorer;
    write('/${explorer.cd(path)}');
    await writeListing(explorer);
  });

  item('pick', () async {
    var explorer = await context.firestoreExplorer;
    var listing = await explorer.list(limit: menuState.limit);
    var ids = [
      ...listing.collectionIds,
      ...listing.documents.map((document) => document.id),
    ];
    if (ids.isEmpty) {
      write('nothing under /${explorer.path}');
      return;
    }
    await showMenu(() {
      for (var id in ids) {
        item(id, () async {
          write('/${explorer.cd(id)}');
          await writeListing(explorer);
          await popMenu();
        });
      }
    });
  });

  item('up', () async {
    var explorer = await context.firestoreExplorer;
    if (!explorer.up()) {
      write('already at the root');
      return;
    }
    write('/${explorer.path}');
    await writeListing(explorer);
  });

  item('root', () async {
    var explorer = await context.firestoreExplorer;
    write('/${explorer.cd('/')}');
    await writeListing(explorer);
  });

  item('show document', () async {
    var explorer = await context.firestoreExplorer;
    if (!firestorePathIsDocument(explorer.path)) {
      write('/${explorer.path} is not a document, enter one first');
      return;
    }
    var document = await explorer.getDocument();
    write('/${document.path}');
    write(document.exists ? 'exists' : 'does not exist');
    if (document.collectionIds.isNotEmpty) {
      write('collections: ${document.collectionIds.join(', ')}');
    }
    var data = document.data;
    if (data != null) {
      write(data.cvToJsonPretty());
    }
  });

  item('delete document', () async {
    var explorer = await context.firestoreExplorer;
    var path = explorer.path;
    if (!firestorePathIsDocument(path)) {
      write('/$path is not a document, enter one first');
      return;
    }
    var answer = _promptValue(
      await prompt('delete /$path? type the document id to confirm'),
    );
    if (answer != firestorePathId(path)) {
      write('cancelled');
      return;
    }
    await explorer.deleteDocument(path);
    write('deleted /$path (its sub collections are untouched)');
  });
}

/// Registers the dev-menu items browsing the storage bucket of [context]:
/// listing a directory, filtering by name, entering a path and reading a file.
///
/// [state] carries the name filter and the listing limit across items; a fresh
/// one is used when it is omitted.
void menuStorageExplorerContent({
  required FirebaseToolsContext context,
  FirebaseExplorerMenuState? state,
}) {
  var menuState = state ?? FirebaseExplorerMenuState();

  /// Writes one entry, relative to the directory being listed.
  void writeEntry(StorageExplorerEntry entry, String from) {
    var name = entry.relativeTo(from);
    if (entry.isDirectory) {
      write('$name/');
      return;
    }
    var size = entry.size;
    write('$name${size == null ? '' : ' ($size bytes)'}');
  }

  Future<void> writeListing(StorageExplorer explorer) async {
    var listing = await explorer.list(
      filter: menuState.storageFilter,
      maxResults: menuState.limit,
    );
    if (listing.isEmpty) {
      write('nothing under /${listing.path}');
      return;
    }
    for (var entry in listing.entries) {
      writeEntry(entry, listing.path);
    }
  }

  enter(() async {
    write('Storage of ${context.projectId ?? 'the project'}.');
    write(
      'A bucket has no real directories: they are inferred from the `/` of '
      'the file names, so an empty one does not show up.',
    );
    write('Filter: ${menuState.storageFilter ?? '<none>'}');
  });

  item('where', () async {
    var explorer = await context.storageExplorer;
    write('${explorer.bucket.name}:/${explorer.path}');
    write('Filter: ${menuState.storageFilter ?? '<none>'}');
  });

  item('set filter', () async {
    var filter = await prompt(
      'name filter (empty to clear, `*` and `?` for a glob)',
    );
    menuState.storageFilter = _promptValue(filter);
    write('filter is now ${menuState.storageFilter ?? '<none>'}');
  });

  item('list', () async {
    var explorer = await context.storageExplorer;
    write('/${explorer.path}');
    await writeListing(explorer);
  });

  item('list recursive', () async {
    var explorer = await context.storageExplorer;
    var files = await explorer.listAll(
      filter: menuState.storageFilter,
      maxResults: menuState.limit,
    );
    if (files.isEmpty) {
      write('no file under /${explorer.path}');
      return;
    }
    for (var file in files) {
      writeEntry(file, explorer.path);
    }
    write('${files.length} file(s)');
  });

  item('list recursive (full paths)', () async {
    var explorer = await context.storageExplorer;
    var files = await explorer.listAll(
      filter: menuState.storageFilter,
      maxResults: menuState.limit,
    );
    if (files.isEmpty) {
      write('no file under /${explorer.path}');
      return;
    }
    for (var file in files) {
      write(file.path);
    }
    write('${files.length} file(s)');
  });

  item('enter path', () async {
    var path = _promptValue(
      await prompt('path (absolute with a leading /, .. to go up)'),
    );
    if (path == null) {
      write('cancelled');
      return;
    }
    var explorer = await context.storageExplorer;
    write('/${explorer.cd(path)}');
    await writeListing(explorer);
  });

  item('pick', () async {
    var explorer = await context.storageExplorer;
    var listing = await explorer.list(
      filter: menuState.storageFilter,
      maxResults: menuState.limit,
    );
    if (listing.isEmpty) {
      write('nothing under /${listing.path}');
      return;
    }
    await showMenu(() {
      for (var entry in listing.entries) {
        item('${entry.name}${entry.isDirectory ? '/' : ''}', () async {
          if (entry.isDirectory) {
            write('/${explorer.cd(entry.name)}');
            await writeListing(explorer);
          } else {
            write(entry.path);
            var metadata = await explorer.metadata(entry.path);
            if (metadata != null) {
              write('size: ${metadata.size}');
              write('content type: ${metadata.contentType ?? '<unknown>'}');
              write('updated: ${metadata.dateUpdated}');
            }
          }
          await popMenu();
        });
      }
    });
  });

  item('up', () async {
    var explorer = await context.storageExplorer;
    if (!explorer.up()) {
      write('already at the bucket root');
      return;
    }
    write('/${explorer.path}');
    await writeListing(explorer);
  });

  item('root', () async {
    var explorer = await context.storageExplorer;
    write('/${explorer.cd('/')}');
    await writeListing(explorer);
  });

  item('show file metadata', () async {
    var path = _promptValue(await prompt('file path'));
    if (path == null) {
      write('cancelled');
      return;
    }
    var explorer = await context.storageExplorer;
    var fullPath = explorer.fullPath(path);
    var metadata = await explorer.metadata(fullPath);
    if (metadata == null) {
      write('no file at $fullPath');
      return;
    }
    write(fullPath);
    write('relative: ${explorer.relativePath(fullPath)}');
    write('size: ${metadata.size}');
    write('content type: ${metadata.contentType ?? '<unknown>'}');
    write('updated: ${metadata.dateUpdated}');
    write('md5: ${metadata.md5Hash}');
  });

  item('read file as text', () async {
    var path = _promptValue(await prompt('file path'));
    if (path == null) {
      write('cancelled');
      return;
    }
    var explorer = await context.storageExplorer;
    var fullPath = explorer.fullPath(path);
    if (!await explorer.exists(fullPath)) {
      write('no file at $fullPath');
      return;
    }
    write(await explorer.readAsString(fullPath));
  });

  item('delete file', () async {
    var path = _promptValue(await prompt('file path'));
    if (path == null) {
      write('cancelled');
      return;
    }
    var explorer = await context.storageExplorer;
    var fullPath = explorer.fullPath(path);
    if (!await explorer.exists(fullPath)) {
      write('no file at $fullPath');
      return;
    }
    var answer = _promptValue(
      await prompt('delete $fullPath? type the file name to confirm'),
    );
    if (answer != storagePathName(fullPath)) {
      write('cancelled');
      return;
    }
    await explorer.delete(fullPath);
    write('deleted $fullPath');
  });
}
