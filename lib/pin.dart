import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 地図上に表示するピン1つ分のデータ
class Pin {
  const Pin({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
  });

  final String id;
  final String title;
  final String description;
  final LatLng position;

  factory Pin.fromJson(Map<String, dynamic> json) {
    return Pin(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
    );
  }

  /// assets 内の JSON 配列からピン一覧を読み込む
  static Future<List<Pin>> loadFromAsset(String path) async {
    final jsonString = await rootBundle.loadString(path);
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => Pin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Marker toMarker() {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(title: title, snippet: description),
    );
  }
}
