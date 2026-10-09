import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/app/startup_failure_app.dart';

void main() {
  testWidgets('says the notes could not be opened and offers a retry',
      (tester) async {
    var retried = 0;
    await tester.pumpWidget(StartupFailureApp(
      error: StateError('lock file busy'),
      retry: () async => retried++,
    ));

    expect(find.text("Your notes couldn't be opened"), findsOneWidget);
    expect(find.textContaining('lock file busy'), findsOneWidget);
    expect(find.textContaining('Nothing has been deleted'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(retried, 1);
    expect(find.text('Send my data'), findsOneWidget);
  });
}
