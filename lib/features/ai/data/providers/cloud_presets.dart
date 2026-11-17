// The cloud AI providers the Settings dialog offers, plus the URL rules for a
// custom OpenAI-compatible endpoint. Every preset speaks the OpenAI chat
// completions protocol, so one client (`OpenAiCompatibleProvider`) serves all.

import 'dart:io' show InternetAddress, InternetAddressType;

class CloudPreset {
  const CloudPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.keyPageUrl,
  });

  final String id, label, baseUrl, keyPageUrl;

  bool get isCustom => id == 'custom';
}

const List<CloudPreset> kCloudPresets = [
  CloudPreset(
      id: 'openrouter',
      label: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      keyPageUrl: 'https://openrouter.ai/settings/keys'),
  CloudPreset(
      id: 'gemini',
      label: 'Google Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      keyPageUrl: 'https://aistudio.google.com/app/apikey'),
  CloudPreset(
      id: 'openai',
      label: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      keyPageUrl: 'https://platform.openai.com/api-keys'),
  CloudPreset(
      id: 'anthropic',
      label: 'Anthropic',
      baseUrl: 'https://api.anthropic.com/v1',
      keyPageUrl: 'https://platform.claude.com/settings/keys'),
  CloudPreset(
      id: 'groq',
      label: 'Groq',
      baseUrl: 'https://api.groq.com/openai/v1',
      keyPageUrl: 'https://console.groq.com/keys'),
  CloudPreset(
      id: 'mistral',
      label: 'Mistral',
      baseUrl: 'https://api.mistral.ai/v1',
      keyPageUrl: 'https://console.mistral.ai/api-keys'),
  CloudPreset(
      id: 'deepseek',
      label: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      keyPageUrl: 'https://platform.deepseek.com/api_keys'),
  CloudPreset(
      id: 'xai',
      label: 'xAI',
      baseUrl: 'https://api.x.ai/v1',
      keyPageUrl: 'https://console.x.ai'),
  CloudPreset(
      id: 'together',
      label: 'Together AI',
      baseUrl: 'https://api.together.xyz/v1',
      keyPageUrl: 'https://api.together.ai/settings/api-keys'),
  CloudPreset(
      id: 'custom',
      label: 'Custom (OpenAI-compatible)',
      baseUrl: '',
      keyPageUrl: ''),
];

CloudPreset? cloudPresetById(String id) {
  for (final p in kCloudPresets) {
    if (p.id == id) return p;
  }
  return null;
}

/// Trims [raw] and strips trailing slashes, so `$base/chat/completions` never
/// has a double slash.
String normalizeCloudBaseUrl(String raw) =>
    raw.trim().replaceFirst(RegExp(r'/+$'), '');

/// True when [raw] is safe to send an API key to: any `https://` URL, or
/// `http://` only for a host on this device or the local network (a
/// self-hosted server), where there is no TLS to be had. Never user info.
bool isAllowedCustomBaseUrl(String raw) {
  final uri = Uri.tryParse(normalizeCloudBaseUrl(raw));
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
  if (uri.userInfo.isNotEmpty) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return true;
  if (scheme != 'http') return false;
  final host = uri.host.toLowerCase();
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local')) {
    return true;
  }
  final ip = InternetAddress.tryParse(host);
  if (ip == null) return false;
  if (ip.isLoopback || ip.isLinkLocal) return true;
  final b = ip.rawAddress;
  if (ip.type == InternetAddressType.IPv4) {
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168);
  }
  return (b[0] & 0xfe) == 0xfc; // IPv6 unique-local, fc00::/7
}

/// The name to show the user for the configured provider: the preset label,
/// or the custom endpoint's host.
String cloudProviderName({required String presetId, required String baseUrl}) {
  final preset = cloudPresetById(presetId);
  if (preset != null && !preset.isCustom) return preset.label;
  if (preset != null) {
    final host = Uri.tryParse(normalizeCloudBaseUrl(baseUrl))?.host ?? '';
    if (host.isNotEmpty) return host;
  }
  return 'your cloud AI provider';
}
