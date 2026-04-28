class AddressSuggestion {
  final String formatted;
  final double? lat;
  final double? lon;

  const AddressSuggestion({
    required this.formatted,
    this.lat,
    this.lon,
  });

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    return AddressSuggestion(
      formatted: (json['formatted'] ?? '').toString(),
      lat: _asDouble(json['lat']),
      lon: _asDouble(json['lon']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formatted': formatted,
      'lat': lat,
      'lon': lon,
    };
  }

  @override
  String toString() {
    return 'AddressSuggestion(formatted: $formatted, lat: $lat, lon: $lon)';
  }
}