// lib/screens/invoice_viewer.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';

class InvoiceViewer extends StatelessWidget {
  final String? filePath;
  final String? remoteUrl;

  const InvoiceViewer({super.key, this.filePath, this.remoteUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            /// LOCAL PDF (ONLY WHEN AVAILABLE)
            if (filePath != null && filePath!.isNotEmpty) ...[
              ElevatedButton(
                onPressed: () async {
                  final file = File(filePath!);

                  if (!await file.exists()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Local invoice not found')),
                    );
                    return;
                  }

                  await OpenFilex.open(file.path);
                },
                child: const Text('Open Local PDF'),
              ),
            ],

            if (remoteUrl != null && remoteUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse(remoteUrl!);

                  if (!await canLaunchUrl(uri)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot open invoice URL')),
                    );
                    return;
                  }

                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: const Text('Open Invoice'),
              ),
            ],

            if ((filePath == null || filePath!.isEmpty) &&
                (remoteUrl == null || remoteUrl!.isEmpty))
              const Text('No invoice available'),
          ],
        ),
      ),
    );
  }
}
