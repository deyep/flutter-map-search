import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_map_search/pin_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetPinRepository', () {
    test('assets/pins.json からピン一覧を読み込める', () async {
      final pins = await AssetPinRepository().fetchPins();

      expect(pins, hasLength(5));
      expect(pins.first.title, '天神駅');
      expect(pins.map((p) => p.id).toSet(), hasLength(pins.length));
    });
  });

  group('ApiPinRepository', () {
    test('GET /api/pins のレスポンスからピン一覧を作れる', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        // charset なしでも日本語が化けないことを確認するため bytes で返す
        return http.Response.bytes(
          utf8.encode(
            '{"pins":[{"id":"x","title":"天神駅","description":"d","lat":33.59,"lng":130.39}]}',
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = ApiPinRepository(
        baseUrl: 'https://example.com',
        client: client,
      );

      final pins = await repository.fetchPins();

      expect(requested.toString(), 'https://example.com/api/pins');
      expect(pins.single.title, '天神駅');
    });

    test('200 以外のステータスでは例外を投げる', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      final repository = ApiPinRepository(
        baseUrl: 'https://example.com',
        client: client,
      );

      expect(repository.fetchPins(), throwsA(isA<PinRepositoryException>()));
    });
  });
}
