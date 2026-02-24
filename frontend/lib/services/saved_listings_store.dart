import '../models/listing.dart';

class SavedListingsStore {
  static final List<Listing> _saved = [];

  static List<Listing> get saved => List.unmodifiable(_saved);

  static bool isSaved(Listing l) => _saved.any((x) => x.id == l.id);

  static void toggle(Listing l) {
    final i = _saved.indexWhere((x) => x.id == l.id);
    if (i >= 0) {
      _saved.removeAt(i);
    } else {
      _saved.add(l);
    }
  }

  static void removeById(String id) {
    _saved.removeWhere((x) => x.id == id);
  }

  static void clear() => _saved.clear();
}
