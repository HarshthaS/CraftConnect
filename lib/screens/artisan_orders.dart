// lib/screens/artisan_orders.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/order_timeline.dart';
import '../services/invoice_service.dart';
import 'package:open_filex/open_filex.dart';


class ArtisanOrdersScreen extends StatelessWidget {
  const ArtisanOrdersScreen({super.key});
  int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    final update = {
      "order_status": newStatus,
      "timeline.$newStatus": FieldValue.serverTimestamp(),
      "timestamp": FieldValue.serverTimestamp(),
    };

    if (newStatus == "delivered") {
      update["order_completed"] = true;
      update["timeline.completed"] = FieldValue.serverTimestamp();

      update["payment_status"] = "paid";
    }



    await FirebaseFirestore.instance.collection("orders").doc(orderId).update(update);
  }
  Future<void> _rejectOrder(String orderId) async {
    await FirebaseFirestore.instance.collection("orders").doc(orderId).update({
      "order_status": "cancelled",
      "timeline.cancelled": FieldValue.serverTimestamp(),
      "timestamp": FieldValue.serverTimestamp(),
    });
  }
  Future<String?> _generateInvoiceIfNeeded(
      String orderId,
      Map<String, dynamic> order,
      ) async {

    final existingPath =
    (order["invoice_local_path"] ?? "").toString();

    if (existingPath.isNotEmpty) {
      return existingPath;
    }

    final result = await InvoiceService.createAndUploadInvoice(
      orderId: orderId,
      order: order,
    );

    final localPath = result["localPath"];

    await FirebaseFirestore.instance
        .collection("orders")
        .doc(orderId)
        .update({
      "invoice_local_path": localPath,
    });

    return localPath;
  }

  String? _nextStep(String s) {
    switch (s) {
      case "placed":
        return "accepted";
      case "accepted":
        return "packed";
      case "packed":
        return "shipped";
      case "shipped":
        return "delivered";
      default:
        return null;
    }
  }

  String _stepLabel(String s) {
    switch (s) {
      case "accepted":
        return "Accept Order";
      case "packed":
        return "Mark Packed";
      case "shipped":
        return "Mark Shipped";
      case "delivered":
        return "Mark Delivered";
      default:
        return "";
    }
  }

  Color _stepColor(String s) {
    switch (s) {
      case "accepted":
        return Colors.blue;
      case "packed":
        return Colors.orange;
      case "shipped":
        return Colors.teal;
      case "delivered":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text("Please login")));

    final stream = FirebaseFirestore.instance
        .collection("orders")
        .where("artisan_uid", isEqualTo: uid)
        .orderBy("timestamp", descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders Received"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No orders yet"));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final raw = docs[i];
              final d = Map<String, dynamic>.from(raw.data() as Map<String, dynamic>);
              final orderId = raw.id;

              final product = d["product_name"] ?? "Product";

              final orderStatus = (d['order_status'] as String?)
                  ?? (d['status'] == 'paid' ? 'placed' : (d['status'] as String? ?? 'placed'));

              final paymentStatus = (d['payment_status'] as String?) ??
                  ((d['payment_mode'] ?? '').toString().toLowerCase().contains('cash')
                      ? 'pending'
                      : 'paid');

              final bool isPlaced = orderStatus == "placed";
              final bool isCancelled = orderStatus == "cancelled";

              final bool isCompleted =
                  !isCancelled &&
                      ((d["order_completed"] == true) || orderStatus == "delivered");


              final next = _nextStep(orderStatus);
              final hasInvoice =
                  (d['invoice_local_path'] ?? '').toString().isNotEmpty;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: paymentStatus == 'pending'
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCancelled
                                    ? Colors.red.shade50
                                    : (paymentStatus == 'pending'
                                    ? Colors.orange.shade50
                                    : Colors.green.shade50),
                              ),
                            ),
                            child: Text(
                              isCancelled
                                  ? 'CANCELLED'
                                  : (paymentStatus == 'pending' ? 'COD' : 'PAID'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isCancelled
                                    ? Colors.red
                                    : (paymentStatus == 'pending'
                                    ? Colors.orange
                                    : Colors.green.shade800),
                              ),
                            ),

                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "Order: ${orderStatus.toUpperCase()}",
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),

                      const SizedBox(height: 10),

                      if (isCancelled)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: const Text(
                            "ORDER CANCELLED",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        )
                      else if (isCompleted)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "ORDER COMPLETED",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.receipt_long, color: Colors.white),
                                label: Text(
                                  d['invoice_generated'] == true
                                      ? "INVOICE GENERATED"
                                      : "GENERATE INVOICE",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: d['invoice_generated'] == true
                                      ? Colors.grey
                                      : Colors.orange,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: d['invoice_generated'] == true
                                    ? null
                                    : () async {
                                  await InvoiceService.createAndUploadInvoice(
                                    orderId: orderId,
                                    order: d,
                                  );

                                  await FirebaseFirestore.instance
                                      .collection("orders")
                                      .doc(orderId)
                                      .update({
                                    "invoice_generated": true,
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Invoice generated")),
                                    );
                                  }
                                },
                              ),

                            ),
                          ],
                        )
                      else if (isPlaced)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text("ACCEPT", style: TextStyle(color: Colors.white)),
                                  onPressed: () async {
                                    await _updateOrderStatus(orderId, "accepted");
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text("REJECT", style: TextStyle(color: Colors.white)),
                                  onPressed: () async {
                                    await _rejectOrder(orderId);
                                  },
                                ),
                              ),
                            ],
                          )
                          else if (next != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _stepColor(next),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _stepLabel(next),
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(_stepLabel(next)),
                                  content: Text(
                                    "Are you sure you want to ${_stepLabel(next).toLowerCase()}?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text("No"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text("Yes"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await _updateOrderStatus(orderId, next);
                                await _generateInvoiceIfNeeded(orderId, d);

                                if (next == "delivered") {
                                  final snap = await FirebaseFirestore.instance
                                      .collection("orders")
                                      .doc(orderId)
                                      .get();

                                  if (snap.exists) {
                                    await _generateInvoiceIfNeeded(orderId, snap.data()!);
                                  }
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("${_stepLabel(next)} completed"),
                                    ),
                                  );
                                }
                              }

                            },
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: const Text(
                            "ORDER COMPLETED",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      Center(
                        child: TextButton(
                          child: const Text("View Details"),
                          onPressed: () {
                            _showDetails(context, d);
                          },
                        ),
                      ),
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

  void _showDetails(BuildContext context, Map<String, dynamic> d) {
    final name = d["product_name"] ?? "Product";
    final buyer = d["buyer_display"] ?? d["buyer_uid"];
    final qty = _safeInt(d["quantity"]);
    final paymentMode = d["payment_mode"] ?? "-";

    final orderStatus = (d['order_status'] as String?)
        ?? (d['status'] == 'paid' ? 'placed' : (d['status'] as String? ?? 'placed'));

    final paymentStatus = (d['payment_status'] as String?) ??
        ((paymentMode.toString().toLowerCase().contains('cash')) ? 'pending' : 'paid');

    final bool isCompleted =
        (d["order_completed"] == true) || orderStatus == "delivered";

    final timeline =
    (d["timeline"] is Map) ? Map<String, dynamic>.from(d["timeline"]) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.70,
        maxChildSize: 0.95,
        minChildSize: 0.45,
        builder: (_, controller) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: controller,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  Text(
                    "Order Details",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text("Product: $name"),
                  const SizedBox(height: 6),
                  Text("Buyer: $buyer"),
                  const SizedBox(height: 6),
                  Text("Quantity: $qty"),
                  const SizedBox(height: 6),
                  Text("Payment Mode: $paymentMode"),
                  const SizedBox(height: 6),
                  Text("Payment Status: ${paymentStatus.toUpperCase()}"),
                  const SizedBox(height: 6),
                  Text("Current Status: ${orderStatus.toUpperCase()}"),
                  const SizedBox(height: 14),

                  OrderTimeline(
                    status: isCompleted ? "completed" : orderStatus,
                    timeline: timeline,
                  ),



                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
