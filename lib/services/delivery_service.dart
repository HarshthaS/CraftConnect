// lib/services/delivery_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class DeliveryService {

  static Future<double?> getDistanceInKm({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {

    double? osrmDistance = await _getOSRMDistance(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );

    if (osrmDistance != null && osrmDistance > 0 && osrmDistance < 3000) {
      return osrmDistance;
    }

    return _haversineDistance(
      originLat,
      originLng,
      destLat,
      destLng,
    );
  }

  static Future<double?> _getOSRMDistance({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final url =
        "https://router.project-osrm.org/route/v1/driving/"
        "$originLng,$originLat;$destLng,$destLat"
        "?overview=false&alternatives=false&steps=false";

    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );

      if (!response.body.trim().startsWith("{")) {
        print("❌ OSRM Error: HTML received instead of JSON");
        return null;
      }

      final data = jsonDecode(response.body);

      if (data["routes"] != null &&
          data["routes"] is List &&
          data["routes"].isNotEmpty) {
        final meters = data["routes"][0]["distance"] ?? 0;
        final km = meters / 1000.0;

        if (km <= 0 || km > 3000) {
          print("❗ OSRM unrealistic distance: $km");
          return null;
        }

        return km;
      }
    } catch (e) {
      print("❌ OSRM Exception: $e");
      return null;
    }

    return null;
  }

  static double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;

    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);

    lat1 = _degToRad(lat1);
    lat2 = _degToRad(lat2);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) *
            sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _degToRad(double deg) {
    return deg * pi / 180.0;
  }
}
