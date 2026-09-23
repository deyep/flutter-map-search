import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'pin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

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
    final pins = await Pin.loadFromAsset('assets/pins.json');
    if (!mounted) return;
    setState(() {
      _markers = pins.map((pin) => pin.toMarker()).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: GoogleMap(
        initialCameraPosition: _fukuokaChuo,
        markers: _markers,
      ),
    );
  }
}
