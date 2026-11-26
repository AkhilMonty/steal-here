import 'dart:convert';

import 'package:http/http.dart' as http;

class GlobalLocation {
  final String name;
  final String? code;

  const GlobalLocation({required this.name, this.code});

  factory GlobalLocation.fromMap(Map<String, dynamic> map) {
    return GlobalLocation(
      name: (map['name'] ?? '').toString(),
      code: (map['Iso2'] ?? map['iso2'] ?? map['state_code'])?.toString(),
    );
  }

  @override
  String toString() => name;
}

class GlobalLocationService {
  GlobalLocationService._();

  static const String _baseUrl = 'https://countriesnow.space/api/v0.1';

  static final Map<String, List<GlobalLocation>> _cache = {};

  static Future<List<GlobalLocation>> getCountries() async {
    if (_cache.containsKey('countries')) {
      return _cache['countries']!;
    }

    final data = await _get('/countries/iso');

    final countries = data
        .map((item) => GlobalLocation.fromMap(item as Map<String, dynamic>))
        .where((item) => item.name.isNotEmpty)
        .toList();

    countries.sort((a, b) => a.name.compareTo(b.name));

    _cache['countries'] = countries;

    return countries;
  }

  static Future<List<GlobalLocation>> getStates(String country) async {
    final cacheKey = 'states_$country';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final uri = Uri.parse('$_baseUrl/countries/states/q')
        .replace(queryParameters: {'country': country});

    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    final body = _decodeResponse(response);

    final data = body['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid states response.');
    }

    final states = data['states'];

    if (states is! List) {
      return [];
    }

    final locations = states
        .map((item) {
          if (item is String) {
            return GlobalLocation(name: item);
          }

          return GlobalLocation.fromMap(item as Map<String, dynamic>);
        })
        .where((item) => item.name.isNotEmpty)
        .toList();

    locations.sort((a, b) => a.name.compareTo(b.name));

    _cache[cacheKey] = locations;

    return locations;
  }

  static Future<List<GlobalLocation>> getCities(
    String country,
    String state,
  ) async {
    final cacheKey = 'cities_${country}_$state';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final uri = Uri.parse('$_baseUrl/countries/state/cities');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'country': country, 'state': state}),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeResponse(response);
    final data = body['data'];

    if (data is! List) {
      throw Exception('Invalid cities response.');
    }

    final locations = data
        .map((item) {
          if (item is String) {
            return GlobalLocation(name: item);
          }

          return GlobalLocation.fromMap(item as Map<String, dynamic>);
        })
        .where((item) => item.name.isNotEmpty)
        .toList();

    locations.sort((a, b) => a.name.compareTo(b.name));

    _cache[cacheKey] = locations;

    return locations;
  }

  static Future<List<dynamic>> _get(String endpoint) async {
    final response = await http
        .get(Uri.parse('$_baseUrl$endpoint'))
        .timeout(const Duration(seconds: 20));

    final body = _decodeResponse(response);
    final data = body['data'];

    if (data is! List) {
      throw Exception('Invalid location response.');
    }

    return data;
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('Location request failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);

    if (body is! Map<String, dynamic>) {
      throw Exception('Invalid API response.');
    }

    if (body['error'] == true) {
      throw Exception(body['msg'] ?? 'Unable to retrieve location data.');
    }

    return body;
  }

  static void clearCache() {
    _cache.clear();
  }
}
