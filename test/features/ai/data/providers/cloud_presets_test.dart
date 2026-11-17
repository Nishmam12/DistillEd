import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/ai/data/providers/cloud_presets.dart';

void main() {
  test('preset ids are unique and custom is last', () {
    final ids = kCloudPresets.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(kCloudPresets.last.isCustom, isTrue);
    expect(kCloudPresets.first.id, 'openrouter');
  });

  test('every non-custom preset uses https', () {
    for (final p in kCloudPresets.where((p) => !p.isCustom)) {
      expect(p.baseUrl, startsWith('https://'), reason: p.id);
      expect(p.keyPageUrl, startsWith('https://'), reason: p.id);
    }
  });

  test('cloudPresetById', () {
    expect(cloudPresetById('gemini')!.label, 'Google Gemini');
    expect(cloudPresetById('nope'), isNull);
  });

  test('isAllowedCustomBaseUrl', () {
    const allowed = [
      'https://api.example.com/v1',
      'http://localhost:11434/v1',
      'http://192.168.1.20:8080/v1',
      'http://10.0.0.5/v1',
      'http://172.16.0.1/v1',
      'http://127.0.0.1:8000',
      'http://169.254.1.1',
      'http://my-box.local:8080/v1',
      'http://[::1]:8080/v1',
      'http://[fd00::1]/v1',
      '  https://x.example/v1/  ',
    ];
    const refused = [
      'http://example.com',
      'http://172.32.0.1',
      'http://8.8.8.8',
      'ftp://x',
      '',
      'https://',
      'https://user:pass@api.example.com/v1',
      'api.example.com',
    ];
    for (final u in allowed) {
      expect(isAllowedCustomBaseUrl(u), isTrue, reason: u);
    }
    for (final u in refused) {
      expect(isAllowedCustomBaseUrl(u), isFalse, reason: u);
    }
  });

  test('normalizeCloudBaseUrl trims and strips trailing slashes', () {
    expect(normalizeCloudBaseUrl('  https://a.b/v1//  '), 'https://a.b/v1');
    expect(normalizeCloudBaseUrl('https://a.b/v1'), 'https://a.b/v1');
    expect(normalizeCloudBaseUrl(''), '');
  });

  test('cloudProviderName', () {
    expect(cloudProviderName(presetId: 'openrouter', baseUrl: ''),
        'OpenRouter');
    expect(
        cloudProviderName(
            presetId: 'custom', baseUrl: 'http://localhost:11434/v1'),
        'localhost');
    expect(cloudProviderName(presetId: 'custom', baseUrl: ''),
        'your cloud AI provider');
    expect(cloudProviderName(presetId: '', baseUrl: 'https://a.b'),
        'your cloud AI provider');
  });
}
