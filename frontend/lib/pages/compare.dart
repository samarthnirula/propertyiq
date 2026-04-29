import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <--- Added this import
import '../models/address_suggesstion.dart';
import '../models/area_stats.dart';
import '../services/api_service.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  final TextEditingController _leftController = TextEditingController();
  Timer? _leftDebounce;
  List<AddressSuggestion> _leftSuggestions = [];
  bool _leftLoadingStats = false;
  String _leftStatus = "Search for a property address or ZIP";
  AreaStats? _leftStats;

  final TextEditingController _rightController = TextEditingController();
  Timer? _rightDebounce;
  List<AddressSuggestion> _rightSuggestions = [];
  bool _rightLoadingStats = false;
  String _rightStatus = "Search for a property address or ZIP";
  AreaStats? _rightStats;

  // Added currency formatter to handle the big numbers
  final NumberFormat _currency = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

  @override
  void dispose() {
    _leftDebounce?.cancel();
    _rightDebounce?.cancel();
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  String? _extractZip(String text) {
    final trimmed = text.trim();
    if (RegExp(r'^\d{5}$').hasMatch(trimmed)) return trimmed;
    final match = RegExp(r'\b\d{5}\b').firstMatch(trimmed);
    return match?.group(0);
  }

  void _onLeftChanged(String value) {
    _leftDebounce?.cancel();
    final v = value.trim();

    if (v.isEmpty) {
      setState(() {
        _leftSuggestions = [];
        _leftStatus = "Search for a property address or ZIP";
        _leftStats = null;
      });
      return;
    }

    if (v.length < 3) {
      setState(() => _leftSuggestions = []);
      return;
    }

    _leftDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ApiService.autocomplete(v);
        setState(() {
          _leftSuggestions = results;
          _leftStatus = results.isEmpty ? "No suggestions found" : "Select an address";
        });
      } catch (e) {
        setState(() {
          _leftSuggestions = [];
          _leftStatus = "Error: $e";
        });
      }
    });
  }

  void _onRightChanged(String value) {
    _rightDebounce?.cancel();
    final v = value.trim();

    if (v.isEmpty) {
      setState(() {
        _rightSuggestions = [];
        _rightStatus = "Search for a property address or ZIP";
        _rightStats = null;
      });
      return;
    }

    if (v.length < 3) {
      setState(() => _rightSuggestions = []);
      return;
    }

    _rightDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ApiService.autocomplete(v);
        setState(() {
          _rightSuggestions = results;
          _rightStatus = results.isEmpty ? "No suggestions found" : "Select an address";
        });
      } catch (e) {
        setState(() {
          _rightSuggestions = [];
          _rightStatus = "Error: $e";
        });
      }
    });
  }

  Future<void> _runLeftStatsSearch({String? query}) async {
    final q = (query ?? _leftController.text).trim();

    setState(() {
      _leftSuggestions = [];
      _leftLoadingStats = true;
      _leftStats = null;
      _leftStatus = q.isEmpty ? "Enter an address" : "Loading stats...";
    });

    if (q.isEmpty) {
      setState(() => _leftLoadingStats = false);
      return;
    }

    try {
      final zip = _extractZip(q);
      final stats = await ApiService.fetchAreaStats(
        areaInput: q,
        zipcode: zip,
      );
      setState(() {
        _leftStats = stats;
        _leftStatus = "Stats loaded";
      });
    } catch (e) {
      setState(() => _leftStatus = "Stats error: $e");
    } finally {
      setState(() => _leftLoadingStats = false);
    }
  }

  Future<void> _runRightStatsSearch({String? query}) async {
    final q = (query ?? _rightController.text).trim();

    setState(() {
      _rightSuggestions = [];
      _rightLoadingStats = true;
      _rightStats = null;
      _rightStatus = q.isEmpty ? "Enter an address" : "Loading stats...";
    });

    if (q.isEmpty) {
      setState(() => _rightLoadingStats = false);
      return;
    }

    try {
      final zip = _extractZip(q);
      final stats = await ApiService.fetchAreaStats(
        areaInput: q,
        zipcode: zip,
      );
      setState(() {
        _rightStats = stats;
        _rightStatus = "Stats loaded";
      });
    } catch (e) {
      setState(() => _rightStatus = "Stats error: $e");
    } finally {
      setState(() => _rightLoadingStats = false);
    }
  }

  Future<void> _selectLeftSuggestion(AddressSuggestion s) async {
    setState(() {
      _leftController.text = s.formatted;
      _leftSuggestions = [];
    });
    await _runLeftStatsSearch(query: s.formatted);
  }

  Future<void> _selectRightSuggestion(AddressSuggestion s) async {
    setState(() {
      _rightController.text = s.formatted;
      _rightSuggestions = [];
    });
    await _runRightStatsSearch(query: s.formatted);
  }

  void _clearLeft() {
    setState(() {
      _leftController.clear();
      _leftSuggestions = [];
      _leftStats = null;
      _leftStatus = "Search for a property address";
    });
  }

  void _clearRight() {
    setState(() {
      _rightController.clear();
      _rightSuggestions = [];
      _rightStats = null;
      _rightStatus = "Search for a property address";
    });
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.5,
              color: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : theme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard(
    AreaStats? stats, {
    required String fallbackLabel,
    required ThemeData theme,
  }) {
    if (fallbackLabel.trim().isEmpty) return const SizedBox.shrink();

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  "Snapshot",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stats?.label ?? fallbackLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),

          // Market Basics Section
          _buildSectionHeader("MARKET BASICS", Icons.home_work_outlined, theme),
          _statRow(
            "Average Property Price",
            stats?.averagePropertyPrice == null ? "—" : _currency.format(stats!.averagePropertyPrice),
            Icons.sell_outlined,
            theme,
          ),
          _statRow(
            "Median Rent",
            stats?.medianRentEstimate == null ? "—" : _currency.format(stats!.medianRentEstimate),
            Icons.real_estate_agent_outlined,
            theme,
          ),

          // Economy Section
          _buildSectionHeader("ECONOMY", Icons.trending_up_outlined, theme),
          _statRow(
            "Median Salary",
            stats?.medianSalary == null ? "—" : _currency.format(stats!.medianSalary),
            Icons.payments_outlined,
            theme,
          ),
          _statRow(
            "Economic Growth",
            stats?.economicGrowth == null ? "—" : "${stats!.economicGrowth!.toStringAsFixed(1)}%",
            Icons.show_chart_outlined,
            theme,
          ),

          // AI Analytics Section
          _buildSectionHeader("AI PROJECTIONS", Icons.auto_awesome_outlined, theme),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _statRow(
                  "Predicted Value",
                  stats?.algorithmPrediction == null ? "—" : _currency.format(stats!.algorithmPrediction!.round()),
                  Icons.online_prediction_outlined,
                  theme,
                ),
                _statRow(
                  "Model Confidence",
                  stats?.algorithmConfidenceScore == null ? "—" : "${(stats!.algorithmConfidenceScore! * 100).toStringAsFixed(0)}%",
                  Icons.verified_outlined,
                  theme,
                ),
                _statRow(
                  "Margin of Error",
                  stats?.algorithmErrorPct == null ? "—" : "±${stats!.algorithmErrorPct!.toStringAsFixed(1)}%",
                  Icons.analytics_outlined,
                  theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidePanel({
    required String sideTitle,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required VoidCallback onSearch,
    required VoidCallback onClear,
    required bool loading,
    required String status,
    required List<AddressSuggestion> suggestions,
    required Future<void> Function(AddressSuggestion) onSelectSuggestion,
    required AreaStats? stats,
    required ThemeData theme,
  }) {
    final q = controller.text.trim();
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sideTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: (_) => onSearch(),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: "Search address / ZIP",
                  hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC),
                  prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: loading ? null : onSearch,
              child: const Text("Search", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: loading ? null : onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textTheme.bodyLarge?.color,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: const Text("Clear"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              color: isDark ? theme.scaffoldBackgroundColor : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final s = suggestions[index];
                  return ListTile(
                    leading: Icon(Icons.location_on_outlined, color: theme.primaryColor),
                    title: Text(
                      s.formatted.isEmpty ? "(Unknown)" : s.formatted,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    ),
                    onTap: () => onSelectSuggestion(s),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? theme.primaryColor.withValues(alpha: 0.15) : theme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: isDark ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            ),
          ),
        if (!loading) _statsCard(stats, fallbackLabel: q, theme: theme),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _sidePanel(
                sideTitle: "Property Market A",
                controller: _leftController,
                onChanged: _onLeftChanged,
                onSearch: _runLeftStatsSearch,
                onClear: _clearLeft,
                loading: _leftLoadingStats,
                status: _leftStatus,
                suggestions: _leftSuggestions,
                onSelectSuggestion: _selectLeftSuggestion,
                stats: _leftStats,
                theme: theme,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: theme.primaryColor,
                  size: 28,
                ),
              ),
            ),
            Expanded(
              child: _sidePanel(
                sideTitle: "Property Market B",
                controller: _rightController,
                onChanged: _onRightChanged,
                onSearch: _runRightStatsSearch,
                onClear: _clearRight,
                loading: _rightLoadingStats,
                status: _rightStatus,
                suggestions: _rightSuggestions,
                onSelectSuggestion: _selectRightSuggestion,
                stats: _rightStats,
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}