part of 'settings_screen.dart';

/// "What the tutor knows about you" (Evernote's AI memory screen): everything
/// the tutor is told about the student, to read, change or forget. That is the
/// concepts they missed in a quiz or that were flagged as gaps (per notebook),
/// their preferred level and kind of explanation, and a note in their own
/// words. All of it lives on the device.
class TutorMemoryScreen extends ConsumerStatefulWidget {
  const TutorMemoryScreen({super.key});

  @override
  ConsumerState<TutorMemoryScreen> createState() => _TutorMemoryScreenState();
}

typedef _Tricky = ({String notebook, int notebookId, ConceptMastery concept});

class _TutorMemoryScreenState extends ConsumerState<TutorMemoryScreen> {
  final _note = TextEditingController();
  LearningPreferences _prefs = LearningPreferences.empty;
  List<_Tricky>? _tricky;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final memory = ref.read(learningMemoryProvider);
    final note = await TutorNoteStore.load();
    final prefs = await memory.loadPreferences();
    final tricky = <_Tricky>[];
    for (final book in ref.read(homeNotifierProvider)) {
      for (final c in await memory.allConcepts(book.id)) {
        if (c.timesMissedInQuiz > 0 || c.timesFlaggedAsGap > 0) {
          tricky.add((notebook: book.title, notebookId: book.id, concept: c));
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _note.text = note;
      _prefs = prefs;
      _tricky = tricky;
    });
  }

  Future<void> _savePrefs(LearningPreferences next) async {
    setState(() => _prefs = next);
    await ref.read(learningMemoryProvider).savePreferences(next);
  }

  Future<void> _forget(_Tricky t) async {
    await ref
        .read(learningMemoryProvider)
        .forgetConcept(t.notebookId, t.concept.conceptKey);
    setState(() => _tricky = [
          for (final o in _tricky ?? const <_Tricky>[])
            if (o != t) o,
        ]);
  }

  static String _why(ConceptMastery c) => [
        if (c.timesMissedInQuiz > 0)
          'missed in a quiz${c.timesMissedInQuiz > 1 ? ' ${c.timesMissedInQuiz} times' : ''}',
        if (c.timesFlaggedAsGap > 0) 'not explained in your notes yet',
      ].join(', ');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = TextStyle(
        fontFamily: 'ModulusPro',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: c.textSecondary);
    final tricky = _tricky;
    final field = TextStyle(
        fontFamily: 'ModulusPro', fontSize: 16, color: c.textPrimary);

    return Scaffold(
      appBar: settingsAppBar(context, 'What the tutor knows about you'),
      backgroundColor: c.bgPrimary,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'The tutor is told this when it answers, to pitch what it '
                  'says. It stays on this device, and goes to a cloud model '
                  'only when you use one.',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                const SizedBox(height: 20),
                Text('About you', style: label),
                const SizedBox(height: 6),
                TextField(
                  key: const ValueKey('tutorNote'),
                  controller: _note,
                  maxLength: kMaxAboutMeChars,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'e.g. First-year nursing student, English is '
                        'my second language',
                  ),
                  onChanged: TutorNoteStore.save,
                ),
                const SizedBox(height: 12),
                Text('How you like to learn', style: label),
                const SizedBox(height: 6),
                DropdownButtonFormField<KnowledgeLevel?>(
                  key: const ValueKey('tutorLevel'),
                  initialValue: _prefs.preferredDifficulty,
                  style: field,
                  decoration: const InputDecoration(labelText: 'Level'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Not set')),
                    for (final l in KnowledgeLevel.values)
                      DropdownMenuItem(
                          value: l,
                          child: Text(l.name[0].toUpperCase() + l.name.substring(1))),
                  ],
                  onChanged: (l) => _savePrefs(LearningPreferences(
                    preferredDifficulty: l,
                    preferredExplainMode: _prefs.preferredExplainMode,
                  )),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ExplainMode?>(
                  key: const ValueKey('tutorMode'),
                  initialValue: _prefs.preferredExplainMode,
                  style: field,
                  decoration:
                      const InputDecoration(labelText: 'Explanations'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Not set')),
                    for (final m in ExplainMode.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (m) => _savePrefs(LearningPreferences(
                    preferredDifficulty: _prefs.preferredDifficulty,
                    preferredExplainMode: m,
                  )),
                ),
                const SizedBox(height: 20),
                Text('Things you find tricky', style: label),
                const SizedBox(height: 6),
                if (tricky == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (tricky.isEmpty)
                  Text(
                    'Nothing yet. Concepts you miss in a quiz, or that your '
                    'notes mention without explaining, show up here.',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  )
                else
                  for (final t in tricky)
                    ListTile(
                      key: ValueKey('tricky:${t.notebookId}:${t.concept.conceptKey}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.concept.conceptName),
                      subtitle: Text('${t.notebook} · ${_why(t.concept)}'),
                      trailing: IconButton(
                        tooltip: 'Forget this',
                        icon: const Icon(Icons.close),
                        onPressed: () => _forget(t),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
