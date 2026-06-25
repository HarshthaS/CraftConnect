import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoiceGenerator {
  static Future<Uint8List> generateInvoicePDF(
      Map<String, dynamic> invoice) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "CraftConnect",
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "INVOICE",
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text("Invoice ID: ${invoice['invoice_id']}"),
                      pw.Text("Date: ${invoice['generated_at']}"),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell("Product"),
                      _cell("Qty"),
                      _cell("Unit Price"),
                      _cell("Total"),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell(invoice['product_name']),
                      _cell(invoice['qty'].toString()),
                      _cell("Rs ${invoice['price_per_unit']}"),
                      _cell("Rs ${invoice['total_product_price']}"),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    "Delivery Cost: Rs ${invoice['delivery_cost']}",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.green),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      "Grand Total: Rs ${invoice['grand_total']}",
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                "Payment Mode: ${invoice['payment_mode']}",
                style: const pw.TextStyle(fontSize: 12),
              ),

              pw.Spacer(),

              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  "Thank you for supporting local artisans through CraftConnect!",
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text),
    );
  }
}
