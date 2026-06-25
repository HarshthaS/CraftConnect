import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../utils/invoice_generator.dart';

class InvoiceScreen extends StatelessWidget {
  final Map<String, dynamic> invoiceData;

  const InvoiceScreen({super.key, required this.invoiceData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice"),
        backgroundColor: Colors.orange,
      ),
      body: PdfPreview(
        build: (format) => InvoiceGenerator.generateInvoicePDF(invoiceData),
      ),
    );
  }
}
