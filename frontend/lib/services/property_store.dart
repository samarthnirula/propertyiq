import '../models/property_item.dart';

class PropertyStore {
  static final List<PropertyItem> saved = [];

  static List<PropertyItem> get savedItems => List.unmodifiable(saved);

  static void add(PropertyItem item) {
    saved.add(item);
  }

  static void removeAt(int index) {
    if (index >= 0 && index < saved.length) {
      saved.removeAt(index);
    }
  }

  static void clear() {
    saved.clear();
  }
}