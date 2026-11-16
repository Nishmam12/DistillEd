// The [AiProvider] a feature is given when its answers should come from
// whichever model the student picked.
//
// It decides at CALL time, not when it is built, so changing the pick takes
// effect on the next question without rebuilding anything. A feature wired to
// this never knows there is a choice: it calls `generate` and budgets from
// `capabilities`, exactly as it did against the on-device model.
//
// One thing it will not do is fall back. When the picked model fails, the
// failure reaches the student. Quietly answering with the on-device model
// instead would show a different model's words under the picked model's name,
// and quietly trying another cloud provider would send their notes somewhere
// they never chose.
//
// Asking the student before a send is NOT done here. One thing the student
// asks for can be several requests (a long summary is read in sections), and a
// question per request would be absurd. The notifier that starts the work asks
// once, through `CloudSendGate`.

import '../ai_provider.dart';
import '../catalog/ai_model_entry.dart';
import '../catalog/answer_route.dart';

class SelectedAnswerProvider implements AiProvider {
  final AiProvider _local;
  final AnswerRoute Function() _route;
  final AiProvider Function(AiModelEntry model) _cloudFor;

  const SelectedAnswerProvider({
    required this._local,
    required this._route,
    required this._cloudFor,
  });

  AiProvider get _current => switch (_route()) {
        CloudDirect(:final model) => _cloudFor(model),
        LocalOnly() || LocalFirst() => _local,
      };

  /// The window of the model that will answer NOW. Callers budget their
  /// passages from this, so it has to follow the pick.
  @override
  AiCapabilities get capabilities => _current.capabilities;

  @override
  Stream<String> generate({
    required String prompt,
    String? systemPrompt,
    List<AiMessage>? history,
    AiGenerationOptions? options,
  }) =>
      _current.generate(
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: history,
        options: options,
      );
}
