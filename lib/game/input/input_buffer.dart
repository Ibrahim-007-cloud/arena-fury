import '../../core/constants.dart';
import '../../data/models/moveset.dart';

/// Ring buffer of recent inputs used to detect combo sequences such as
/// ↓ → SP or LP LP HK.
class InputBuffer {
  InputBuffer({this.capacity = 12});

  final int capacity;
  final List<({InputToken token, double time})> _entries = [];

  List<InputToken> get tokens => _entries.map((e) => e.token).toList();

  void add(InputToken token, double time) {
    _entries.add((token: token, time: time));
    if (_entries.length > capacity) _entries.removeAt(0);
  }

  void clear() => _entries.clear();

  /// True when the most recent input completes [sequence] within [window]
  /// seconds. Extra DIRECTION inputs in between are tolerated (joysticks are
  /// noisy) but an unrelated BUTTON press breaks the sequence.
  bool matches(
    List<InputToken> sequence,
    double now, {
    double window = GameConstants.comboInputWindow,
  }) {
    if (sequence.isEmpty || _entries.isEmpty) return false;
    if (_entries.last.token != sequence.last) return false;

    var seqIndex = sequence.length - 1;
    for (var i = _entries.length - 1; i >= 0; i--) {
      final e = _entries[i];
      if (now - e.time > window) return false;
      if (e.token == sequence[seqIndex]) {
        seqIndex--;
        if (seqIndex < 0) return true;
      } else if (e.token.isButton) {
        return false;
      }
    }
    return false;
  }
}
