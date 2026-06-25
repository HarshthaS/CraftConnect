// lib/screens/product_details.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/delivery_service.dart';
import '../services/delivery_logic.dart';

import 'payment_selection.dart';

import '../services/invoice_service.dart';

class ProductDetailsPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> data;

  const ProductDetailsPage({
    required this.productId,
    required this.data,
    Key? key,
  }) : super(key: key);

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

enum DeliverySpeed { standard, fast, express }

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  int orderQty = 1;
  bool isPlacingOrder = false;

  Map<String, dynamic>? artisanData;

  double? deliveryDistance;
  String? deliveryMethod;
  double? deliveryCost;
  bool loadingDelivery = true;

  DeliverySpeed _selectedSpeed = DeliverySpeed.standard;
  bool _extraProtection = false;

  Map<String, dynamic>? _selectedDeliveryOption;

  static const List<String> _fragileMaterialKeywords = [
    "glass",
    "ceramic",
    "clay",
    "terracotta",
    "pottery",
    "porcelain",
    "mirror",
    "mirror work",
    "marble",
    "stone",
    "seashell",
  ];

  final Map<DeliverySpeed, List<Map<String, dynamic>>> deliveryOptions = {
    DeliverySpeed.standard: [
      {
        "name": "Standard Delivery (Free)",
        "base": 0.0,
        "perKm": 0.0,
      },
    ],
    DeliverySpeed.fast: [
      {"name": "Priority Courier", "base": 45.0, "perKm": 0.8},
      {"name": "Express Surface Courier", "base": 55.0, "perKm": 1.0},
    ],
    DeliverySpeed.express: [
      {"name": "Air Courier Prime", "base": 65.0, "perKm": 1.2},
      {"name": "Same-Day Express Partner", "base": 75.0, "perKm": 1.4},
    ],
  };

  static const double fragileFeeFixed = 12.0;
  static const double extraProtectionFeeFixed = 10.0;

  @override
  void initState() {
    super.initState();
    _initDefaultOptionForSpeed(_selectedSpeed);
    fetchArtisanDetails();
    loadDeliveryInfo();
  }

  void _initDefaultOptionForSpeed(DeliverySpeed s) {
    final opts = deliveryOptions[s];
    if (opts != null && opts.isNotEmpty) {
      _selectedDeliveryOption = Map<String, dynamic>.from(opts.first);
      deliveryMethod = _selectedDeliveryOption!["name"] as String;
    } else {
      _selectedDeliveryOption = null;
      deliveryMethod = _transportForSpeed(s);
    }
  }

  Future<void> fetchArtisanDetails() async {
    final uid = widget.data["artisan_uid"];
    if (uid == null || uid.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();

      if (doc.exists) {
        setState(() => artisanData = doc.data());
      }
    } catch (_) {}
  }

  Future<void> loadDeliveryInfo() async {
    final buyer = FirebaseAuth.instance.currentUser;
    if (buyer == null) {
      _applyFallbackDelivery();
      return;
    }

    try {
      final buyerDoc =
      await FirebaseFirestore.instance.collection("users").doc(buyer.uid).get();

      final artisanDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.data["artisan_uid"])
          .get();

      final buyerLat = buyerDoc.data()?["lat"];
      final buyerLng = buyerDoc.data()?["lng"];
      final artLat = artisanDoc.data()?["lat"];
      final artLng = artisanDoc.data()?["lng"];

      if (buyerLat == null || buyerLng == null || artLat == null || artLng == null) {
        _applyFallbackDelivery();
        return;
      }

      double? distance = await DeliveryService.getDistanceInKm(
        originLat: buyerLat,
        originLng: buyerLng,
        destLat: artLat,
        destLng: artLng,
      );

      if (distance != null && distance > 0) {
        deliveryDistance = distance;
        _recalculateDeliveryCost();
      } else {
        _applyFallbackDelivery();
      }
    } catch (e) {
      _applyFallbackDelivery();
    } finally {
      if (mounted) setState(() => loadingDelivery = false);
    }
  }

  void _applyFallbackDelivery() {
    deliveryDistance = 10.0;
    if (_selectedDeliveryOption == null) {
      _initDefaultOptionForSpeed(_selectedSpeed);
    } else {
      deliveryMethod = _selectedDeliveryOption!["name"] as String?;
    }
    _recalculateDeliveryCost();
    if (mounted) setState(() => loadingDelivery = false);
  }

  int _parseQty(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool _isMaterialFragile(String? material) {
    if (material == null) return false;
    final lowered = material.toLowerCase();
    for (final k in _fragileMaterialKeywords) {
      if (lowered.contains(k)) return true;
    }
    return false;
  }

  String _transportForSpeed(DeliverySpeed s) {
    switch (s) {
      case DeliverySpeed.standard:
        return "Economy Delivery Partner";
      case DeliverySpeed.fast:
        return "Priority Courier Service";
      case DeliverySpeed.express:
        return "Express Air/Surface Courier";
    }
  }

  double _computeCostFromSelectedOption({
    required Map<String, dynamic> option,
    required double distanceKm,
    required bool fragile,
    required bool extraProtection,
  }) {
    final double base = (option["base"] as num).toDouble();
    final double perKm = (option["perKm"] as num).toDouble();

    if (base == 0.0 && perKm == 0.0) {
      return 0.0;
    }

    double cost = base + (distanceKm * perKm);

    if (fragile) cost += fragileFeeFixed;
    if (extraProtection) cost += extraProtectionFeeFixed;

    if (cost < 50) cost = 50;
    if (cost > 150) cost = 150;

    return double.parse(cost.toStringAsFixed(0));
  }

  void _recalculateDeliveryCost() {
    final dist = deliveryDistance ?? 0.0;
    final fragile = _isMaterialFragile(widget.data["material"]?.toString());

    if (_selectedDeliveryOption != null) {
      final newCost = _computeCostFromSelectedOption(
        option: _selectedDeliveryOption!,
        distanceKm: dist,
        fragile: fragile,
        extraProtection: _extraProtection,
      );

      setState(() {
        deliveryCost = newCost;
        deliveryMethod = _selectedDeliveryOption!["name"] as String?;
      });
    } else {
      final fallbackOption = {
        "name": _transportForSpeed(_selectedSpeed),
        "base": 30.0,
        "perKm": 0.6
      };
      final newCost = _computeCostFromSelectedOption(
        option: fallbackOption,
        distanceKm: dist,
        fragile: fragile,
        extraProtection: _extraProtection,
      );

      setState(() {
        deliveryCost = newCost;
        deliveryMethod = fallbackOption["name"] as String?;
      });
    }
  }

  Future<String> placeOrderFromPayment({
    required String buyerId,
    required double unitPrice,
    required int quantity,
    required double totalProductPrice,
    required double grandTotal,
    required String paymentMode,
    required String paymentRef,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final prodRef = firestore.collection("products").doc(widget.productId);
    final orderRef = firestore.collection("orders").doc();

    return await firestore.runTransaction((transaction) async {
      final prodSnap = await transaction.get(prodRef);

      if (!prodSnap.exists) {
        throw Exception("Product not found");
      }

      final data = prodSnap.data() as Map<String, dynamic>;
      final currentQty = _parseQty(data["quantity"]);

      if (currentQty <= 0) {
        throw Exception("Product is out of stock");
      }

      if (quantity > currentQty) {
        throw Exception("Only $currentQty items available");
      }

      transaction.update(prodRef, {
        "quantity": currentQty - quantity,
        "in_stock": (currentQty - quantity) > 0,
      });

      final safeDeliveryDistance = deliveryDistance ?? 10.0;
      final safeDeliveryCost = deliveryCost ?? 50.0;
      final safeDeliveryMethod = deliveryMethod ?? "Delivery";

      transaction.set(orderRef, {
        "buyer_uid": buyerId,
        "artisan_uid": widget.data["artisan_uid"],
        "product_id": widget.productId,
        "product_name": widget.data["name"] ?? "Product",
        "product_image": widget.data["image_url"] ?? "",
        "unit_price": unitPrice,
        "quantity": quantity,
        "total_price": totalProductPrice,
        "delivery_cost": safeDeliveryCost,
        "delivery_method": safeDeliveryMethod,
        "delivery_distance": safeDeliveryDistance,
        "grand_total": grandTotal,
        "payment_mode": paymentMode,
        "payment_ref": paymentRef,
        "order_status": "placed",
        "payment_status":
        paymentMode == "Cash on Delivery" ? "pending" : "paid",
        "timeline": {
          "placed": FieldValue.serverTimestamp(),
        },
        "timestamp": FieldValue.serverTimestamp(),
        "invoice_url": "",
        "invoice_local_path": "",
      });
      // 🔹 Track purchased material for recommendation
      final material =
      (widget.data["material"] ?? "").toString().toLowerCase();

      if (material.isNotEmpty) {
        transaction.update(
          FirebaseFirestore.instance
              .collection("users")
              .doc(buyerId),
          {
            "purchased_materials": FieldValue.arrayUnion([material])
          },
        );
      }

      return orderRef.id;
    });
  }


  String _labelForSpeed(DeliverySpeed s) {
    switch (s) {
      case DeliverySpeed.standard:
        return "Standard";
      case DeliverySpeed.fast:
        return "Fast";
      case DeliverySpeed.express:
        return "Express";
    }
  }

  Widget _infoTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange)),
      child: Text(text, style: const TextStyle(color: Colors.orange)),
    );
  }

  IconData _iconForSpeed(DeliverySpeed s) {
    switch (s) {
      case DeliverySpeed.standard:
        return Icons.local_shipping;
      case DeliverySpeed.fast:
        return Icons.flash_on;
      case DeliverySpeed.express:
        return Icons.airplanemode_active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final availableQty = _parseQty(data["quantity"]);

    final rawPrice = data["price"];
    final price =
    (rawPrice is num) ? rawPrice.toDouble() : double.tryParse(rawPrice.toString()) ?? 0.0;

    final isFragile = _isMaterialFragile(data["material"]?.toString());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Details"),
        backgroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  AspectRatio(
                    aspectRatio: 1,
                    child: (data["image_url"] ?? "").toString().isNotEmpty
                        ? Image.network(
                      data["image_url"],
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, size: 80),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data["name"] ?? "",
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          "₹ ${price.toStringAsFixed(0)}",
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("Available: $availableQty"),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text("Material: ${data['material'] ?? '—'}"),
                        const SizedBox(width: 12),
                        if (isFragile) _infoTag("Fragile Item"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (artisanData != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const Text("Artisan Details",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("Name: ${artisanData!['name'] ?? '—'}"),
                          Text("Mobile: ${artisanData!['mobile'] ?? '—'}"),
                          Text("Address: ${artisanData!['address'] ?? '—'}"),
                          const Divider(),
                        ],
                      ),
                    ),

                  loadingDelivery
                      ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("Calculating delivery...",
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  )
                      : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Delivery Options",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "Choose a delivery speed depending on your urgency.\n"
                                "After selecting speed, choose a transport option (each option differs by price and speed).",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                            "Distance: ${deliveryDistance?.toStringAsFixed(1) ?? '-'} km"),
                        const SizedBox(height: 10),

                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: DeliverySpeed.values.map((s) {
                              final label = _labelForSpeed(s);
                              final eta = s == DeliverySpeed.standard
                                  ? "3–5 days"
                                  : s == DeliverySpeed.fast
                                  ? "2–3 days"
                                  : "1–2 days";

                              return Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  RadioListTile<DeliverySpeed>(
                                    value: s,
                                    dense: true,
                                    groupValue: _selectedSpeed,
                                    secondary: Icon(_iconForSpeed(s),
                                        color: Colors.orange),
                                    title: Text(label,
                                        style:
                                        const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      eta,
                                      style: TextStyle(
                                          color: Colors.grey.shade600),
                                    ),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _selectedSpeed = v;
                                        _initDefaultOptionForSpeed(v);
                                      });
                                      _recalculateDeliveryCost();
                                    },
                                  ),

                                  if (_selectedSpeed == s)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 12.0,
                                          right: 8.0,
                                          bottom: 8.0),
                                      child: Column(
                                        children: deliveryOptions[s]!
                                            .map((opt) {
                                          final optName =
                                          opt["name"] as String;
                                          final isSelected =
                                              _selectedDeliveryOption !=
                                                  null &&
                                                  _selectedDeliveryOption![
                                                  "name"] ==
                                                      optName;

                                          final previewDistance =
                                              deliveryDistance ?? 10.0;
                                          final fragile =
                                          _isMaterialFragile(widget
                                              .data["material"]
                                              ?.toString());
                                          final previewCost =
                                          _computeCostFromSelectedOption(
                                            option: opt,
                                            distanceKm:
                                            previewDistance,
                                            fragile: fragile,
                                            extraProtection:
                                            _extraProtection,
                                          );

                                          return Card(
                                            color: isSelected
                                                ? Colors
                                                .orange.shade50
                                                : null,
                                            margin: const EdgeInsets
                                                .symmetric(
                                                vertical: 6,
                                                horizontal: 4),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(
                                                    8)),
                                            child: RadioListTile<
                                                String>(
                                              value: optName,
                                              groupValue:
                                              _selectedDeliveryOption?[
                                              "name"],
                                              title: Text(optName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                      FontWeight
                                                          .w600)),
                                              subtitle: Text(
                                                "Preview: ₹${previewCost.toStringAsFixed(0)}",
                                                style: TextStyle(
                                                    color: Colors
                                                        .grey
                                                        .shade600,
                                                    fontSize: 12),
                                              ),
                                              secondary: isSelected
                                                  ? const Icon(
                                                  Icons
                                                      .check_circle,
                                                  color:
                                                  Colors.green)
                                                  : const Icon(Icons
                                                  .circle_outlined),
                                              onChanged: (_) {
                                                setState(() {
                                                  _selectedDeliveryOption =
                                                  Map<String,
                                                      dynamic>.from(
                                                      opt);
                                                  deliveryMethod =
                                                      optName;
                                                });
                                                _recalculateDeliveryCost();
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _extraProtection,
                          title: const Text(
                              "Extra Protection (+₹10)"),
                          subtitle: const Text(
                              "Bubble wrap + cushion packing"),
                          onChanged: (v) {
                            setState(() =>
                            _extraProtection = v ?? false);
                            _recalculateDeliveryCost();
                          },
                        ),

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Method: ${deliveryMethod ?? '-'}"),
                                Text("Estimated Fee",
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                            Text(
                              "₹ ${deliveryCost?.toStringAsFixed(0) ?? '--'}",
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),

                        const Divider(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text("Quantity:"),
                        const SizedBox(width: 10),
                        IconButton(
                          icon:
                          const Icon(Icons.remove_circle_outline),
                          onPressed: orderQty > 1
                              ? () =>
                              setState(() => orderQty--)
                              : null,
                        ),
                        Text(orderQty.toString()),
                        IconButton(
                          icon:
                          const Icon(Icons.add_circle_outline),
                          onPressed: orderQty < availableQty
                              ? () =>
                              setState(() => orderQty++)
                              : null,
                        ),
                        const Spacer(),
                        Text(
                          "Total: ₹ ${(price * orderQty).toStringAsFixed(0)}",
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                color: Colors.white,
                child: ElevatedButton(
                  onPressed:
                  (availableQty <= 0 || isPlacingOrder)
                      ? null
                      : () {
                    final unitPrice = price;
                    final total = price * orderQty;
                    final delivery =
                        deliveryCost ?? 50.0;
                    final grand =
                        total + delivery;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PaymentSelectionScreen(
                              productId:
                              widget.productId,
                              productData:
                              widget.data,
                              orderQty: orderQty,
                              productTotal:
                              total,
                              deliveryCost:
                              delivery,
                              unitPrice:
                              unitPrice,
                              placeOrderCallback:
                                  ({
                                required buyerId,
                                required unitPrice,
                                required quantity,
                                required totalProductPrice,
                                required grandTotal,
                                required paymentMode,
                                required paymentRef,
                              }) async {
                                setState(() =>
                                isPlacingOrder =
                                true);

                                try {
                                  return await placeOrderFromPayment(
                                    buyerId:
                                    buyerId,
                                    unitPrice:
                                    unitPrice,
                                    quantity:
                                    quantity,
                                    totalProductPrice:
                                    totalProductPrice,
                                    grandTotal:
                                    grandTotal,
                                    paymentMode:
                                    paymentMode,
                                    paymentRef:
                                    paymentRef,
                                  );
                                } finally {
                                  if (mounted)
                                    setState(() => isPlacingOrder = false);
                                }
                              },
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.orange,
                    padding:
                    const EdgeInsets.symmetric(
                        vertical: 14),
                  ),
                  child: isPlacingOrder
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child:
                    CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                        Colors.white),
                  )
                      : const Text("Buy Now",
                      style:
                      TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
