class AreaStats {
  final String label;
  final int? medianSalary;
  final double? economicGrowth;
  final String? notes;

  AreaStats({
    required this.label,
    this.medianSalary,
    this.economicGrowth,
    this.notes,
  });

  factory AreaStats.fromJson(Map<String, dynamic> json) {
    return AreaStats(
      label: (json["label"] ?? "").toString(),
      medianSalary: (json["medianSalary"] as num?)?.toInt(),
      economicGrowth: (json["economicGrowth"] as num?)?.toDouble(),
      notes: json["notes"]?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "label": label,
      "medianSalary": medianSalary,
      "economicGrowth": economicGrowth,
      "notes": notes,
    };
  }
}
