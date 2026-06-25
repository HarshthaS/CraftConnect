import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/invoice_generator.dart';

class InvoiceService {
  static Future<Map<String, String>> createAndUploadInvoice({
    required String orderId,
    required Map<String, dynamic> order,
  }) async {
    final supabase = Supabase.instance.client;

    final invoiceData = {
      "invoice_id": orderId,
      "generated_at": DateTime.now().toString().split('.')[0],
      "product_name": order["product_name"] ?? "Product",
      "qty": order["quantity"] ?? 1,
      "price_per_unit": order["price"] ??
          ((order["grand_total"] ?? 0) / (order["quantity"] ?? 1)),
      "total_product_price": order["grand_total"] ?? 0,
      "delivery_cost": order["delivery_cost"] ?? 0,
      "grand_total": order["grand_total"] ?? 0,
      "payment_mode": order["payment_mode"] ?? "-",
    };

    final Uint8List pdfBytes =
    await InvoiceGenerator.generateInvoicePDF(invoiceData);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/invoice_$orderId.pdf');
    await file.writeAsBytes(pdfBytes);

    final storagePath = 'invoice_$orderId.pdf';

    await supabase.storage
        .from('invoices')
        .upload(
      storagePath,
      file,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'application/pdf',
      ),
    );


    final signedUrl = await supabase.storage
        .from('invoices')
        .createSignedUrl(storagePath, 3600);



    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'invoice_url': signedUrl,
    });

    return {
      "localPath": file.path,
      "remoteUrl": signedUrl,
    };
  }
}
