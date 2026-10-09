import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/core/utils/external_links.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  const url = 'https://huggingface.co/litert-community/some-model';

  /// Records each attempt, and answers each mode with the given result.
  Future<bool> Function(Uri, LaunchMode) launcher(
    List<LaunchMode> attempts, {
    required Map<LaunchMode, Object> answers,
  }) =>
      (uri, mode) async {
        attempts.add(mode);
        final answer = answers[mode] ?? false;
        if (answer is Exception) throw answer;
        return answer as bool;
      };

  test('a link with no web scheme is refused without trying a browser',
      () async {
    final attempts = <LaunchMode>[];
    expect(
      await openExternalUrl('not a url', launch: launcher(attempts, answers: {})),
      isFalse,
    );
    expect(
      await openExternalUrl('javascript:alert(1)',
          launch: launcher(attempts, answers: {})),
      isFalse,
    );
    expect(attempts, isEmpty);
  });

  test('the first browser mode that takes the link is used, and no other',
      () async {
    final attempts = <LaunchMode>[];
    final opened = await openExternalUrl(url,
        launch: launcher(attempts,
            answers: {LaunchMode.inAppBrowserView: true}));

    expect(opened, isTrue);
    expect(attempts, [LaunchMode.inAppBrowserView]);
  });

  test('a mode that is unavailable falls through to the external browser',
      () async {
    final attempts = <LaunchMode>[];
    final opened = await openExternalUrl(url,
        launch: launcher(attempts, answers: {
          LaunchMode.inAppBrowserView:
              PlatformException(code: 'no custom tab provider'),
          LaunchMode.externalApplication: true,
        }));

    expect(opened, isTrue);
    expect(attempts, [
      LaunchMode.inAppBrowserView,
      LaunchMode.externalApplication,
    ]);
  });

  test('when no browser takes it, the answer is false and nothing is thrown',
      () async {
    final opened = await openExternalUrl(url,
        launch: launcher([], answers: {
          LaunchMode.inAppBrowserView: PlatformException(code: 'a'),
          LaunchMode.externalApplication: PlatformException(code: 'b'),
        }));

    expect(opened, isFalse,
        reason: 'the caller shows the raw link when this is false');
  });
}
