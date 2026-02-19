import 'dart:async';

import 'package:flutter/material.dart';

import '../models/address_suggesstion.dart';
import '../models/area_stats.dart';
import '../services/api_service.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  // LEFT side state
  final TextEditingController _leftController = TextEditingController();
  Timer? _leftDebounce;
  List<AddressSuggestion> _leftSuggestions = [];
  bool _leftLoadingStats = false;
  String _leftStatus = "Search for a property address or ZIP";
  AreaStats? _leftStats;

  // RIGHT side state
  final TextEditingController _rightController = TextEditingController();
  Timer? _rightDebounce;
  List<AddressSuggestion> _rightSuggestions = [];
  bool _rightLoadingStats = false;
  String _rightStatus = "Search for a property address or ZIP";
  AreaStats? _rightStats;

  @override
  void dispose() {
    _leftDebounce?.cancel();
    _rightDebounce?.cancel();
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  // ----------------------------
  // Autocomplete handlers
  // ----------------------------

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
          _leftStatus = results.isEmpty
              ? "No suggestions found"
              : "Select an address (or press Enter to search)";
        });
      } catch (e) {
        setState(() {
          _leftSuggestions = [];
          _leftStatus = "Autocomplete error: $e";
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
          _rightStatus = results.isEmpty
              ? "No suggestions found"
              : "Select an address (or press Enter to search)";
        });
      } catch (e) {
        setState(() {
          _rightSuggestions = [];
          _rightStatus = "Autocomplete error: $e";
        });
      }
    });
  }

  // ----------------------------
  // Stats search (AreaStats)
  // ----------------------------

  Future<void> _runLeftStatsSearch({String? query}) async {
    final q = (query ?? _leftController.text).trim();

    setState(() {
      _leftSuggestions = [];
      _leftLoadingStats = true;
      _leftStats = null;
      _leftStatus = q.isEmpty ? "Enter an address or ZIP" : "Loading stats...";
    });

    if (q.isEmpty) {
      setState(() => _leftLoadingStats = false);
      return;
    }

    try {
      final stats = await ApiService.fetchAreaStats(q: q);
      setState(() {
        _leftStats = stats;
        _leftStatus = "Stats loaded";
      });
    } catch (e) {
      setState(() {
        _leftStatus = "Stats error: $e";
      });
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
      _rightStatus = q.isEmpty ? "Enter an address or ZIP" : "Loading stats...";
    });

    if (q.isEmpty) {
      setState(() => _rightLoadingStats = false);
      return;
    }

    try {
      final stats = await ApiService.fetchAreaStats(q: q);
      setState(() {
        _rightStats = stats;
        _rightStatus = "Stats loaded";
      });
    } catch (e) {
      setState(() {
        _rightStatus = "Stats error: $e";
      });
    } finally {
      setState(() => _rightLoadingStats = false);
    }
  }

  Future<void> _selectLeftSuggestion(AddressSuggestion s) async {
    setState(() {
      _leftController.text = (s.formatted ?? "");
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
      _leftStatus = "Search for a property address or ZIP";
    });
  }

  void _clearRight() {
    setState(() {
      _rightController.clear();
      _rightSuggestions = [];
      _rightStats = null;
      _rightStatus = "Search for a property address or ZIP";
    });
  }

  // ----------------------------
  // UI helpers
  // ----------------------------

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard(AreaStats? stats, {required String fallbackLabel}) {
    // Show only if there's something searched (stats might still be loading/null)
    if (fallbackLabel.trim().isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Stats",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _statRow("Area", stats?.label ?? fallbackLabel),
            _statRow(
              "Median Salary",
              stats?.medianSalary == null ? "—" : "\$${stats!.medianSalary}",
            ),
            _statRow(
              "Economic Growth",
              stats?.economicGrowth == null
                  ? "—"
                  : "${(stats!.economicGrowth! * 100).toStringAsFixed(1)}%",
            ),
            _statRow("Price History", "Coming soon"),
            _statRow("More Census Stats", "Coming soon"),
          ],
        ),
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
  }) {
    final q = controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sideTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: (_) => onSearch(),
                decoration: const InputDecoration(
                  labelText: "Search address / ZIP",
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: loading ? null : onSearch,
              child: const Text("Search"),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: loading ? null : onClear,
              child: const Text("Clear"),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Card(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final s = suggestions[index];
                  return ListTile(
                    title: Text((s.formatted ?? "").isEmpty ? "(Unknown address)" : s.formatted!),
                    onTap: () => onSelectSuggestion(s),
                  );
                },
              ),
            ),
          ),

        const SizedBox(height: 10),
        Text(status),

        const SizedBox(height: 12),

        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),

        // Stats appear only when something is searched/typed
        _statsCard(stats, fallbackLabel: q),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT 50%
          Expanded(
            child: _sidePanel(
              sideTitle: "Property A",
              controller: _leftController,
              onChanged: _onLeftChanged,
              onSearch: _runLeftStatsSearch,
              onClear: _clearLeft,
              loading: _leftLoadingStats,
              status: _leftStatus,
              suggestions: _leftSuggestions,
              onSelectSuggestion: _selectLeftSuggestion,
              stats: _leftStats,
            ),
          ),

          // CENTER "Compare"
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 44),
            child: Column(
              children: const [
                Text(
                  "Compare",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // RIGHT 50%
          Expanded(
            child: _sidePanel(
              sideTitle: "Property B",
              controller: _rightController,
              onChanged: _onRightChanged,
              onSearch: _runRightStatsSearch,
              onClear: _clearRight,
              loading: _rightLoadingStats,
              status: _rightStatus,
              suggestions: _rightSuggestions,
              onSelectSuggestion: _selectRightSuggestion,
              stats: _rightStats,
            ),
          ),
        ],
      ),
    );
  }
}
