// Who adds the task prefixes an embedding model expects, and what text it sees.
//
// A model's vector space is defined by more than its weights: the text it is fed,
// prefix and title included, is part of the contract. Recording that as data lets
// a second model with a different contract be added without guessing what the
// first one did (docs/TECH_MIGRATION_PLAN.md, phase 4.3).

/// Who prepends the task prefix before tokenizing.
enum PromptAppliedBy {
  /// flutter_edge_ai prepends the prefix for the task type it is given.
  plugin,

  /// The app prepends the prefix itself, and asks the runtime for none.
  app,

  /// Not decided yet. A spec with this contract cannot run.
  undecided,
}

/// What a model's input looks like: its prefixes, and whether the notebook title
/// rides at the front of the text.
class PromptContract {
  const PromptContract({
    required this.id,
    required this.appliedBy,
    required this.titleInText,
    this.documentPrefix,
    this.queryPrefix,
    this.candidates = const {},
  });

  /// Short and stable. A spec's modelId must contain it, so the index is
  /// invalidated when the contract changes.
  final String id;

  final PromptAppliedBy appliedBy;

  /// Whether the notebook title is written at the front of the text, followed by
  /// a blank line, before the passage.
  final bool titleInText;

  /// The prefixes the model was trained with. Recorded for documentation and
  /// tests; a [PromptAppliedBy.plugin] contract never applies them itself.
  final String? documentPrefix;
  final String? queryPrefix;

  /// Candidate (document, query) prefix pairs for a model whose contract is not
  /// chosen yet, recorded as each published source gives them. Never applied.
  final Map<String, (String document, String query)> candidates;

  /// EmbeddingGemma 300M, as flutter_edge_ai applies it. The plugin writes
  /// `title: none` for documents, so the app puts the title in the text instead.
  static const pluginGemma300m = PromptContract(
    id: 'titled',
    appliedBy: PromptAppliedBy.plugin,
    titleInText: true,
    documentPrefix: 'title: none | text: ',
    queryPrefix: 'task: search result | query: ',
  );

  /// EmbeddingGemma 2, until phase 5 decides its contract from the evaluation.
  static const undecided = PromptContract(
    id: 'UNSET',
    appliedBy: PromptAppliedBy.undecided,
    titleInText: false,
    candidates: {
      // The Hugging Face model card.
      'huggingface-card': (
        'title: {title} | text: {content}',
        'task: search result | query: {q}',
      ),
      // Google's LiteRT-LM documentation.
      'litert-lm-docs': (
        'task: search result | text:',
        'task: search query | text:',
      ),
    },
  );

  /// The text to embed for [passage], given the notebook [title] (null when there
  /// is none). The stored chunk keeps the bare passage; only the model sees the
  /// title.
  String embeddingInput(String? title, String passage) =>
      titleInText && title != null ? '$title\n\n$passage' : passage;
}
