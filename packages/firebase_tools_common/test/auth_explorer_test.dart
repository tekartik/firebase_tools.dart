@TestOn('vm')
library;

import 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
import 'package:tekartik_firebase_tools_common/firebase_explorer.dart';
import 'package:test/test.dart';

void main() {
  late FirebaseAuthExplorer explorer;

  setUp(() {
    explorer = FirebaseAuthExplorer(newFirebaseAuthMemory());
  });

  test('creates and finds a user', () async {
    var created = await explorer.createUserWithEmailAndPassword(
      email: ' alex@example.com ',
      password: 'password',
      displayName: 'Alex',
    );
    expect(created.email, 'alex@example.com');

    var byEmail = await explorer.findUserByEmail(' alex@example.com ');
    expect(byEmail!.uid, created.uid);

    var byUid = await explorer.findUser(' ${created.uid} ');
    expect(byUid!.email, 'alex@example.com');
  });

  test('no user found', () async {
    expect(await explorer.findUserByEmail('nobody@example.com'), isNull);
    expect(await explorer.findUser('nobody'), isNull);
  });

  test('deletes a user', () async {
    var created = await explorer.createUserWithEmailAndPassword(
      email: 'alex@example.com',
      password: 'password',
    );
    await explorer.deleteUser(created.uid);
    expect(await explorer.findUser(created.uid), isNull);
  });

  test('listUsers throws when the implementation cannot enumerate', () async {
    // The sembast auth has no way to list users; the explorer says so up front
    // rather than failing deeper.
    expect(explorer.supportsListUsers, isFalse);
    await expectLater(() => explorer.listUsers(), throwsStateError);
  });

  group('firebaseUserText', () {
    test('with an email', () async {
      var user = await explorer.createUserWithEmailAndPassword(
        email: 'alex@example.com',
        password: 'password',
      );
      expect(firebaseUserText(user), 'alex@example.com (${user.uid})');
    });

    test('without an email', () async {
      var user = await explorer.admin.createUser(
        FirebaseAuthCreateUserRequest(uid: 'anonymous1'),
      );
      expect(firebaseUserText(user), '<no email> (anonymous1)');
    });
  });
}
