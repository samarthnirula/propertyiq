import 'package:flutter/material.dart';
import '../services/property_store.dart';
import '../models/property_item.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  PropertyItem? a;
  PropertyItem? b;

  void select(PropertyItem item) {
    setState(() {
      if (a == null || (a != null && b != null)) {
        a = item;
        b = null;
      } else {
        // second pick
        if (a!.label == item.label) return;
        b = item;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final saved = PropertyStore.saved;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "Compare Properties",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Tap to select two properties. First tap selects Property A, second tap selects Property B.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          if (saved.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No saved properties yet.\nGo to Calculate and press 'Save to Compare'.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: saved.length,
                itemBuilder: (context, i) {
                  final item = saved[i];
                  final selected = (a?.label == item.label) || (b?.label == item.label);

                  return Card(
                    child: ListTile(
                      title: Text(item.label),
                      subtitle: Text(
                        "Breakeven: ${item.calc.breakevenYears == null ? "N/A" : "${item.calc.breakevenYears!.toStringAsFixed(2)} yrs"}"
                        " | Cash Flow: \$${item.calc.cashFlow.toStringAsFixed(2)}/mo",
                      ),
                      trailing: selected ? const Icon(Icons.check_circle) : null,
                      onTap: () => select(item),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 10),

          if (a != null)
            Text("A: ${a!.label}", style: const TextStyle(fontSize: 16)),
          if (b != null)
            Text("B: ${b!.label}", style: const TextStyle(fontSize: 16)),

          const SizedBox(height: 10),

          if (a != null && b != null)
            Expanded(
              flex: 0,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        "Side-by-Side",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _row("Metric", "A", "B"),
                      const Divider(),
                      _row("Cash Flow (mo)", "\$${a!.calc.cashFlow.toStringAsFixed(2)}",
                          "\$${b!.calc.cashFlow.toStringAsFixed(2)}"),
                      _row("Cap Rate", "${a!.calc.capRate.toStringAsFixed(2)}%",
                          "${b!.calc.capRate.toStringAsFixed(2)}%"),
                      _row("ROI", "${a!.calc.roi.toStringAsFixed(2)}%",
                          "${b!.calc.roi.toStringAsFixed(2)}%"),
                      _row(
                        "Breakeven",
                        a!.calc.breakevenYears == null
                            ? "N/A"
                            : "${a!.calc.breakevenYears!.toStringAsFixed(2)} yrs",
                        b!.calc.breakevenYears == null
                            ? "N/A"
                            : "${b!.calc.breakevenYears!.toStringAsFixed(2)} yrs",
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String left, String mid, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(width: 140, child: Text(left, style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 90, child: Text(mid, textAlign: TextAlign.center)),
          SizedBox(width: 90, child: Text(right, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
