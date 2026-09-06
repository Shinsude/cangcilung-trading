import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ApiService {
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  final String baseUrl;

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://cangcilung-trading-api.vercel.app',
  );

  Future<TradingData> fetchSignal(String symbol) async {
    final uri = Uri.parse('$baseUrl/signal/$symbol');
    final response = await http.get(uri).timeout(const Duration(seconds: 90));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TradingData.fromJson(json);
    }
    throw ApiException('Server error (${response.statusCode})');
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}