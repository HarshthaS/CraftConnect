
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_filex/open_filex.dart';
import '../widgets/order_timeline.dart';
import 'invoice_viewer.dart';
import '../services/invoice_service.dart';
import 'package:url_launcher/url_launcher.dart';


class BuyerOrdersScreen extends StatelessWidget {
  const BuyerOrdersScreen({super.key});

  double _safeDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _openInvoice(BuildContext context, Map<String, dynamic> order) async {
    final url = (order['invoice_url'] ?? '').toString();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invoice not available")),
      );
      return;
    }

    final uri = Uri.parse(url);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }




  void _showTracking(BuildContext context, Map<String, dynamic> order) {
    final orderStatus = (order['order_status'] as String?)
        ?? (order['status'] as String? ?? 'placed');
    final timeline = (order['timeline'] is Map)
        ? Map<String, dynamic>.from(order['timeline'])
        : null;

    final bool isCompleted =
        (order["order_completed"] == true) || orderStatus == "delivered";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.36,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Text(
                  "Order Tracking",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800),
                ),
                const SizedBox(height: 8),
                Text(
                  "Current status: ${isCompleted ? "Completed" : orderStatus[0].toUpperCase() + orderStatus.substring(1)}",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                OrderTimeline(
                  status: isCompleted ? "completed" : orderStatus,
                  timeline: timeline,
                ),

                const SizedBox(height: 12),
                if (order['order_status'] == 'cancelled' ||
                    order['status'] == 'cancelled')
                  Center(
                    child: Text("Order was cancelled",
                        style: TextStyle(color: Colors.red.shade700)),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close")),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('buyer_uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Orders"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No orders yet"));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final raw = docs[index];
              final Map<String, dynamic> d =
              Map<String, dynamic>.from(raw.data() as Map<String, dynamic>);
              d["order_id"] = raw.id;

              final qty = _safeInt(d["quantity"]);
              final total = _safeDouble(
                  d["total_price"] ??
                      d["grand_total"] ??
                      d["grandTotal"] ??
                      0);

              final orderStatus =
                  (d['order_status'] as String?) ?? (d['status'] as String? ?? "placed");

              final bool isCompleted =
                  (d["order_completed"] == true) || orderStatus == "delivered";

              final paymentMode = (d['payment_mode'] as String?) ?? "-";
              final paymentStatus = (d['payment_status'] as String?) ??
                  ((paymentMode.toLowerCase().contains('cash'))
                      ? 'pending'
                      : 'paid');

              final ts = d["timestamp"] as Timestamp?;
              final time =
              ts != null ? ts.toDate().toString().split('.')[0] : "";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: (d['product_image'] ?? '').toString().isNotEmpty
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            d['product_image'],
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image,
                              size: 36, color: Colors.black26),
                        ),
                        title: Text(
                          d["product_name"] ?? "Product",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                        Text("Qty: $qty  •  ₹${total.toStringAsFixed(0)}"),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [

                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                  color: isCompleted
                                      ? Colors.green.shade50
                                      : orderStatus == 'cancelled'
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: orderStatus == 'cancelled'
                                          ? Colors.red.shade200
                                          : Colors.green.shade200)),
                              child: Text(
                                isCompleted
                                    ? "Completed"
                                    : orderStatus[0].toUpperCase() +
                                    orderStatus.substring(1),
                                style: TextStyle(
                                    color: isCompleted
                                        ? Colors.green
                                        : orderStatus == 'cancelled'
                                        ? Colors.red.shade700
                                        : Colors.green.shade800,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(time, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),

                      const Divider(),

                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          if (isCompleted && d['invoice_generated'] == true)
                            TextButton.icon(
                              onPressed: () => _openInvoice(context, d),
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
                              label: const Text("Invoice"),
                            ),


                          TextButton.icon(
                            onPressed: () => _showTracking(context, d),
                            icon: const Icon(Icons.local_shipping),
                            label: const Text("Track"),
                          ),

                          if (orderStatus == "placed")
                            TextButton.icon(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('orders')
                                    .doc(d["order_id"])
                                    .update({
                                  'order_status': 'cancelled',
                                  'timeline.cancelled': FieldValue.serverTimestamp(),
                                  'timestamp': FieldValue.serverTimestamp(),
                                });
                              },
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              label: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      )

                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
