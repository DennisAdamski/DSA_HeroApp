/// Debug-only rebuild metrics for widget tests.
///
/// Counters are only increased in `assert` mode, so runtime behavior in release
/// builds stays unchanged.
class UiRebuildObserver {
  UiRebuildObserver._();

  static final Map<String, int> _counters = <String, int>{};

  static bool enabled = false;

  static void reset([String? key]) {
    if (key == null) {
      _counters.clear();
      return;
    }
    _counters.remove(key);
  }

  static int count(String key) => _counters[key] ?? 0;

  static void bump(String key) {
    assert(() {
      if (!enabled) {
        return true;
      }
      _counters[key] = (_counters[key] ?? 0) + 1;
      return true;
    }());
  }
}
