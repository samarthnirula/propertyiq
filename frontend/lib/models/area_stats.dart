class AreaStats {
  final String label;

  final int? medianHouseholdIncome;
  final double? populationChangePct;

  final int? ownerOccupiedUnits;
  final int? renterOccupiedUnits;
  final double? ownerSharePct;
  final double? renterSharePct;

  final int? averagePropertyPrice;
  final int? medianRentEstimate;

  final String? housingStatsSummary;
  final String? priceRentContext;

  final double? countyUnemploymentTrendPct;
  final String? metroLaborTrend;
  final String? macroSignal;

  final String? countyName;
  final double? countyCrimeRate;
  final double? latitude;
  final double? longitude;

  final int? forecastCurrentPrice;
  final int? forecastQ1Price;
  final int? forecastQ2Price;
  final int? forecastQ3Price;
  final int? forecastQ4Price;

  final double? forecastQ1GrowthPct;
  final double? forecastQ2GrowthPct;
  final double? forecastQ3GrowthPct;
  final double? forecastQ4GrowthPct;

  final String? forecastSummary;
  final String? forecastConfidence;

  final double? algorithmPrediction;
  final double? algorithmErrorPct;
  final int? algorithmKUsed;
  final List<dynamic>? algorithmNeighbors;

  // ✅ NEW FIELD (CRITICAL)
  final double? algorithmConfidenceScore;

  final String? notes;

  AreaStats({
    required this.label,
    this.medianHouseholdIncome,
    this.populationChangePct,
    this.ownerOccupiedUnits,
    this.renterOccupiedUnits,
    this.ownerSharePct,
    this.renterSharePct,
    this.averagePropertyPrice,
    this.medianRentEstimate,
    this.housingStatsSummary,
    this.priceRentContext,
    this.countyUnemploymentTrendPct,
    this.metroLaborTrend,
    this.macroSignal,
    this.countyName,
    this.countyCrimeRate,
    this.latitude,
    this.longitude,
    this.forecastCurrentPrice,
    this.forecastQ1Price,
    this.forecastQ2Price,
    this.forecastQ3Price,
    this.forecastQ4Price,
    this.forecastQ1GrowthPct,
    this.forecastQ2GrowthPct,
    this.forecastQ3GrowthPct,
    this.forecastQ4GrowthPct,
    this.forecastSummary,
    this.forecastConfidence,
    this.algorithmPrediction,
    this.algorithmErrorPct,
    this.algorithmKUsed,
    this.algorithmNeighbors,
    this.algorithmConfidenceScore, // ✅ added
    this.notes,
  });

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory AreaStats.fromJson(Map<String, dynamic> json) {
    return AreaStats(
      label: (json["label"] ?? "").toString(),

      medianHouseholdIncome: _asInt(json["median_household_income"]),
      populationChangePct: _asDouble(json["population_change_pct"]),

      ownerOccupiedUnits: _asInt(json["owner_occupied_units"]),
      renterOccupiedUnits: _asInt(json["renter_occupied_units"]),
      ownerSharePct: _asDouble(json["owner_share_pct"]),
      renterSharePct: _asDouble(json["renter_share_pct"]),

      averagePropertyPrice: _asInt(json["average_property_price"]),
      medianRentEstimate: _asInt(json["median_rent_estimate"]),

      housingStatsSummary: json["housing_stats_summary"]?.toString(),
      priceRentContext: json["price_rent_context"]?.toString(),

      countyUnemploymentTrendPct:
          _asDouble(json["county_unemployment_trend_pct"]),
      metroLaborTrend: json["metro_labor_trend"]?.toString(),
      macroSignal: json["macro_signal"]?.toString(),

      countyName: json["county_name"]?.toString(),
      countyCrimeRate: _asDouble(json["county_crime_rate"]),
      latitude: _asDouble(json["latitude"]),
      longitude: _asDouble(json["longitude"]),

      forecastCurrentPrice: _asInt(json["forecast_current_price"]),
      forecastQ1Price: _asInt(json["forecast_q1_price"]),
      forecastQ2Price: _asInt(json["forecast_q2_price"]),
      forecastQ3Price: _asInt(json["forecast_q3_price"]),
      forecastQ4Price: _asInt(json["forecast_q4_price"]),

      forecastQ1GrowthPct: _asDouble(json["forecast_q1_growth_pct"]),
      forecastQ2GrowthPct: _asDouble(json["forecast_q2_growth_pct"]),
      forecastQ3GrowthPct: _asDouble(json["forecast_q3_growth_pct"]),
      forecastQ4GrowthPct: _asDouble(json["forecast_q4_growth_pct"]),

      forecastSummary: json["forecast_summary"]?.toString(),
      forecastConfidence: json["forecast_confidence"]?.toString(),

      algorithmPrediction: _asDouble(json["algorithm_prediction"]),
      algorithmErrorPct: _asDouble(json["algorithm_error_pct"]),
      algorithmKUsed: _asInt(json["algorithm_k_used"]),
      algorithmNeighbors: json["algorithm_neighbors"] is List
          ? List<dynamic>.from(json["algorithm_neighbors"])
          : null,

      // ✅ NEW PARSE
      algorithmConfidenceScore:
          _asDouble(json["algorithm_confidence_score"]),

      notes: json["notes"]?.toString(),
    );
  }

  // Compatibility getters
  int? get medianSalary => medianHouseholdIncome;
  double? get economicGrowth => populationChangePct;

  @override
  String toString() {
    return 'AreaStats('
        'label: $label, '
        'medianHouseholdIncome: $medianHouseholdIncome, '
        'averagePropertyPrice: $averagePropertyPrice, '
        'medianRentEstimate: $medianRentEstimate, '
        'populationChangePct: $populationChangePct, '
        'forecastCurrentPrice: $forecastCurrentPrice, '
        'algorithmPrediction: $algorithmPrediction, '
        'algorithmErrorPct: $algorithmErrorPct, '
        'algorithmConfidenceScore: $algorithmConfidenceScore, '
        'algorithmKUsed: $algorithmKUsed, '
        'countyName: $countyName'
        ')';
  }
}