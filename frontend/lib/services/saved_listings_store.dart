import '../models/listing.dart';

class SavedListingsStore {
  static final List<Listing> saved = [];

  static void add(Listing listing) {
    final exists = saved.any((l) => l.id == listing.id);
    if (!exists) {
      saved.add(listing);
    }
  }

  static void removeById(String? id) {
    if (id == null) return;
    saved.removeWhere((l) => l.id == id);
  }

  static void clear() {
    saved.clear();
  }

  static bool isSaved(String? id) {
    if (id == null) return false;
    return saved.any((l) => l.id == id);
  }
}