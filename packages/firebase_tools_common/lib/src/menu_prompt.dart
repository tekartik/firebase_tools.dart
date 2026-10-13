import 'package:dev_build/menu/menu.dart';

/// The `prompt` answer [value], trimmed, or `null` when it was left empty —
/// which every item takes as a cancellation.
String? menuPromptValue(String value) {
  var trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Prompts [message] and returns the trimmed answer, or `null` after writing
/// `cancelled` when it was left empty.
Future<String?> menuPromptOrCancel(String message) async {
  var value = menuPromptValue(await prompt(message));
  if (value == null) {
    write('cancelled');
  }
  return value;
}
