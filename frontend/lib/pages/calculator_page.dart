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
  final bathroom = TextEditingController();
  final bedroom = TextEditingController();
  final area = TextEditingController();
  final zipcode = TextEditingController();
  final year = TextEditingController();
  final monthlyExpenses = TextEditingController();
  final oneTimeExpenses = TextEditingController();

  String message = "Enter details to analyze your investment";
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

    if (p == null ||
        d == null ||
        r == null ||
        ren == null ||
        mExp == null ||
        oExp == null) {
      return "Please enter valid numbers only.";
    }

    if (p <= 0) return "Price must be greater than 0.";
    if (d < 0 || r < 0 || ren < 0 || mExp < 0 || oExp < 0) {
      return "Values cannot be negative.";
    }
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
        message = "Calculated successfully.";
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

  PropertyStore.saved.add(
    PropertyItem(
      label: label,
      calc: result!,
    ),
  );

  if (!mounted) return;

  setState(() {
    message = "Saved as $label";
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("$label saved successfully")),
  );
}

  void clearAll() {
    price.clear();
    down.clear();
    rate.clear();
    rent.clear();
    bathroom.clear();
    bedroom.clear();
    area.clear();
    zipcode.clear();
    year.clear();
    monthlyExpenses.clear();
    oneTimeExpenses.clear();

    setState(() {
      result = null;
      message = "Enter details to analyze your investment";
    });
  }

  @override
  void dispose() {
    price.dispose();
    down.dispose();
    rate.dispose();
    rent.dispose();
    bathroom.dispose();
    bedroom.dispose();
    area.dispose();
    zipcode.dispose();
    year.dispose();
    monthlyExpenses.dispose();
    oneTimeExpenses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Property Details", Icons.home_work_outlined, theme),
          const SizedBox(height: 10),
          _buildFormContainer([
            _styledField("Purchase Price", price, Icons.attach_money, theme),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _styledField("Down Payment", down, Icons.money_off, theme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _styledField("Interest Rate", rate, Icons.percent, theme),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _styledField("Zipcode", zipcode, Icons.location_on, theme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _styledField("Year Built", year, Icons.build, theme),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _styledField("Bedrooms", bedroom, Icons.bed, theme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _styledField("Bathrooms", bathroom, Icons.bathtub, theme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _styledField("Area (sq ft)", area, Icons.square_foot, theme),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader(
            "Monthly & Upfront Costs",
            Icons.payments_outlined,
            theme,
          ),
          const SizedBox(height: 10),
          _buildFormContainer([
            _styledField("Expected Monthly Rent", rent, Icons.add_home_outlined, theme),
            const SizedBox(height: 16),
            _styledField(
              "Monthly Expenses",
              monthlyExpenses,
              Icons.receipt_long,
              theme,
            ),
            const SizedBox(height: 16),
            _styledField(
              "Upfront Costs",
              oneTimeExpenses,
              Icons.build_circle_outlined,
              theme,
            ),
          ]),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: loading ? null : calculate,
              child: loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Calculate Investment",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: loading ? null : clearAll,
              child: const Text("Clear All Fields"),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              message,
              style: TextStyle(
                color: message.contains("Error") ? Colors.red : Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          if (result != null) _buildResultDashboard(result!, theme),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFormContainer(List<Widget> children) {
    return Column(children: children);
  }

  Widget _styledField(
    String label,
    TextEditingController c,
    IconData icon,
    ThemeData theme,
  ) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
      ),
    );
  }

  Widget _buildResultDashboard(CalcResponse res, ThemeData theme) {
    final bool isPositive = res.cashFlow >= 0;
    final Color mainColor =
        isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withAlpha(26)),
          ),
          child: Column(
            children: [
              const Text(
                "Estimated Cash Flow",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
Text(
  "\$${res.cashFlow.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: mainColor,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
GridView.count(
  shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _summaryItem(
                    "ROI",
                    "${res.roi.toStringAsFixed(2)}%",
                    theme.primaryColor,
                    theme,
                  ),
                  _summaryItem(
                    "Cap Rate",
                    "${res.capRate.toStringAsFixed(2)}%",
                    Colors.purpleAccent,
                    theme,
                  ),
                  _summaryItem(
                    "Mortgage",
                    "\$${res.mortgagePayment.toStringAsFixed(0)}",
                    Colors.orangeAccent,
                    theme,
                  ),
                  _summaryItem(
                    "Breakeven",
                    res.breakevenYears == null
                        ? "N/A"
                        : "${res.breakevenYears!.toStringAsFixed(1)} yrs",
                    Colors.teal,
                    theme,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text("Save to Compare"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primaryColor,
                    side: BorderSide(color: theme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: saveToCompare,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryItem(String label, String value, Color accent, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withAlpha(26)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withAlpha(51),
                radius: 4,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}