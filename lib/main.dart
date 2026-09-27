import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'pin_repository.dart';

void main() {
  runApp(MyApp(pinRepository: createPinRepository()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.pinRepository});

  final PinRepository pinRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MapPage(pinRepository: pinRepository));
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.pinRepository});

  final PinRepository pinRepository;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // 最初に表示する場所（福岡市中央区）
  static const _fukuokaChuo = CameraPosition(
    target: LatLng(33.5870, 130.3900),
    zoom: 14,
  );

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    try {
      final pins = await widget.pinRepository.fetchPins();
      if (!mounted) return;
      setState(() {
        _markers = pins.map((pin) => pin.toMarker()).toSet();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ピンを読み込めませんでした: $e'),
          action: SnackBarAction(label: '再試行', onPressed: _loadPins),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar・SafeArea を使わず、ステータスバーの裏まで地図を描画する
      body: GoogleMap(
        initialCameraPosition: _fukuokaChuo,
        markers: _markers,
        // 地図のボタンやロゴがステータスバーやホームインジケーターに隠れないよう上下に余白を取る
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
      ),
    );
  }
}
