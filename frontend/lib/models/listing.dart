class Listing {
  final String id;
  final String address;
  final String city;
  final String state;
  final String zip;
  final int? price;
  final double? beds;
  final double? baths;
  final int? sqft;
  final String? photo;

  Listing({
    required this.id,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    required this.price,
    required this.beds,
    required this.baths,
    required this.sqft,
    required this.photo,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: (json["id"] ?? "").toString(),
      address: (json["address"] ?? "").toString(),
      city: (json["city"] ?? "").toString(),
      state: (json["state"] ?? "").toString(),
      zip: (json["zip"] ?? "").toString(),
      price: json["price"] == null ? null : (json["price"] as num).toInt(),
      beds: json["beds"] == null ? null : (json["beds"] as num).toDouble(),
      baths: json["baths"] == null ? null : (json["baths"] as num).toDouble(),
      sqft: json["sqft"] == null ? null : (json["sqft"] as num).toInt(),
      photo: json["photo"]?.toString(),
    );
  }
}
