import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/calc_models.dart';
import '../models/address_suggesstion.dart';
import '../models/listing.dart';
import '../models/area_stats.dart';

class ApiService {
static String get baseUrl {
  return "http://localhost:8000";
}
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

    final decoded = jsonDecode(res.body);

    if (decoded is List) {
      return decoded
          .map((e) => AddressSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final List results = (decoded["results"] ?? []) as List;
      return results
          .map((e) => AddressSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  static Future<List<Listing>> searchListings({
    String? query,
    String? city,
    int limit = 12,
    int offset = 0,
  }) async {
    final params = <String, String>{
      "limit": limit.toString(),
      "offset": offset.toString(),
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

    final decoded = jsonDecode(res.body);

    if (decoded is List) {
      return decoded
          .map((e) => Listing.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final List results = (decoded["results"] ?? []) as List;
      return results
          .map((e) => Listing.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  static Future<AreaStats> fetchAreaStats({
    required String areaInput,
    String? zipcode,
  }) async {
    final query = areaInput.trim();
    if (query.isEmpty) {
      throw Exception("fetchAreaStats: empty query");
    }

    final params = <String, String>{
      "area_input": query,
    };

    if (zipcode != null && zipcode.trim().isNotEmpty) {
      params["zipcode"] = zipcode.trim();
    }

    final url = Uri.parse("$baseUrl/area-stats").replace(
      queryParameters: params,
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception("Area stats failed: ${res.statusCode} ${res.body}");
    }

    return AreaStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // Older pages still call this.
  static Future<AreaStats> getStats({required String zip}) async {
    return fetchAreaStats(
      areaInput: zip,
      zipcode: zip,
    );
  }

  static Future<Map<String, dynamic>> fetchAreaReport(String areaInput) async {
    final url = Uri.parse("$baseUrl/area-report").replace(
      queryParameters: {"area_input": areaInput},
    );
    final res = await http
        .get(url)
        .timeout(const Duration(minutes: 3));

    if (res.statusCode != 200) {
      throw Exception("Area report failed: ${res.statusCode} ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchDeepAreaReport(
    String areaInput,
  ) async {
    final url = Uri.parse("$baseUrl/area-report/deep").replace(
      queryParameters: {"area_input": areaInput},
    );
    final res = await http
        .get(url)
        .timeout(const Duration(minutes: 5));

    if (res.statusCode != 200) {
      throw Exception("Deep report failed: ${res.statusCode} ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> fetchHousingNews() async {
    final url = Uri.parse("$baseUrl/housing-news");
    final res = await http.get(url).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(res.body);

    if (decoded is Map<String, dynamic>) {
      return List<Map<String, dynamic>>.from(decoded["news"] ?? []);
    }

    if (decoded is List) {
      return List<Map<String, dynamic>>.from(decoded);
    }

    return [];
  }

  static Future<String> askAreaFollowup(
    String areaInput,
    String question,
  ) async {
    final url = Uri.parse("$baseUrl/area-report/followup").replace(
      queryParameters: {
        "area_input": areaInput,
        "question": question,
      },
    );

    final res = await http
        .get(url)
        .timeout(const Duration(minutes: 2));

    if (res.statusCode != 200) {
      throw Exception("Followup failed: ${res.statusCode} ${res.body}");
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data["answer"] ?? "No answer returned.";
  }

  static Future<void> logEvent(
    String userId,
    String eventType,
    Map<String, dynamic> payload,
  ) async {
    try {
      await http.post(
        Uri.parse("$baseUrl/events"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "event_type": eventType,
          "payload": payload,
        }),
      );
    } catch (_) {
      // never break the UI for a tracking event
    }
  }

  static Future<List<Map<String, dynamic>>> fetchInsights(String userId) async {
    final url = Uri.parse("$baseUrl/insights/$userId");
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception("Insights failed");
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data["insights"] ?? []);
  }
}