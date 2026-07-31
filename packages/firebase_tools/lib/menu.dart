/// The `dev_build` console menus of the firebase tools, the main entry point
/// included.
///
/// [firebaseToolsMenuMain] runs the whole thing for one firebase folder in a
/// single call; [menuFirebaseToolsContent] declares it inside a menu you own.
/// Everything `tekartik_firebase_tools_common` declares is re-exported, so the
/// emulator, project and explorer submenus can also be used on their own.
library;

export 'package:tekartik_firebase_tools_common/menu.dart';

export 'src/main_menu.dart'
    show menuFirebaseToolsContent, firebaseToolsMenuMain;
