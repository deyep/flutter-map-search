import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_map_search/pin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assets/pins.json からピン一覧を読み込める', () async {
    final pins = await Pin.loadFromAsset('assets/pins.json');

    expect(pins, hasLength(5));
    expect(pins.first.title, '天神駅');
    expect(pins.map((p) => p.id).toSet(), hasLength(pins.length));
  });
}
