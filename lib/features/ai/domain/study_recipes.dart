// Study recipes (Evernote's AI Prompts and Playbooks, turned toward study):
// a named instruction run over this page, this PDF or the notebook, so the
// same request gets the same kind of result every time. Typed in the Ask box
// as `/name`, with anything after the name as a focus ("/flashcards enzymes").
//
// A few are built in; the student saves their own with `/recipe name what to
// do`. Pure: storage is in `presentation/study_recipes_store.dart`.

class StudyRecipe {
  /// Lower-case letters, digits and dashes: what follows the slash.
  final String name;
  final String instruction;
  final bool builtIn;

  const StudyRecipe(this.name, this.instruction, {this.builtIn = false});

  /// What the model is asked: the instruction, narrowed by [focus] if given.
  String promptWith(String focus) => focus.trim().isEmpty
      ? instruction
      : '$instruction\nFocus on: ${focus.trim()}';
}

const List<StudyRecipe> kBuiltInRecipes = [
  StudyRecipe(
    'cornell',
    'Rewrite these notes as Cornell notes: a "Cues" list of the key '
        'questions and terms, a "Notes" section in short points, and a '
        'two-sentence "Summary".',
    builtIn: true,
  ),
  StudyRecipe(
    'flashcards',
    'Write 10 flashcards from these notes, each as "Q: ..." on one line and '
        '"A: ..." on the next.',
    builtIn: true,
  ),
  StudyRecipe(
    'key-terms',
    'List the key terms in these notes, each with a one-line definition '
        'taken from the notes.',
    builtIn: true,
  ),
  StudyRecipe(
    'new-to-this',
    'Explain what these notes cover to someone new to the subject: plain '
        'words, one idea at a time, building up step by step.',
    builtIn: true,
  ),
];

/// Names that are app commands, never recipes.
const Set<String> kReservedRecipeNames = {'cloud', 'model', 'recipe', 'recipes'};

/// [raw] as a recipe name ("Exam Prep!" -> "exam-prep"), or null when nothing
/// usable is left or it is a command's name.
String? recipeName(String raw) {
  final name = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (name.isEmpty || name.length > 30 || kReservedRecipeNames.contains(name)) {
    return null;
  }
  return name;
}
