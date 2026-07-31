// The same menu, declared by hand inside a menu of your own: a project reached
// by id rather than through a `.firebaserc`, and no deploy submenu.
//
//     dart run example/firebase_tools_menu_custom.dart
import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_firebase_tools/firebase_tools.dart';
import 'package:tekartik_firebase_tools/menu.dart';

Future<void> main(List<String> arguments) async {
  mainMenuConsole(arguments, () {
    menu('my project', () {
      menuFirebaseToolsContent(
        path: 'deploy',
        projectId: 'my_project',
        withProject: false,
      );
    });

    // Or just the explorer, on a project named by id only — nothing needs a
    // firebase folder here. Pass no project id at all to let the environment
    // decide which project is reached.
    menu('explore only', () {
      menuFirebaseExplorerContent(
        context: newFirebaseToolsContextAdminSdk(projectId: 'my_project'),
      );
    });
  });
}
