// The providers the "Add an AI" screen offers by name, so a student picks
// "Groq" instead of typing an address.
//
// Every one of them speaks the OpenAI chat-completions format, which is what
// `OpenAiCompatibleProvider` sends. Nothing here is a model id: the models a
// key can use are fetched from the provider when the key is tested.
//
// Each address was read from the provider's own documentation on the date in
// its comment. An address that could not be confirmed that day says so.
// Anthropic is deliberately absent: add it only after checking how its
// compatibility endpoint is meant to be used.

import 'package:flutter/foundation.dart' show immutable;

@immutable
class ProviderPreset {
  final String id;
  final String name;

  /// Empty for [customId], where the student types the address.
  final String baseUrl;

  const ProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
  });

  static const String customId = 'custom';

  static const ProviderPreset custom = ProviderPreset(
    id: customId,
    name: 'Other (OpenAI-compatible)',
    baseUrl: '',
  );

  /// The named providers, in the order the screen lists them.
  static const List<ProviderPreset> all = [
    // openrouter.ai/docs/quickstart, 2026-11-16.
    ProviderPreset(
      id: 'openrouter',
      name: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
    ),
    // console.groq.com/docs/openai, 2026-11-16.
    ProviderPreset(
      id: 'groq',
      name: 'Groq',
      baseUrl: 'https://api.groq.com/openai/v1',
    ),
    // docs.mistral.ai/api, 2026-11-16.
    ProviderPreset(
      id: 'mistral',
      name: 'Mistral',
      baseUrl: 'https://api.mistral.ai/v1',
    ),
    // api-docs.deepseek.com, 2026-11-16.
    ProviderPreset(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
    ),
    // docs.x.ai/docs/api-reference, 2026-11-16 (base address only; the page
    // showed the Responses API, not chat completions).
    ProviderPreset(id: 'xai', name: 'xAI', baseUrl: 'https://api.x.ai/v1'),
    // NOT confirmed on the provider's page on 2026-11-16 (the page refused the
    // request). Check before release.
    ProviderPreset(
      id: 'openai',
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
    ),
    // NOT confirmed on the provider's page on 2026-11-16 (the page moved).
    // Check before release.
    ProviderPreset(
      id: 'gemini',
      name: 'Google Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    ),
  ];

  /// The preset with [id], or [custom] for an id this build does not know.
  static ProviderPreset byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return custom;
  }
}
