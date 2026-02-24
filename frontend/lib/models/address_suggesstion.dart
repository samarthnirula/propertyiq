class AddressSuggestion {
  final String formatted;
  final double lat;
  final double lon;

  AddressSuggestion({
    required this.formatted,
    required this.lat,
    required this.lon,
  });

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    return AddressSuggestion(
      formatted: json["formatted"] as String,
      lat: (json["lat"] as num).toDouble(),
      lon: (json["lon"] as num).toDouble(),
    );
  }
}
