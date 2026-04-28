import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/area_stats.dart';

class AreaStatsPanel extends StatefulWidget {
  final AreaStats? stats;
  final bool loading;
  final String? error;

  const AreaStatsPanel({
    super.key,
    required this.stats,
    required this.loading,
    required this.error,
  });

  @override
  State<AreaStatsPanel> createState() => _AreaStatsPanelState();
}

class _AreaStatsPanelState extends State<AreaStatsPanel> {
  bool _expanded = false;

  AreaStats? get stats => widget.stats;

  String _money(num? v) {
    if (v == null) return "—";
    final f = NumberFormat.currency(locale: "en_US", symbol: "\$", decimalDigits: 0);
    return f.format(v);
  }

  String _pct(double? v) {
    if (v == null) return "—";
    return "${v.toStringAsFixed(1)}%";
  }

  String _modelQuality(double? errorPct) {
    if (errorPct == null) return "Unknown";
    if (errorPct <= 5) return "Excellent";
    if (errorPct <= 10) return "Good";
    if (errorPct <= 15) return "Moderate";
    return "Weak";
  }

  String _modelMessage(double? errorPct) {
    final score = stats?.algorithmConfidenceScore;
    if (score != null) {
      if (score >= 0.85) return "This estimate is based on tightly matched comparable ZIP markets and strong cluster alignment.";
      if (score >= 0.70) return "This estimate is supported by several reasonably strong comparable ZIP markets.";
      if (score >= 0.50) return "This estimate is usable for screening, but the comparable ZIP cluster is only moderately aligned.";
      return "This estimate should be treated cautiously. Comparable ZIP alignment is weak.";
    }
    if (errorPct == null) return "Model reliability could not be estimated for this ZIP.";
    if (errorPct <= 5) return "This estimate is highly reliable based on the model's historical ZIP-level performance.";
    if (errorPct <= 10) return "This estimate is strong and should be useful for market screening.";
    if (errorPct <= 15) return "This estimate is reasonable for screening, but should be paired with local comparables.";
    return "This estimate should be treated as directional only. This ZIP is harder for the model.";
  }

  Color _qualityColor(double? errorPct) {
    if (errorPct == null) return Colors.black54;
    if (errorPct <= 5) return Colors.green;
    if (errorPct <= 10) return Colors.teal;
    if (errorPct <= 15) return Colors.orange;
    return Colors.red;
  }

  IconData _qualityIcon(double? errorPct) {
    if (errorPct == null) return Icons.help_outline;
    if (errorPct <= 5) return Icons.verified;
    if (errorPct <= 10) return Icons.thumb_up_alt_outlined;
    if (errorPct <= 15) return Icons.analytics_outlined;
    return Icons.warning_amber_rounded;
  }

  String _wealthCategory() {
    final price = stats?.algorithmPrediction ?? stats?.averagePropertyPrice?.toDouble();
    if (price == null) return "Unknown";
    if (price >= 1500000) return "Ultra Wealthy";
    if (price >= 800000) return "Wealthy";
    if (price >= 400000) return "Upper Middle";
    if (price >= 200000) return "Middle";
    return "Affordable";
  }

  Color _wealthColor() {
    switch (_wealthCategory()) {
      case "Ultra Wealthy": return Colors.purple;
      case "Wealthy": return Colors.indigo;
      case "Upper Middle": return Colors.blue;
      case "Middle": return Colors.teal;
      case "Affordable": return Colors.green;
      default: return Colors.grey;
    }
  }

  String _confidenceLabel() {
    final score = stats?.algorithmConfidenceScore;
    if (score == null) return "Unknown";
    if (score >= 0.85) return "High Confidence";
    if (score >= 0.70) return "Strong";
    if (score >= 0.50) return "Moderate";
    return "Low Confidence";
  }

  String _confidencePercent() {
    final score = stats?.algorithmConfidenceScore;
    if (score == null) return "—";
    return "${(score * 100).clamp(0, 100).toStringAsFixed(0)}%";
  }

  String _predictionExplanation() {
    final neighbors = stats?.algorithmNeighbors?.length ?? 0;
    final label = (stats?.label ?? "").trim().isEmpty ? "this area" : stats!.label;
    final confidence = _confidencePercent();
    return "Based on $neighbors comparable ZIP markets using pricing similarity, market tier, regional behavior, and recent housing patterns around $label. Confidence: $confidence.";
  }

  double? _mlBaseValue() {
    if (stats?.algorithmPrediction != null) return stats!.algorithmPrediction!;
    if (stats?.averagePropertyPrice != null) return stats!.averagePropertyPrice!.toDouble();
    if (stats?.forecastCurrentPrice != null) return stats!.forecastCurrentPrice!.toDouble();
    return null;
  }

  int? _combinedProjectedPrice({required int? quarterForecastPrice, required double mlWeight, required double forecastWeight}) {
    final mlBase = _mlBaseValue();
    if (mlBase == null && quarterForecastPrice == null) return null;
    if (mlBase == null) return quarterForecastPrice;
    if (quarterForecastPrice == null) return mlBase.round();
    return ((mlBase * mlWeight) + (quarterForecastPrice * forecastWeight)).round();
  }

  double? _combinedGrowthPct(int? quarterCombinedPrice) {
    final mlBase = _mlBaseValue();
    if (mlBase == null || mlBase == 0 || quarterCombinedPrice == null) return null;
    return ((quarterCombinedPrice - mlBase) / mlBase) * 100.0;
  }

  Widget _badge(String text, {Color? bg, Color? fg, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg ?? Colors.black.withAlpha(15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (fg ?? Colors.black54).withAlpha(46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg ?? Colors.black87),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: fg ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _forecastCard(String label, int? price, double? growth) {
    return Container(
      width: 125,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_money(price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            growth == null ? "—" : _pct(growth),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: growth == null ? Colors.black54 : (growth >= 0 ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStatCard({required String label, required String value, IconData? icon, Color? iconColor}) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: iconColor ?? Colors.black87), const SizedBox(height: 10)],
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  // ── ALWAYS VISIBLE ──────────────────────────────────────────────────

  Widget _compactPrediction() {
    final qualityColor = _qualityColor(stats?.algorithmErrorPct);
    final qualityLabel = _modelQuality(stats?.algorithmErrorPct);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: qualityColor.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: qualityColor.withAlpha(56)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(_wealthCategory(), bg: _wealthColor().withAlpha(25), fg: _wealthColor(), icon: Icons.attach_money),
              _badge("${_confidenceLabel()} • ${_confidencePercent()}", icon: Icons.psychology_outlined),
              _badge(qualityLabel, bg: qualityColor.withAlpha(25), fg: qualityColor, icon: _qualityIcon(stats?.algorithmErrorPct)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _money(stats?.algorithmPrediction),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, height: 1),
          ),
          const SizedBox(height: 6),
          Text("AI Estimated Market Value", style: TextStyle(fontSize: 13, color: qualityColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _forecastStrip() {
    final hasAnyForecast =
        stats?.forecastCurrentPrice != null ||
        stats?.forecastQ1Price != null ||
        stats?.forecastQ2Price != null ||
        stats?.forecastQ3Price != null ||
        stats?.forecastQ4Price != null;

    if (!hasAnyForecast) return const SizedBox.shrink();

    final base = _mlBaseValue();
    final combinedQ1 = _combinedProjectedPrice(quarterForecastPrice: stats?.forecastQ1Price, mlWeight: 0.65, forecastWeight: 0.35);
    final combinedQ2 = _combinedProjectedPrice(quarterForecastPrice: stats?.forecastQ2Price, mlWeight: 0.55, forecastWeight: 0.45);
    final combinedQ3 = _combinedProjectedPrice(quarterForecastPrice: stats?.forecastQ3Price, mlWeight: 0.45, forecastWeight: 0.55);
    final combinedQ4 = _combinedProjectedPrice(quarterForecastPrice: stats?.forecastQ4Price, mlWeight: 0.35, forecastWeight: 0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text("1-Year Forecast", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _forecastCard("Now", base?.round(), null),
              const SizedBox(width: 10),
              _forecastCard("Q1", combinedQ1, _combinedGrowthPct(combinedQ1)),
              const SizedBox(width: 10),
              _forecastCard("Q2", combinedQ2, _combinedGrowthPct(combinedQ2)),
              const SizedBox(width: 10),
              _forecastCard("Q3", combinedQ3, _combinedGrowthPct(combinedQ3)),
              const SizedBox(width: 10),
              _forecastCard("Q4", combinedQ4, _combinedGrowthPct(combinedQ4)),
            ],
          ),
        ),
      ],
    );
  }

  // ── EXPANDED (behind Show More) ─────────────────────────────────────

  Widget _expandedContent() {
    final neighbors = stats?.algorithmNeighbors ?? const [];
    final qualityColor = _qualityColor(stats?.algorithmErrorPct);
    final qualityLabel = _modelQuality(stats?.algorithmErrorPct);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 18),

        // Model explanation
        Text(
          _predictionExplanation(),
          style: const TextStyle(height: 1.4, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          _modelMessage(stats?.algorithmErrorPct),
          style: const TextStyle(height: 1.4, color: Colors.black54),
        ),

        // Model mini stats
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _miniStatCard(label: "Prediction Error", value: _pct(stats?.algorithmErrorPct), icon: Icons.speed_outlined, iconColor: qualityColor),
              const SizedBox(width: 10),
              _miniStatCard(label: "Model Quality", value: qualityLabel, icon: _qualityIcon(stats?.algorithmErrorPct), iconColor: qualityColor),
              const SizedBox(width: 10),
              _miniStatCard(label: "Neighbors Used", value: stats?.algorithmKUsed?.toString() ?? "—", icon: Icons.account_tree_outlined),
              const SizedBox(width: 10),
              _miniStatCard(label: "Confidence Score", value: _confidencePercent(), icon: Icons.psychology_outlined, iconColor: Colors.indigo),
            ],
          ),
        ),

        // Comparable ZIPs
        if (neighbors.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text("Top Comparable ZIPs", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ...neighbors.take(5).map((n) {
            final zip = (n['zip_code'] ?? '—').toString();
            final county = (n['county'] ?? '').toString();
            final tier = (n['market_tier'] ?? '').toString();
            final region = (n['region_bucket'] ?? '').toString();
            final urbanCore = (n['urban_core_flag'] ?? '').toString();

            final rawSim = n['similarity_score'];
            double? simDouble;
            if (rawSim is num) {
              simDouble = rawSim.toDouble();
            } else {
              simDouble = double.tryParse(rawSim?.toString() ?? '');
            }

            final value = n['property_value'];
            int? valueInt;
            if (value is num) {
              valueInt = value.toInt();
            } else {
              valueInt = int.tryParse(value?.toString() ?? '');
            }

            Color simColor = Colors.green;
            if (simDouble != null) {
              if (simDouble >= 70) {
                simColor = Colors.green;
              } else if (simDouble >= 40) {
                simColor = Colors.orange;
              } else {
                simColor = Colors.red;
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text("ZIP $zip", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                        Text(_money(valueInt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (county.isNotEmpty) _badge(county.toUpperCase(), icon: Icons.map_outlined),
                        if (tier.isNotEmpty) _badge(tier, icon: Icons.bar_chart_outlined),
                        if (region.isNotEmpty) _badge(region, icon: Icons.public_outlined),
                        _badge(
                          urbanCore == "1" ? "Urban Core" : "Non-Urban Core",
                          icon: urbanCore == "1" ? Icons.apartment_outlined : Icons.home_work_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (simDouble ?? 0) / 100,
                              backgroundColor: Colors.black12,
                              color: simColor,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          simDouble == null ? "—" : "${simDouble.toStringAsFixed(0)}% similar",
                          style: TextStyle(color: simColor, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        // Area snapshot rows
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),
        const Text("Area Snapshot", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        _row("Area", stats?.label.isNotEmpty == true ? stats!.label : "—"),
        _row("County", stats?.countyName ?? "—"),
        _row("Median household income", _money(stats?.medianHouseholdIncome)),
        _row("Population change", _pct(stats?.populationChangePct)),
        _row("Owner share", _pct(stats?.ownerSharePct)),
        _row("Renter share", _pct(stats?.renterSharePct)),
        _row("Average property price", _money(stats?.averagePropertyPrice)),
        _row("Median rent estimate", _money(stats?.medianRentEstimate)),
        _row("County unemployment trend", _pct(stats?.countyUnemploymentTrendPct)),
        _row("Metro labor trend", stats?.metroLaborTrend ?? "—"),
        _row("Macro signal", stats?.macroSignal ?? "—"),

        // Forecast summary
        if ((stats?.forecastSummary ?? "").trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text("Forecast Summary", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(stats!.forecastSummary!, style: const TextStyle(height: 1.4, color: Colors.black87)),
        ],

        // Housing stats + context
        if ((stats?.housingStatsSummary ?? "").trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text("Housing Stats", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(stats!.housingStatsSummary!, style: const TextStyle(height: 1.4)),
        ],
        if ((stats?.priceRentContext ?? "").trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text("Price / Rent Context", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(stats!.priceRentContext!, style: const TextStyle(height: 1.4)),
        ],
        if ((stats?.notes ?? "").trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(stats!.notes!, style: const TextStyle(color: Colors.black54, height: 1.35)),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = !widget.loading && widget.error == null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + toggle button always visible at top
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Area Snapshot",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                if (hasContent)
                  TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(
                      _expanded ? "Less" : "More Details",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.loading) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else if (widget.error != null) ...[
              Text(widget.error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ] else ...[
              _compactPrediction(),
              _forecastStrip(),
              if (_expanded) _expandedContent(),
            ],
          ],
        ),
      ),
    );
  }
}
