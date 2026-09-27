import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_map_search/pin.dart';

void main() {
  test('{ "pins": [...] } 形式の JSON からピン一覧を作れる', () {
    final pins = Pin.listFromJsonString('''
      {"pins": [
        {"id": "a", "title": "A", "description": "desc", "lat": 33, "lng": 130.5}
      ]}
    ''');

    expect(pins, hasLength(1));
    expect(pins.first.id, 'a');
    expect(pins.first.position.latitude, 33.0);
    expect(pins.first.position.longitude, 130.5);
  });
}
