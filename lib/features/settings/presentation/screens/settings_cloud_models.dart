part of 'settings_screen.dart';

// Cloud AIs the student reaches with their own key: the list on the AI models
// screen, and the screen that adds one. See docs/AI_TUTOR_PLAN.md part 1.

/// The cloud models card: Margo's own (not available yet), then one row per AI
/// the student added, then "Add an AI".
class _CloudModelsCard extends ConsumerWidget {
  const _CloudModelsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final connections = ref.watch(userConnectionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingsCard(
          icon: AppIcons.cloud,
          title: 'Cloud models',
          children: [
            const _SettingsRow(
              icon: AppIcons.cloud,
              title: 'From Margo',
              subtitle: 'Free, budget and premium models are coming soon.',
            ),
            for (final connection in connections)
              _SettingsRow(
                icon: AppIcons.key,
                title: connection.label,
                subtitle: '${_modelCount(connection.models.length)} · '
                    '${connection.host}',
                trailing: TextButton(
                  onPressed: () => _confirmRemove(context, ref, connection),
                  child: Text(
                    'Remove',
                    style: TextStyle(
                      fontFamily: 'ModulusPro',
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
            _SettingsRow(
              icon: AppIcons.key,
              title: 'Add an AI',
              subtitle: 'Use your own key from OpenRouter, Groq, Mistral and '
                  'others.',
              trailing: Icon(Icons.add, color: c.accent),
              onTap: () => context.push('/settings/models/add'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(
            'Your key stays on this device and is only used when you pick '
            'that model to answer. Reading and analysing pages in the '
            'background never uses it.',
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }

  static String _modelCount(int count) =>
      count == 1 ? '1 model' : '$count models';

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    UserConnection connection,
  ) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${connection.label}?'),
        content: const Text(
          'Its key is deleted from this device. You can add it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) {
      await ref.read(userConnectionsProvider.notifier).delete(connection.id);
    }
  }
}

/// Adds a cloud AI with the student's own key: pick the provider, type the key,
/// check it, tick the models to use, save.
///
/// Nothing is saved until the key has been checked and a model chosen, so a key
/// that does not work never ends up in the list.
class AddConnectionScreen extends ConsumerStatefulWidget {
  const AddConnectionScreen({super.key});

  @override
  ConsumerState<AddConnectionScreen> createState() =>
      _AddConnectionScreenState();
}

class _AddConnectionScreenState extends ConsumerState<AddConnectionScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _key = TextEditingController();
  final _modelId = TextEditingController();
  final _filter = TextEditingController();

  ProviderPreset _preset = ProviderPreset.all.first;
  bool _showKey = false;
  bool _busy = false;
  String? _error;

  /// What the last check found. Null until a key has been checked.
  ConnectionTestResult? _result;
  final _picked = <String>{};

  /// For a provider that does not say which models can call tools.
  bool _toolsForAll = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _key.dispose();
    _modelId.dispose();
    _filter.dispose();
    super.dispose();
  }

  String get _baseUrl => _preset.id == ProviderPreset.customId
      ? _address.text.trim()
      : _preset.baseUrl;

  String get _label {
    final typed = _name.text.trim();
    if (typed.isNotEmpty) return typed;
    return _preset.id == ProviderPreset.customId ? 'My AI' : _preset.name;
  }

  /// A new check is needed whenever what it checked has changed.
  void _invalidate() {
    if (_result == null && _error == null) return;
    setState(() {
      _result = null;
      _error = null;
      _picked.clear();
    });
  }

  Future<void> _check() async {
    final key = _key.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Paste your API key first.');
      return;
    }
    final invalid = validateBaseUrl(_baseUrl);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _picked.clear();
    });
    final result = await ref
        .read(modelConnectionTesterProvider)
        .listModels(baseUrl: _baseUrl, apiKey: key);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
      if (result is ConnectionFailed) _error = result.message;
    });
  }

  /// For a provider with no model list: checks the one typed model answers.
  Future<void> _checkTypedModel() async {
    final modelId = _modelId.text.trim();
    if (modelId.isEmpty) {
      setState(() => _error = 'Type the model\'s name as the provider writes it.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(modelConnectionTesterProvider).probe(
          baseUrl: _baseUrl,
          apiKey: _key.text.trim(),
          modelId: modelId,
          label: _label,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result is ConnectionOk) {
        _picked
          ..clear()
          ..add(modelId);
      } else if (result is ConnectionFailed) {
        _error = result.message;
      }
    });
  }

  Future<void> _save() async {
    if (_picked.isEmpty) {
      setState(() => _error = 'Tick at least one model to use.');
      return;
    }
    final result = _result;
    final listed = result is ConnectionOk ? result : null;
    final connection = UserConnection(
      id: _newId(),
      label: _label,
      presetId: _preset.id,
      baseUrl: _baseUrl,
      models: [
        for (final modelId in _picked.toList()..sort())
          UserModel(
            modelId: modelId,
            displayName: modelId,
            contextWindowTokens:
                listed?.contextWindows[modelId] ?? kUnknownModelWindowTokens,
            supportsTools:
                _toolsForAll || (listed?.toolModels.contains(modelId) ?? false),
          ),
      ],
    );
    setState(() => _busy = true);
    final saved = await ref
        .read(userConnectionsProvider.notifier)
        .save(connection, apiKey: _key.text.trim());
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _busy = false;
        _error = "The key couldn't be stored securely on this device, so "
            'nothing was saved.';
      });
      return;
    }
    Navigator.of(context).maybePop();
  }

  static String _newId() {
    final random = math.Random.secure();
    return [
      for (var i = 0; i < 8; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final result = _result;
    final isCustom = _preset.id == ProviderPreset.customId;

    return Scaffold(
      appBar: settingsAppBar(context, 'Add an AI'),
      backgroundColor: c.bgPrimary,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Use a key from your own account with an AI provider. '
                  'Questions you send to it are billed by them, to you.',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _FieldLabel('Provider'),
                DropdownButtonFormField<String>(
                  key: const Key('conn-provider'),
                  initialValue: _preset.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final preset in [
                      ...ProviderPreset.all,
                      ProviderPreset.custom,
                    ])
                      DropdownMenuItem(value: preset.id, child: Text(preset.name)),
                  ],
                  onChanged: _busy
                      ? null
                      : (id) {
                          if (id == null) return;
                          setState(() => _preset = ProviderPreset.byId(id));
                          _invalidate();
                        },
                ),
                if (isCustom) ...[
                  const SizedBox(height: 16),
                  _FieldLabel('Address'),
                  TextField(
                    key: const Key('conn-url'),
                    controller: _address,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: (_) => _invalidate(),
                    decoration: const InputDecoration(
                      hintText: 'https://api.example.com/v1',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _FieldLabel('Name'),
                TextField(
                  key: const Key('conn-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: _label,
                    helperText: 'What you want to call it in the model list.',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                _FieldLabel('API key'),
                TextField(
                  key: const Key('conn-key'),
                  controller: _key,
                  obscureText: !_showKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => _invalidate(),
                  decoration: InputDecoration(
                    helperText: 'Kept in this device\'s secure storage only.',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: _showKey ? 'Hide key' : 'Show key',
                      icon: Icon(
                        _showKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _showKey = !_showKey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    key: const Key('conn-test'),
                    style: FilledButton.styleFrom(backgroundColor: c.accent),
                    onPressed: _busy ? null : _check,
                    child: Text(
                      result == null ? 'Check key' : 'Check again',
                      style: TextStyle(color: c.onAccent),
                    ),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (result is ConnectionOk) ...[
                  const SizedBox(height: 24),
                  _ModelChecklist(
                    modelIds: result.modelIds,
                    picked: _picked,
                    filter: _filter,
                    onChanged: () => setState(() => _error = null),
                  ),
                ],
                if (result is ConnectionNoModelList) ...[
                  const SizedBox(height: 24),
                  _FieldLabel('Model'),
                  Text(
                    'This provider does not list its models. Type the name of '
                    'the one you want, exactly as the provider writes it.',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('conn-model-id'),
                          controller: _modelId,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        key: const Key('conn-check-model'),
                        onPressed: _busy ? null : _checkTypedModel,
                        child: const Text('Check'),
                      ),
                    ],
                  ),
                  if (_picked.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_picked.first} answered.',
                      style: TextStyle(fontSize: 13, color: c.accent),
                    ),
                  ],
                ],
                if (result is ConnectionOk || result is ConnectionNoModelList) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _toolsForAll,
                    onChanged: (value) => setState(() => _toolsForAll = value),
                    title: const Text('These models can use tools'),
                    subtitle: const Text(
                      'Needed for Research. Turn on only if the provider says '
                      'the model supports tool or function calling.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      key: const Key('conn-save'),
                      style: FilledButton.styleFrom(backgroundColor: c.accent),
                      onPressed: _busy ? null : _save,
                      child: Text('Save', style: TextStyle(color: c.onAccent)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'ModulusPro',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

/// The models a key can use, to tick. Some providers list several hundred, so
/// there is a search box and the list scrolls inside its own frame.
class _ModelChecklist extends StatefulWidget {
  final List<String> modelIds;
  final Set<String> picked;
  final TextEditingController filter;
  final VoidCallback onChanged;

  const _ModelChecklist({
    required this.modelIds,
    required this.picked,
    required this.filter,
    required this.onChanged,
  });

  @override
  State<_ModelChecklist> createState() => _ModelChecklistState();
}

class _ModelChecklistState extends State<_ModelChecklist> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final query = widget.filter.text.trim().toLowerCase();
    final shown = [
      for (final id in widget.modelIds)
        if (query.isEmpty || id.toLowerCase().contains(query)) id,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel(
          widget.picked.isEmpty
              ? 'Models to use'
              : 'Models to use (${widget.picked.length} ticked)',
        ),
        if (widget.modelIds.length > 8) ...[
          TextField(
            key: const Key('conn-filter'),
            controller: widget.filter,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search models',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.modelIds.isEmpty)
          Text(
            'The key works, but the provider listed no models for it.',
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final id = shown[index];
                return CheckboxListTile(
                  dense: true,
                  value: widget.picked.contains(id),
                  title: Text(id),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (ticked) {
                    setState(() {
                      ticked == true
                          ? widget.picked.add(id)
                          : widget.picked.remove(id);
                    });
                    widget.onChanged();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
