import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/home/presentation/saved_searches.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('newest first, no repeats ignoring case, at most eight, kept', () async {
    final recent = RecentSearchesNotifier();
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 10; i++) {
      await recent.add('q$i');
    }
    await recent.add('  Q3 ');
    expect(recent.state.first, 'Q3');
    expect(recent.state.where((q) => q.toLowerCase() == 'q3').length, 1);
    expect(recent.state.length, RecentSearchesNotifier.max);
    await recent.add('   ');
    expect(recent.state.first, 'Q3');

    final reloaded = RecentSearchesNotifier();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(reloaded.state, recent.state);

    await recent.clear();
    expect(recent.state, isEmpty);
  });
}
