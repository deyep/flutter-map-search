import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'pin.dart';

/// ピン一覧の取得元を抽象化する
abstract class PinRepository {
  Future<List<Pin>> fetchPins();
}

/// assets 内の JSON からピン一覧を読み込む
class AssetPinRepository implements PinRepository {
  AssetPinRepository({this.path = 'assets/pins.json', AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final String path;
  final AssetBundle _bundle;

  @override
  Future<List<Pin>> fetchPins() async {
    final jsonString = await _bundle.loadString(path);
    return Pin.listFromJsonString(jsonString);
  }
}

/// サーバーの `GET /api/pins` からピン一覧を取得する
class ApiPinRepository implements PinRepository {
  ApiPinRepository({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<List<Pin>> fetchPins() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/pins'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw PinRepositoryException(
        'ピンの取得に失敗しました (HTTP ${response.statusCode})',
      );
    }
    // Content-Type に charset が無いと latin1 扱いになるため、明示的に UTF-8 で読む
    return Pin.listFromJsonString(utf8.decode(response.bodyBytes));
  }
}

class PinRepositoryException implements Exception {
  PinRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `--dart-define=API_BASE_URL=...` が指定されていれば API、なければ assets を使う
PinRepository createPinRepository() {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) return AssetPinRepository();
  return ApiPinRepository(baseUrl: baseUrl);
}
