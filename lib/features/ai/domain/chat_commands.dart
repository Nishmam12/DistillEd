// Things a student types into the Ask box that are instructions to the APP
// rather than questions for the model.
//
// Two families: study recipes (`/cornell`, `/recipe name ...`, `/recipes`,
// see `study_recipes.dart`), and turning cloud AI on and off. The cloud one
// earns a command because the alternative is a trip out to Settings in the middle of a
// question, and because the moment someone wants the cloud model is usually the
// moment the on-device one has just given them a poor answer — three taps away
// from where they are looking.
//
// Pure string work, deliberately: what a phrase means is decided here and unit
// tested, and the notifier only has to act on the result.
//
// Two rules shape the matching:
//   • A slash command is EXACT. `/cloud on` does one thing and nothing else.
//   • Natural phrasing is matched narrowly, and only when the whole input is
//     the request. "Use the cloud model" is a command; "what did I write about
//     cloud computing" is a question and must reach the model untouched.
//     Getting this wrong in the permissive direction silently eats questions,
//     which is far worse than making someone type the slash version.

import 'study_recipes.dart';

/// A recognised app-level instruction.
sealed class ChatCommand {
  const ChatCommand();
}

/// Turn cloud AI on or off. [enable] null means "just tell me the state".
class CloudModelCommand extends ChatCommand {
  final bool? enable;
  const CloudModelCommand(this.enable);
}

/// Open the model picker (`/model`), to choose who answers.
class ModelPickerCommand extends ChatCommand {
  const ModelPickerCommand();
}

/// Run a study recipe over the current scope; [focus] is whatever followed
/// its name.
class RunRecipeCommand extends ChatCommand {
  final StudyRecipe recipe;
  final String focus;
  const RunRecipeCommand(this.recipe, this.focus);
}

/// `/recipes`: list them.
class ListRecipesCommand extends ChatCommand {
  const ListRecipesCommand();
}

/// `/recipe name what to do`: save (or replace) one of the student's own.
/// [name] is null when the name given was not usable.
class SaveRecipeCommand extends ChatCommand {
  final String? name;
  final String instruction;
  const SaveRecipeCommand(this.name, this.instruction);
}

/// `/recipe remove name`.
class RemoveRecipeCommand extends ChatCommand {
  final String name;
  const RemoveRecipeCommand(this.name);
}

/// A `/`-prefixed word that isn't a command we know. Recognised so the app can
/// say so, rather than sending `/clod on` to the model as a question.
class UnknownSlashCommand extends ChatCommand {
  final String raw;
  const UnknownSlashCommand(this.raw);
}

/// Parses [input] as a command, or null when it is an ordinary question.
/// [recipes] are the study recipes a `/name` may run.
ChatCommand? parseChatCommand(
  String input, {
  List<StudyRecipe> recipes = kBuiltInRecipes,
}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('/')) return _parseSlash(trimmed, recipes);
  return _parseNatural(trimmed);
}

ChatCommand? _parseSlash(String input, List<StudyRecipe> recipes) {
  final parts = input.substring(1).trim().split(RegExp(r'\s+'));
  final name = parts.first.toLowerCase();
  final argument = parts.length > 1 ? parts[1].toLowerCase() : '';
  // What followed the first word, as typed.
  final rest = parts.length > 1
      ? input.substring(1).trim().substring(parts.first.length).trim()
      : '';

  if (name == 'recipes') {
    return rest.isEmpty ? const ListRecipesCommand() : UnknownSlashCommand(input);
  }
  if (name == 'recipe') {
    if (argument == 'remove' && parts.length == 3) {
      return RemoveRecipeCommand(parts[2].toLowerCase());
    }
    if (parts.length < 3) return UnknownSlashCommand(input);
    final instruction = rest.substring(parts[1].length).trim();
    return SaveRecipeCommand(recipeName(parts[1]), instruction);
  }
  for (final r in recipes) {
    if (r.name == name) return RunRecipeCommand(r, rest);
  }

  // Exact, like every slash command: `/model` and nothing after it. A model is
  // chosen from the list the picker shows, not by typing a name here.
  if (name == 'model') {
    return argument.isEmpty
        ? const ModelPickerCommand()
        : UnknownSlashCommand(input);
  }
  if (name != 'cloud') return UnknownSlashCommand(input);

  return switch (argument) {
    'on' || 'enable' || 'enabled' || 'yes' => const CloudModelCommand(true),
    'off' || 'disable' || 'disabled' || 'no' => const CloudModelCommand(false),
    // A bare `/cloud` reports the current state rather than guessing which way
    // the student meant to flip it.
    '' => const CloudModelCommand(null),
    _ => UnknownSlashCommand(input),
  };
}

/// Whole-input natural phrasings, matched against a short fixed list.
///
/// A list rather than a pattern on purpose. Anything cleverer — "does the input
/// mention cloud and a verb?" — starts eating questions about cloud storage,
/// cloud computing and cumulus clouds, and a question silently swallowed by a
/// setting change is a far worse failure than a phrasing that wasn't
/// recognised.
ChatCommand? _parseNatural(String input) {
  final normalized = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (_enablePhrases.contains(normalized)) return const CloudModelCommand(true);
  if (_disablePhrases.contains(normalized)) {
    return const CloudModelCommand(false);
  }
  return null;
}

const Set<String> _enablePhrases = {
  'use the cloud model',
  'use cloud model',
  'use the cloud',
  'switch to the cloud model',
  'switch to cloud model',
  'switch to the cloud',
  'turn on cloud ai',
  'turn on the cloud model',
  'turn on cloud',
  'enable cloud ai',
  'enable cloud',
};

const Set<String> _disablePhrases = {
  'use the local model',
  'use local model',
  'switch to the local model',
  'switch to local model',
  'switch to local',
  'turn off cloud ai',
  'turn off the cloud model',
  'turn off cloud',
  'disable cloud ai',
  'disable cloud',
  'go local',
  'stay local',
};

/// The confirmation shown after a cloud command runs.
///
/// [enabled] is the state AFTER the change. [privacyAsksEachTime] adds the
/// second sentence, because turning the setting on is not the same as agreeing
/// to a cloud call — under `askEachTime` each request is still confirmed, and a
/// student told only "cloud AI is on" would reasonably expect otherwise.
String cloudCommandConfirmation({
  required bool enabled,
  required bool privacyAsksEachTime,
}) {
  if (!enabled) {
    return 'Cloud AI is off. Everything runs on your device.';
  }
  return privacyAsksEachTime
      ? "Cloud AI is on. You'll still be asked before anything is sent."
      : 'Cloud AI is on.';
}

/// The reply to a bare `/cloud`.
String cloudStateReport({required bool enabled}) => enabled
    ? 'Cloud AI is on. Type /cloud off to keep everything on your device.'
    : 'Cloud AI is off. Type /cloud on to allow the cloud model.';
