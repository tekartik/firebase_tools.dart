import 'package:tekartik_firebase_auth/auth.dart';
import 'package:tekartik_firebase_auth/auth_admin.dart';

/// A one line description of [user], `email (uid)`, for a tool listing users.
///
/// The email is replaced by `<no email>` when the account has none.
String firebaseUserText(UserRecord user) =>
    '${user.email ?? '<no email>'} (${user.uid})';

/// Reads and administers the auth users of a firebase project.
///
/// Listing and creating users is not something a client auth can do: back this
/// with the admin sdk (see `FirebaseToolsContext.adminSdk`), or with a local
/// implementation in tests. Every method that the backing auth cannot serve
/// throws a [StateError] naming what is missing, rather than failing deeper.
class FirebaseAuthExplorer {
  /// The auth being explored.
  final FirebaseAuth auth;

  /// Explores the users of [auth].
  FirebaseAuthExplorer(this.auth);

  /// Whether [listUsers] is supported by the backing implementation.
  ///
  /// Only the admin flavours can enumerate users; a client auth can look one up
  /// but not list them.
  bool get supportsListUsers => auth.service.supportsListUsers;

  /// The admin api of [auth], i.e. what creates, updates and deletes users.
  ///
  /// Throws a [StateError] when the backing auth has no admin api — anything
  /// but the admin sdk (or a local test implementation), in practice.
  FirebaseAuthAdmin get admin {
    var auth = this.auth;
    if (auth is! FirebaseAuthAdmin) {
      throw StateError(
        'this auth cannot manage users, build the context with the admin sdk',
      );
    }
    return auth;
  }

  /// The users of the project, at most [maxResults] of them, starting at
  /// [pageToken] (from a previous call) when given.
  ///
  /// Returns the users of that batch, the ones that could not be resolved
  /// skipped. Throws a [StateError] when [supportsListUsers] is false.
  Future<List<UserRecord>> listUsers({
    int? maxResults,
    String? pageToken,
  }) async {
    if (!supportsListUsers) {
      throw StateError(
        'this auth cannot list users, build the context with the admin sdk',
      );
    }
    var result = await auth.listUsers(
      maxResults: maxResults,
      pageToken: pageToken,
    );
    return result.users.nonNulls.toList();
  }

  /// The user whose primary email is [email], surrounding blanks ignored.
  ///
  /// Returns `null` when no account has it.
  Future<UserRecord?> findUserByEmail(String email) =>
      auth.getUserByEmail(email.trim());

  /// The user of id [uid], surrounding blanks ignored.
  ///
  /// Returns `null` when no account has it.
  Future<UserRecord?> findUser(String uid) => auth.getUser(uid.trim());

  /// Creates an email/password account.
  ///
  /// [email] is the primary email (surrounding blanks ignored), [password] its
  /// password, [displayName] the optional display name.
  ///
  /// Returns the created user. Throws a [StateError] when the backing auth has
  /// no admin api, see [admin].
  Future<UserRecord> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) => admin.createUser(
    FirebaseAuthCreateUserRequest(
      email: email.trim(),
      password: password,
      displayName: displayName,
    ),
  );

  /// Deletes the account of id [uid].
  ///
  /// Throws a [StateError] when the backing auth has no admin api, see [admin].
  Future<void> deleteUser(String uid) async {
    await admin.deleteUser(uid.trim());
  }
}
