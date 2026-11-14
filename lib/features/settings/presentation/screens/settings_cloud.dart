part of 'settings_screen.dart';

/// What [CloudProviderDialog] hands back on Save or Remove. Cancel pops null.
class CloudProviderResult {
  const CloudProviderResult({
    required this.presetId,
    required this.baseUrl,
    required this.model,
    required this.contextTokens,
    this.newKey,
    this.clearKey = false,
  });

  final String presetId;
  final String baseUrl;
  final String model;

  /// The chosen model's context length from the provider's list, or 0.
  final int contextTokens;

  /// A key the user typed, already checked against the provider. Null keeps
  /// the saved one.
  final String? newKey;

  /// The user asked to remove the saved key.
  final bool clearKey;
}

typedef CloudModelLister =
    Future<List<CloudModel>> Function({
      required String baseUrl,
      required String apiKey,
    });

/// Picks a cloud AI provider, its key and a model. A newly typed key is
/// checked by listing the provider's models before the dialog closes, so a
/// rejected key is never saved.
class CloudProviderDialog extends StatefulWidget {
  const CloudProviderDialog({
    super.key,
    required this.presetId,
    required this.baseUrl,
    required this.model,
    required this.hasKey,
    this.listModels = OpenAiCompatibleProvider.listModels,
  });

  /// The saved settings. The saved key itself is never passed in or shown.
  final String presetId;
  final String baseUrl;
  final String model;
  final bool hasKey;

  final CloudModelLister listModels;

  @override
  State<CloudProviderDialog> createState() => _CloudProviderDialogState();
}

class _CloudProviderDialogState extends State<CloudProviderDialog> {
  late String _presetId = cloudPresetById(widget.presetId)?.id ?? 'openrouter';
  late final _baseUrl = TextEditingController(
    text: cloudPresetById(widget.presetId)?.isCustom ?? false
        ? widget.baseUrl
        : '',
  );
  final _key = TextEditingController();
  late final _modelText = TextEditingController(text: widget.model);

  bool _obscured = true;
  bool _saving = false;

  // The model list and its outcome belong to one (base URL, key) pair: any
  // edit to either clears them.
  Future<void>? _pending;
  String? _pendingSig;
  String? _loadedSig;
  bool _loading = false;
  List<CloudModel>? _models;
  String? _selected;
  bool _listFailed = false;
  bool _keyRejected = false;

  bool _urlError = false;
  bool _modelError = false;
  bool _keyMissing = false;

  CloudPreset get _preset => cloudPresetById(_presetId)!;
  String get _url => _preset.isCustom ? _baseUrl.text : _preset.baseUrl;
  // The key exactly as it will be stored, so the one checked is the one saved.
  String get _newKey => SettingsNotifier.sanitizeToken(_key.text);
  bool get _urlOk => !_preset.isCustom || isAllowedCustomBaseUrl(_url);

  /// A saved key belongs to the provider it was pasted for. Changing the
  /// provider or its URL means the saved key must not be sent there, so a new
  /// key is required.
  bool get _providerChanged =>
      _presetId != widget.presetId ||
      normalizeCloudBaseUrl(_url) != normalizeCloudBaseUrl(widget.baseUrl);

  /// The saved key can be kept: one exists and the provider is unchanged.
  bool get _keepsSavedKey => widget.hasKey && !_providerChanged;
  String _sig() => '${normalizeCloudBaseUrl(_url)}\n$_newKey';

  @override
  void dispose() {
    _baseUrl.dispose();
    _key.dispose();
    _modelText.dispose();
    super.dispose();
  }

  /// The URL, provider or key changed: drop the old list. Nothing is sent until
  /// the user asks (Check key, or Save), so a typed key only ever goes to the
  /// provider on screen at that moment, never to one passed on the way.
  void _inputsChanged() {
    setState(() {
      _pending = null;
      _pendingSig = null;
      _loadedSig = null;
      _loading = false;
      _models = null;
      _listFailed = false;
      _keyRejected = false;
      _urlError = false;
      _keyMissing = false;
    });
  }

  Future<void> _load() {
    final sig = _sig();
    if (_pendingSig == sig && _pending != null) return _pending!;
    _pendingSig = sig;
    return _pending = _fetch(sig, normalizeCloudBaseUrl(_url), _newKey);
  }

  Future<void> _fetch(String sig, String url, String key) async {
    setState(() => _loading = true);
    List<CloudModel>? models;
    var rejected = false;
    try {
      models = await widget.listModels(baseUrl: url, apiKey: key);
    } on CloudModelListException catch (e) {
      rejected = e.keyRejected;
    } catch (_) {
      // Any other failure is a non-auth one: fall back to a typed model name.
    }
    if (!mounted || _pendingSig != sig) return;
    setState(() {
      _loading = false;
      _pending = null;
      _pendingSig = null;
      _loadedSig = sig;
      _keyRejected = rejected;
      _models = (models?.isEmpty ?? true) ? null : models;
      _listFailed = !rejected && _models == null;
      final ids = [for (final m in _models ?? const <CloudModel>[]) m.id];
      _selected = ids.isEmpty
          ? null
          : (ids.contains(widget.model) ? widget.model : ids.first);
    });
  }

  /// One save at a time: a second tap while a check runs must not pop the
  /// dialog twice (which would close the screen behind it).
  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    try {
      await _saveOnce();
    } finally {
      _saving = false;
    }
  }

  Future<void> _saveOnce() async {
    if (!_urlOk) {
      setState(() => _urlError = true);
      return;
    }
    if (_newKey.isEmpty && !_keepsSavedKey) {
      setState(() => _keyMissing = true);
      return;
    }
    if (_newKey.isNotEmpty) {
      final sig = _sig();
      if (_loadedSig != sig) {
        await _load();
        // The user edited the URL or key while it ran: let them save again.
        if (!mounted || _loadedSig != sig) return;
      }
      if (_keyRejected) return;
    }
    final model = (_models != null ? _selected : _modelText.text)?.trim() ?? '';
    if (model.isEmpty) {
      setState(() => _modelError = true);
      return;
    }
    var contextTokens = 0;
    for (final m in _models ?? const <CloudModel>[]) {
      if (m.id == model) contextTokens = m.contextLength ?? 0;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      CloudProviderResult(
        presetId: _presetId,
        baseUrl: normalizeCloudBaseUrl(_url),
        model: model,
        contextTokens: contextTokens,
        newKey: _newKey.isEmpty ? null : _newKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final preset = _preset;
    return AlertDialog(
      backgroundColor: c.surface,
      title: const Text('Cloud AI provider'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use your own key from a cloud AI provider. The key stays on '
              'this device and is only sent to that provider.',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('cloudPreset'),
              initialValue: _presetId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final p in kCloudPresets)
                  DropdownMenuItem(value: p.id, child: Text(p.label)),
              ],
              onChanged: (id) {
                if (id == null || id == _presetId) return;
                _presetId = id;
                _inputsChanged();
              },
            ),
            if (preset.isCustom) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('cloudBaseUrl'),
                controller: _baseUrl,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                onChanged: (_) => _inputsChanged(),
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://example.com/v1',
                  border: const OutlineInputBorder(),
                  errorText: _urlError
                      ? 'Use https://, or http:// only for localhost or a '
                            'private address.'
                      : null,
                  errorMaxLines: 3,
                ),
              ),
            ],
            if (preset.keyPageUrl.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _openHuggingFace(context, preset.keyPageUrl),
                  child: Text('Get a key from ${preset.label}'),
                ),
              )
            else
              const SizedBox(height: 12),
            TextField(
              key: const ValueKey('cloudKey'),
              controller: _key,
              obscureText: _obscured,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => _inputsChanged(),
              decoration: InputDecoration(
                hintText: _keepsSavedKey
                    ? 'Saved on this device. Leave blank to keep it.'
                    : 'Paste this provider’s API key',
                border: const OutlineInputBorder(),
                errorText: _keyRejected
                    ? 'The provider rejected this key. Check it and try again.'
                    : _keyMissing
                    ? (widget.hasKey
                        ? 'The saved key is for another provider. Paste the '
                            'key for this one.'
                        : 'Paste your API key.')
                    : null,
                errorMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: _obscured ? 'Show' : 'Hide',
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_newKey.isNotEmpty && _urlOk && _models == null && !_loading)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('cloudCheckKey'),
                  onPressed: _load,
                  child: const Text('Check key and load models'),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_models != null)
              DropdownButtonFormField<String>(
                // A new list replaces the field, so its initial value applies.
                key: ObjectKey(_models),
                initialValue: _selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final m in _models!)
                    DropdownMenuItem(
                      value: m.id,
                      child: Text(m.id, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) => setState(() => _selected = id),
              )
            else ...[
              TextField(
                key: const ValueKey('cloudModelName'),
                controller: _modelText,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) {
                  if (_modelError) setState(() => _modelError = false);
                },
                decoration: InputDecoration(
                  labelText: 'Model name',
                  border: const OutlineInputBorder(),
                  errorText: _modelError ? 'Choose or type a model.' : null,
                ),
              ),
              if (_listFailed) ...[
                const SizedBox(height: 6),
                Text(
                  'Could not load the model list. Type the model name.',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (widget.hasKey)
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              CloudProviderResult(
                presetId: widget.presetId,
                baseUrl: widget.baseUrl,
                model: widget.model,
                contextTokens: 0,
                clearKey: true,
              ),
            ),
            child: Text(
              'Remove key',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.accent),
          onPressed: _loading ? null : _save,
          child: Text('Save', style: TextStyle(color: c.onAccent)),
        ),
      ],
    );
  }
}
