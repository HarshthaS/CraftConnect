// lib/screens/location_map.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMapScreen extends StatelessWidget {
  final double lat;
  final double lng;
  final String name;

  const LocationMapScreen({
    super.key,
    required this.lat,
    required this.lng,
    required this.name,
  });

  String get _googleMapsUrl => 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  String get _geoUri => 'geo:$lat,$lng?q=$lat,$lng($name)';

  Future<void> _openMaps() async {
    final uri = Uri.parse(_geoUri);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    final web = Uri.parse(_googleMapsUrl);
    if (await canLaunchUrl(web)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
      return;
    }
    throw 'Could not open maps';
  }

  @override
  Widget build(BuildContext context) {
    final display = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Location'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map, size: 48, color: Colors.black54),
                  const SizedBox(height: 8),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(display, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Open this location in your maps app for navigation or to view the exact spot.',
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await _openMaps();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open maps: $e')),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in Maps'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
