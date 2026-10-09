import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/data/persistence/ref_counted_cache.dart';

void main() {
  test('disposes a value exactly once, when the last reference is released', () {
    final disposed = <int>[];
    final cache = RefCountedCache<int>(disposed.add);

    final v = cache.acquire('k', () => 42);
    expect(v, 42);
    expect(cache.refCount('k'), 1);

    // Second acquire reuses the cached value (creator must not run).
    cache.acquire('k', () => throw StateError('should not re-create'));
    expect(cache.refCount('k'), 2);

    cache.release('k');
    expect(cache.refCount('k'), 1);
    expect(disposed, isEmpty);

    cache.release('k');
    expect(cache.refCount('k'), 0);
    expect(cache.contains('k'), false);
    expect(disposed, [42]);
  });

  test('disposeAll evicts everything', () {
    final disposed = <int>[];
    final cache = RefCountedCache<int>(disposed.add);
    cache.acquire('a', () => 1);
    cache.acquire('b', () => 2);
    cache.disposeAll();
    expect(disposed.toSet(), {1, 2});
    expect(cache.contains('a'), false);
  });
}
