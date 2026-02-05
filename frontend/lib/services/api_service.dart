import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/calc_models.dart';

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
}
