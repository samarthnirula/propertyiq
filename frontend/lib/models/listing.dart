class Listing {
  final String id;
  final String address;
  final String city;
  final String state;
  final String zip;

  final double? price;
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
    this.price,
    this.beds,
    this.baths,
    this.sqft,
    this.photo,
  });

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: (json['id'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zip: (json['zip'] ?? '').toString(),

      price: _asDouble(json['price']),
      beds: _asDouble(json['beds']),
      baths: _asDouble(json['baths']),
      sqft: _asInt(json['sqft']),

      photo: json['photo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'city': city,
      'state': state,
      'zip': zip,
      'price': price,
      'beds': beds,
      'baths': baths,
      'sqft': sqft,
      'photo': photo,
    };
  }

  @override
  String toString() {
    return 'Listing('
        'id: $id, '
        'address: $address, '
        'city: $city, '
        'state: $state, '
        'zip: $zip, '
        'price: $price, '
        'beds: $beds, '
        'baths: $baths, '
        'sqft: $sqft'
        ')';
  }
}