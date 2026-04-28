import 'calc_models.dart';

class PropertyItem {
  final String id;
  final String label;
  final CalcResponse calc;

  PropertyItem({
    required this.label,
    required this.calc,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  String toString() {
    return 'PropertyItem(id: $id, label: $label, calc: $calc)';
  }
}