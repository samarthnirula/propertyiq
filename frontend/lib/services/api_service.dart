import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/calc_models.dart';
import '../models/address_suggesstion.dart';
import '../models/listing.dart';
import '../models/area_stats.dart';

class ApiService {
  static const String baseUrl = "http://localhost:8000";

  static Future<CalcResponse> calculate(CalcRequest request) async {
    final url = Uri.parse("$baseUrl/calculate");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(request.toJson()),
    );

    if (res.statusCode != 200) {
      throw Exception("Backend error ${res.statusCode}: ${res.body}");
    }

    return CalcResponse.fromJson(jsonDecode(res.body));
  }

  static Future<List<AddressSuggestion>> autocomplete(String query) async {
    if (query.trim().length < 3) return [];

    final url = Uri.parse(
      "$baseUrl/autocomplete?q=${Uri.encodeComponent(query.trim())}",
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception("Autocomplete failed: ${res.statusCode} ${res.body}");
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    final List results = (data["results"] ?? []) as List;

    return results
        .map((e) => AddressSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Listing>> searchListings({
    String? query,
    String? city,
    int limit = 12,
  }) async {
    final params = <String, String>{
      "limit": limit.toString(),
    };

    if (query != null && query.trim().isNotEmpty) {
      params["q"] = query.trim();
    }

    if (city != null && city.trim().isNotEmpty) {
      params["city"] = city.trim();
    }

    final url = Uri.parse("$baseUrl/listings").replace(queryParameters: params);

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception("Listings failed: ${res.statusCode} ${res.body}");
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final List results = (data["results"] ?? []) as List;

    return results
        .map((e) => Listing.fromJson(e as Map<String, dynamic>))
        .toList();
  }


  static Future<AreaStats> fetchAreaStats({required String q}) async {
    final query = q.trim();
    if (query.isEmpty) {
      throw Exception("fetchAreaStats: empty query");
    }

    final url = Uri.parse("$baseUrl/area-stats")
        .replace(queryParameters: {"q": query});

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception("Area stats failed: ${res.statusCode} ${res.body}");
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AreaStats.fromJson(data);
  }
}
