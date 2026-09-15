@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_firebase_tools_common/firebase_project.dart';
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
    File(join(path, fileName)).writeAsStringSync(content);
  });
  return path;
}

void main() {
  group('firebaseFunctionsDeployOnly', () {
    test('null or empty deploys every function', () {
      expect(firebaseFunctionsDeployOnly(null), 'functions');
      expect(firebaseFunctionsDeployOnly([]), 'functions');
    });

    test('prefixes each name', () {
      expect(firebaseFunctionsDeployOnly(['a']), 'functions:a');
      expect(
        firebaseFunctionsDeployOnly(['a', 'b']),
        'functions:a,functions:b',
      );
    });

    test('leaves an already prefixed name alone', () {
      expect(
        firebaseFunctionsDeployOnly(['functions:a', 'b']),
        'functions:a,functions:b',
      );
    });
  });

  group('firebaseDeployCommand', () {
    test('deploys everything by default', () {
      expect(
        firebaseDeployCommand(projectId: 'my_project'),
        'firebase deploy --project my_project',
      );
    });

    test('restricts to only', () {
      expect(
        firebaseDeployCommand(projectId: 'my_project', only: 'functions:a'),
        'firebase deploy --only functions:a --project my_project',
      );
    });

    test('force adds --force', () {
      expect(
        firebaseDeployCommand(projectId: 'my_project', force: true),
        'firebase deploy --project my_project --force',
      );
      expect(
        firebaseDeployCommand(
          projectId: 'my_project',
          only: 'firestore:indexes',
          force: true,
        ),
        'firebase deploy --only firestore:indexes --project my_project --force',
      );
      expect(
        firebaseDeployCommand(projectId: 'my_project', force: false),
        'firebase deploy --project my_project',
      );
    });
  });

  group('firebaseRcContentProjectId', () {
    test('reads the default project', () {
      expect(
        firebaseRcContentProjectId('{"projects": {"default": "my_project"}}'),
        'my_project',
      );
    });

    test('throws on invalid json', () {
      expect(() => firebaseRcContentProjectId('not json'), throwsStateError);
    });

    test('throws when there is no default project', () {
      expect(() => firebaseRcContentProjectId('{}'), throwsStateError);
      expect(
        () => firebaseRcContentProjectId('{"projects": {}}'),
        throwsStateError,
      );
      expect(
        () => firebaseRcContentProjectId('{"projects": {"default": ""}}'),
        throwsStateError,
      );
    });

    test('throws when the content is not an object', () {
      expect(() => firebaseRcContentProjectId('[]'), throwsStateError);
    });
  });

  group('firebaseFolderProjectId', () {
    test('reads the .firebaserc of the folder', () {
      var path = _newFirebaseFolder('project_ok', {
        'firebase.json': '{}',
        '.firebaserc': '{"projects": {"default": "my_project"}}',
      });
      expect(firebaseFolderProjectId(path: path), 'my_project');
    });

    test('throws when the folder is not a firebase folder', () {
      var path = _newFirebaseFolder('project_no_firebase_json', {
        '.firebaserc': '{"projects": {"default": "my_project"}}',
      });
      expect(() => firebaseFolderProjectId(path: path), throwsStateError);
    });

    test('throws when there is no .firebaserc', () {
      var path = _newFirebaseFolder('project_no_firebaserc', {
        'firebase.json': '{}',
      });
      expect(() => firebaseFolderProjectId(path: path), throwsStateError);
    });
  });

  group('FirebaseProjectOptions', () {
    test('defaults', () {
      var options = FirebaseProjectOptions(projectId: 'my_project');
      expect(options.projectId, 'my_project');
      expect(options.path, normalize(absolute('.')));
      expect(options.functions, isNull);
      expect(options.functionsSource, 'functions');
      expect(options.functionsEntryPoint, 'bin/server.dart');
      expect(options.functionsSourcePath, join(options.path, 'functions'));
    });

    test('the path is made absolute and normalized', () {
      var options = FirebaseProjectOptions(
        projectId: 'my_project',
        path: 'a/../b',
      );
      expect(options.path, normalize(absolute('b')));
    });

    test('copyWith overrides only what it is given', () {
      var options = FirebaseProjectOptions(
        projectId: 'my_project',
        path: 'b',
        functions: ['a'],
        functionsTargetOs: 'macos',
      );
      var copy = options.copyWith(projectId: 'other');
      expect(copy.projectId, 'other');
      expect(copy.path, options.path);
      expect(copy.functions, ['a']);
      expect(copy.functionsTargetOs, 'macos');
    });

    test('firebaseFolder reads the project id', () {
      var path = _newFirebaseFolder('project_options', {
        'firebase.json': '{}',
        '.firebaserc': '{"projects": {"default": "my_project"}}',
      });
      var options = FirebaseProjectOptions.firebaseFolder(
        path: path,
        functions: ['a'],
      );
      expect(options.projectId, 'my_project');
      expect(options.path, normalize(absolute(path)));
      expect(options.functions, ['a']);
    });
  });

  test('FirebaseProjectBuilder path comes from its options', () {
    var builder = FirebaseProjectBuilder(
      options: FirebaseProjectOptions(projectId: 'my_project', path: 'b'),
    );
    expect(builder.path, normalize(absolute('b')));
  });
}
