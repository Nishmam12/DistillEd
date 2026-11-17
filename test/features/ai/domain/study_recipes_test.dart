import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/ai/domain/chat_commands.dart';
import 'package:margo/features/ai/domain/study_recipes.dart';

void main() {
  test('a recipe name runs it, with the rest as its focus', () {
    final c = parseChatCommand('/flashcards  Enzymes and pH');
    expect(c, isA<RunRecipeCommand>());
    c as RunRecipeCommand;
    expect(c.recipe.name, 'flashcards');
    expect(c.focus, 'Enzymes and pH');
    expect(c.recipe.promptWith(c.focus), endsWith('Focus on: Enzymes and pH'));
    expect(c.recipe.promptWith(''), c.recipe.instruction);
  });

  test("the student's own recipes run too; unknown names stay unknown", () {
    const own = [StudyRecipe('exam-prep', 'List likely questions.')];
    expect(parseChatCommand('/exam-prep', recipes: own), isA<RunRecipeCommand>());
    expect(parseChatCommand('/exam-prep'), isA<UnknownSlashCommand>());
    // The old commands are unchanged.
    expect(parseChatCommand('/cloud on'), isA<CloudModelCommand>());
    expect(parseChatCommand('/model'), isA<ModelPickerCommand>());
    // A question is still a question.
    expect(parseChatCommand('what are flashcards'), isNull);
  });

  test('save, list and remove', () {
    final save = parseChatCommand('/recipe Exam Prep! List likely questions');
    // A name is one word; "Prep!" starts the instruction.
    expect(save, isA<SaveRecipeCommand>());
    save as SaveRecipeCommand;
    expect(save.name, 'exam');
    expect(save.instruction, 'Prep! List likely questions');

    final bad = parseChatCommand('/recipe cloud do something');
    expect((bad as SaveRecipeCommand).name, isNull);
    expect(parseChatCommand('/recipe onlyname'), isA<UnknownSlashCommand>());
    expect(parseChatCommand('/recipes'), isA<ListRecipesCommand>());
    expect((parseChatCommand('/recipe remove Exam') as RemoveRecipeCommand).name,
        'exam');
  });

  test('recipe names', () {
    expect(recipeName('Exam Prep!'), 'exam-prep');
    expect(recipeName('model'), isNull);
    expect(recipeName('  !!  '), isNull);
  });
}
