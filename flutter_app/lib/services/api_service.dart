import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class ApiService {
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  final String baseUrl;

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://cangcilung-trading-api.vercel.app',
  );

  static String _cacheKey(String symbol) => 'cached_signal_${symbol.toUpperCase()}';

  Future<void> warmup() async {
    try {
      await http.get(Uri.parse('$baseUrl/warm')).timeout(const Duration(seconds: 30));
    } catch (_) {}
  }

  Future<TradingData> fetchSignal(String symbol, {bool useCache = true}) async {
    final upper = symbol.toUpperCase();

    if (useCache) {
      final cached = await readCachedSignal(upper);
      if (cached != null) return cached;
    }

    final uri = Uri.parse('$baseUrl/signal/$upper');
    final response = await http.get(uri).timeout(const Duration(seconds: 90));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = TradingData.fromJson(json);
      await _writeCache(upper, response.body);
      return data;
    }
    throw ApiException('Server error (${response.statusCode})');
  }

  Future<TradingData?> readCachedSignal(String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(symbol.toUpperCase()));
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TradingData.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String symbol, String rawBody) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(symbol), rawBody);
    } catch (_) {}
  }

  Future<ModelInfo> fetchModel() async {
    final uri = Uri.parse('$baseUrl/model');
    final response = await http.get(uri).timeout(const Duration(seconds: 90));
    if (response.statusCode == 200) {
      return ModelInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
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