import 'package:flutter/material.dart';
import '../models/calc_models.dart';
import '../services/api_service.dart';
import '../services/property_store.dart';
import '../models/property_item.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final price = TextEditingController();
  final down = TextEditingController();
  final rate = TextEditingController();
  final rent = TextEditingController();
  final monthlyExpenses = TextEditingController();
  final oneTimeExpenses = TextEditingController();

  String message = "Enter values and press Calculate";
  CalcResponse? result;
  bool loading = false;

  String? _validateInputs() {
    if (price.text.isEmpty ||
        down.text.isEmpty ||
        rate.text.isEmpty ||
        rent.text.isEmpty ||
        monthlyExpenses.text.isEmpty ||
        oneTimeExpenses.text.isEmpty) {
      return "Please fill in all fields.";
    }

    final p = double.tryParse(price.text);
    final d = double.tryParse(down.text);
    final r = double.tryParse(rate.text);
    final ren = double.tryParse(rent.text);
    final mExp = double.tryParse(monthlyExpenses.text);
    final oExp = double.tryParse(oneTimeExpenses.text);

    if (p == null || d == null || r == null || ren == null || mExp == null || oExp == null) {
      return "Please enter valid numbers only.";
    }
    if (p <= 0) return "Price must be greater than 0.";
    if (d < 0 || r < 0 || ren < 0 || mExp < 0 || oExp < 0) return "Values cannot be negative.";
    if (d > p) return "Down payment cannot be greater than price.";
    return null;
  }

  Future<void> calculate() async {
    final error = _validateInputs();
    if (error != null) {
      setState(() => message = error);
      return;
    }

    setState(() {
      loading = true;
      message = "Calculating...";
      result = null;
    });

    try {
      final req = CalcRequest(
        price: double.parse(price.text),
        downPayment: double.parse(down.text),
        interestRate: double.parse(rate.text),
        rent: double.parse(rent.text),
        monthlyExpenses: double.parse(monthlyExpenses.text),
        oneTimeExpenses: double.parse(oneTimeExpenses.text),
      );

      final res = await ApiService.calculate(req);

      setState(() {
        result = res;
        message = "Calculated successfully. Tap 'Save to Compare' to store.";
      });
    } catch (e) {
      setState(() => message = "Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  void saveToCompare() {
    if (result == null) return;

    final label = "Property ${PropertyStore.saved.length + 1}";
    PropertyStore.saved.add(PropertyItem(label: label, calc: result!));

    setState(() {
      message = "Saved as $label. Go to Compare tab to select 2 properties.";
    });
  }

  void clearAll() {
    price.clear();
    down.clear();
    rate.clear();
    rent.clear();
    monthlyExpenses.clear();
    oneTimeExpenses.clear();

    setState(() {
      result = null;
      message = "Enter values and press Calculate";
    });
  }

  Widget field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget resultRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = result;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          field("Price", price),
          field("Down Payment", down),
          field("Interest Rate (%)", rate),
          field("Monthly Rent", rent),
          field("Monthly Expenses (Tax/Insurance/Repairs)", monthlyExpenses),
          field("One-time Upfront Cost (Closing/Repairs)", oneTimeExpenses),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: loading ? null : calculate,
                child: Text(loading ? "Working..." : "Calculate"),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: loading ? null : clearAll,
                child: const Text("Clear"),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),

          if (res != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    resultRow("Mortgage", "\$${res.mortgagePayment.toStringAsFixed(2)}"),
                    resultRow(
                      "Cash Flow",
                      "\$${res.cashFlow.toStringAsFixed(2)}/mo",
                      valueColor: res.cashFlow >= 0 ? Colors.greenAccent : Colors.redAccent,
                    ),
                    resultRow("Cap Rate", "${res.capRate.toStringAsFixed(2)}%"),
                    resultRow("ROI", "${res.roi.toStringAsFixed(2)}%"),
                    resultRow(
                      "Breakeven",
                      res.breakevenYears == null
                          ? "N/A"
                          : "${res.breakevenYears!.toStringAsFixed(2)} years",
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: saveToCompare,
                      child: const Text("Save to Compare"),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
