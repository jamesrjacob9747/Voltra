import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class VoltraApi {
  VoltraApi({String baseUrl = apiBaseUrl, http.Client? client})
      : _base = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;
  static const _timeout = Duration(seconds: 8);

  String get baseUrl => _base.toString();

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = _base.replace(path: path, queryParameters: query);
    try {
      final resp = await _client.get(uri).timeout(_timeout);
      final body = resp.body.isEmpty ? null : jsonDecode(utf8.decode(resp.bodyBytes));
      if (resp.statusCode >= 400) {
        final detail = body is Map ? body['detail'] : null;
        throw ApiException(detail is String ? detail : 'Server error ${resp.statusCode}');
      }
      return body;
    } on SocketException {
      throw ApiException("Can't reach the Voltra server at $baseUrl");
    } on TimeoutException {
      throw ApiException('The Voltra server at $baseUrl took too long to answer');
    }
  }

  Future<List<AppUser>> users() async {
    final list = await _get('/users') as List<dynamic>;
    return list.map((j) => AppUser.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Charger>> chargers({required double lat, required double lng, double radiusKm = 5}) async {
    final list = await _get('/chargers', {
      'lat': '$lat',
      'lng': '$lng',
      'radius_km': '$radiusKm',
    }) as List<dynamic>;
    return list.map((j) => Charger.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Charger> charger(int id, {int? userId}) async {
    final j = await _get('/chargers/$id', userId == null ? null : {'user_id': '$userId'});
    return Charger.fromJson(j as Map<String, dynamic>);
  }
}

final api = VoltraApi();
