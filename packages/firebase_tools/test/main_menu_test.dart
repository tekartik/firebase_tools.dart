@TestOn('vm')
library;

import 'dart:io';

// The menus are declared in a declarer of their own, never run.
// ignore: implementation_imports
import 'package:dev_build/src/menu/menu.dart' show menuNewDeclarer;
import 'package:tekartik_firebase_tools/firebase_tools.dart';
import 'package:tekartik_firebase_tools/menu.dart';
import 'package:test/test.dart';

/// A context never built: the menus are only declared.
FirebaseToolsContext _context() => FirebaseToolsContext(
  projectId: 'demo-firebase-tools',
  servicesBuilder: () async => throw StateError('not built in this test'),
);

/// The names of the menus [declare] declares at the top level.
List<String> _menuNames(void Function() declare) {
  var declarer = menuNewDeclarer()..autoRun = false;
  declare();
  return declarer.devMenu.items.map((item) => item.name).toList();
}

void main() {
  group('menuFirebaseToolsContent', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('firebase_tools_menu');
    });
    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('explorer of a context outside a firebase folder', () {
      // Nothing needs the folder project id: no firebase.json required.
      expect(
        _menuNames(
          () => menuFirebaseToolsContent(
            path: dir.path,
            context: _context(),
            withEmulator: false,
            withProject: false,
            withExport: false,
          ),
        ),
        ['explore'],
      );
    });

    test('every submenu given its options outside a firebase folder', () {
      expect(
        _menuNames(
          () => menuFirebaseToolsContent(
            path: dir.path,
            context: _context(),
            emulatorOptions: FirebaseEmulatorOptions(
              projectId: 'demo-firebase-tools',
            ),
            withProject: false,
            exportOptions: FirestoreExportOptions(
              projectId: 'demo-firebase-tools',
            ),
          ),
        ),
        ['emulator', 'explore', 'export'],
      );
    });

    test('a submenu needing the folder project id', () {
      expect(
        () => _menuNames(
          () => menuFirebaseToolsContent(path: dir.path, withProject: false),
        ),
        throwsStateError,
      );
    });

    test('the folder project id', () {
      File(
        '${dir.path}${Platform.pathSeparator}firebase.json',
      ).writeAsStringSync('{}');
      File(
        '${dir.path}${Platform.pathSeparator}.firebaserc',
      ).writeAsStringSync('{"projects": {"default": "demo-from-folder"}}');
      expect(_menuNames(() => menuFirebaseToolsContent(path: dir.path)), [
        'emulator',
        'project',
        'explore',
        'export',
      ]);
    });
  });
}
