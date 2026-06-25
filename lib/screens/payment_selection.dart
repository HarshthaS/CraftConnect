// lib/screens/payment_selection.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

typedef PlaceOrderCallback = Future<String> Function({
required String buyerId,
required double unitPrice,
required int quantity,
required double totalProductPrice,
required double grandTotal,
required String paymentMode,
required String paymentRef,
});

class PaymentSelectionScreen extends StatelessWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final int orderQty;
  final double productTotal;
  final double deliveryCost;
  final double unitPrice;
  final PlaceOrderCallback placeOrderCallback;

  const PaymentSelectionScreen({
    super.key,
    required this.productId,
    required this.productData,
    required this.orderQty,
    required this.productTotal,
    required this.deliveryCost,
    required this.unitPrice,
    required this.placeOrderCallback,
  });

  @override
  Widget build(BuildContext context) {
    final double grandTotal = productTotal + deliveryCost;
    final bool codAllowed = grandTotal <= 5000;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Payment Method"),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          _orderSummaryCard(grandTotal),

          Expanded(
            child: ListView(
              children: [
                _sectionHeader("Recommended"),

                _paymentTile(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: "UPI",
                  subtitle: "Google Pay, PhonePe, Paytm",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UpiPaymentScreen(
                          amount: grandTotal,
                          orderQty: orderQty,
                          productTotal: productTotal,
                          unitPrice: unitPrice,
                          placeOrderCallback: placeOrderCallback,
                        ),
                      ),
                    );
                  },
                ),

                _sectionHeader("Cards"),

                _paymentTile(
                  context,
                  icon: Icons.credit_card,
                  title: "Debit / Credit Card",
                  subtitle: "Visa, MasterCard, RuPay",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CardPaymentScreen(
                          amount: grandTotal,
                          orderQty: orderQty,
                          productTotal: productTotal,
                          unitPrice: unitPrice,
                          placeOrderCallback: placeOrderCallback,
                        ),
                      ),
                    );
                  },
                ),

                _sectionHeader("Other Options"),

                _codTile(
                  context,
                  codAllowed: codAllowed,
                  grandTotal: grandTotal,
                  orderQty: orderQty,
                  productTotal: productTotal,
                  unitPrice: unitPrice,
                  placeOrderCallback: placeOrderCallback,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderSummaryCard(double grandTotal) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Order Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(productData["name"] ?? "Product"),
          Text("Quantity: $orderQty"),
          Text("Items Total: ₹${productTotal.toStringAsFixed(0)}"),
          Text("Delivery: ₹${deliveryCost.toStringAsFixed(0)}"),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("To Pay", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(
                "₹${grandTotal.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }

  Widget _paymentTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.1),
          child: Icon(icon, color: Colors.orange),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }

  Widget _codTile(
      BuildContext context, {
        required bool codAllowed,
        required double grandTotal,
        required int orderQty,
        required double productTotal,
        required double unitPrice,
        required PlaceOrderCallback placeOrderCallback,
      }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        enabled: codAllowed,
        leading: CircleAvatar(
          backgroundColor: codAllowed ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
          child: Icon(Icons.local_shipping_outlined, color: codAllowed ? Colors.orange : Colors.grey),
        ),
        title: const Text("Cash on Delivery"),
        subtitle: codAllowed
            ? const Text("Pay when item arrives")
            : const Text(" ", style: TextStyle(color: Colors.red)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: codAllowed
            ? () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final paymentRef = "COD-${DateTime.now().millisecondsSinceEpoch}";

          final invoiceUrl = await placeOrderCallback(
            buyerId: user.uid,
            unitPrice: unitPrice,
            quantity: orderQty,
            totalProductPrice: productTotal,
            grandTotal: grandTotal,
            paymentMode: "Cash on Delivery",
            paymentRef: paymentRef,
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CodOrderPlacedScreen(invoiceUrl: invoiceUrl),
            ),
          );
        }
            : null,
      ),
    );
  }
}

class CodOrderPlacedScreen extends StatelessWidget {
  final String invoiceUrl;

  const CodOrderPlacedScreen({super.key, required this.invoiceUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Order Placed"), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.check_circle, size: 70, color: Colors.green),
            const SizedBox(height: 16),
            const Text("Your Order Has Been Placed", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/buyer_dashboard',
                        (route) => false,
                  );
                  Navigator.pushNamed(context, '/buyer_orders');
                },
                child: const Text("View My Orders", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class UpiPaymentScreen extends StatefulWidget {
  final double amount;
  final int orderQty;
  final double productTotal;
  final double unitPrice;
  final PlaceOrderCallback placeOrderCallback;

  const UpiPaymentScreen({
    super.key,
    required this.amount,
    required this.orderQty,
    required this.productTotal,
    required this.unitPrice,
    required this.placeOrderCallback,
  });

  @override
  State<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends State<UpiPaymentScreen> {
  String _selectedApp = "Google Pay";
  final TextEditingController _upiIdController = TextEditingController(text: "yourname@upi");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("UPI Payment"), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select UPI App", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            RadioListTile(
              value: "Google Pay",
              groupValue: _selectedApp,
              title: const Text("Google Pay"),
              onChanged: (v) => setState(() => _selectedApp = v!),
            ),
            RadioListTile(
              value: "PhonePe",
              groupValue: _selectedApp,
              title: const Text("PhonePe"),
              onChanged: (v) => setState(() => _selectedApp = v!),
            ),
            RadioListTile(
              value: "Paytm",
              groupValue: _selectedApp,
              title: const Text("Paytm"),
              onChanged: (v) => setState(() => _selectedApp = v!),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _upiIdController,
              decoration: const InputDecoration(labelText: "UPI ID", border: OutlineInputBorder()),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  final ref = "UPI-${_selectedApp.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}";
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OtpVerificationScreen(
                        amount: widget.amount,
                        paymentMode: "UPI ($_selectedApp)",
                        paymentRef: ref,
                        orderQty: widget.orderQty,
                        productTotal: widget.productTotal,
                        unitPrice: widget.unitPrice,
                        placeOrderCallback: widget.placeOrderCallback,
                      ),
                    ),
                  );
                },
                child: Text("Pay ₹${widget.amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class CardPaymentScreen extends StatefulWidget {
  final double amount;
  final int orderQty;
  final double productTotal;
  final double unitPrice;
  final PlaceOrderCallback placeOrderCallback;

  const CardPaymentScreen({
    super.key,
    required this.amount,
    required this.orderQty,
    required this.productTotal,
    required this.unitPrice,
    required this.placeOrderCallback,
  });

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final TextEditingController _cardNumber = TextEditingController();
  final TextEditingController _nameOnCard = TextEditingController();
  final TextEditingController _expiry = TextEditingController();
  final TextEditingController _cvv = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Card Payment"), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _cardNumber,
              keyboardType: TextInputType.number,
              decoration: _input("Card Number", "xxxx xxxx xxxx xxxx"),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _nameOnCard,
              decoration: _input("Name on Card", ""),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: TextField(controller: _expiry, decoration: _input("MM/YY", ""))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _cvv, obscureText: true, decoration: _input("CVV", ""))),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  final ref = "CARD-${DateTime.now().millisecondsSinceEpoch}";
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OtpVerificationScreen(
                        amount: widget.amount,
                        paymentMode: "Card",
                        paymentRef: ref,
                        orderQty: widget.orderQty,
                        productTotal: widget.productTotal,
                        unitPrice: widget.unitPrice,
                        placeOrderCallback: widget.placeOrderCallback,
                      ),
                    ),
                  );
                },
                child: Text("Pay ₹${widget.amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label, String hint) {
    return InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());
  }
}

class OtpVerificationScreen extends StatefulWidget {
  final double amount;
  final String paymentMode;
  final String paymentRef;
  final int orderQty;
  final double productTotal;
  final double unitPrice;
  final PlaceOrderCallback placeOrderCallback;

  const OtpVerificationScreen({
    super.key,
    required this.amount,
    required this.paymentMode,
    required this.paymentRef,
    required this.orderQty,
    required this.productTotal,
    required this.unitPrice,
    required this.placeOrderCallback,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otp = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP"), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Enter OTP to complete payment."),
            const SizedBox(height: 12),

            TextField(
              controller: _otp,
              maxLength: 6,
              decoration: const InputDecoration(labelText: "OTP", border: OutlineInputBorder()),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentProcessingScreen(
                        amount: widget.amount,
                        paymentMode: widget.paymentMode,
                        paymentRef: widget.paymentRef,
                        orderQty: widget.orderQty,
                        productTotal: widget.productTotal,
                        unitPrice: widget.unitPrice,
                        placeOrderCallback: widget.placeOrderCallback,
                      ),
                    ),
                  );
                },
                child: const Text("Submit", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class PaymentProcessingScreen extends StatefulWidget {
  final double amount;
  final String paymentMode;
  final String paymentRef;
  final int orderQty;
  final double productTotal;
  final double unitPrice;
  final PlaceOrderCallback placeOrderCallback;

  const PaymentProcessingScreen({
    super.key,
    required this.amount,
    required this.paymentMode,
    required this.paymentRef,
    required this.orderQty,
    required this.productTotal,
    required this.unitPrice,
    required this.placeOrderCallback,
  });

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final invoiceUrl = await widget.placeOrderCallback(
      buyerId: user.uid,
      unitPrice: widget.unitPrice,
      quantity: widget.orderQty,
      totalProductPrice: widget.productTotal,
      grandTotal: widget.amount,
      paymentMode: widget.paymentMode,
      paymentRef: widget.paymentRef,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(
          success: true,
          amount: widget.amount,
          paymentMode: widget.paymentMode,
          paymentRef: widget.paymentRef,
          invoiceUrl: invoiceUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Processing payment..."),
          ],
        ),
      ),
    );
  }
}

class PaymentResultScreen extends StatelessWidget {
  final bool success;
  final double amount;
  final String paymentMode;
  final String paymentRef;
  final String invoiceUrl;

  const PaymentResultScreen({
    super.key,
    required this.success,
    required this.amount,
    required this.paymentMode,
    required this.paymentRef,
    required this.invoiceUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Status"), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(success ? Icons.check_circle : Icons.error,
                size: 70, color: success ? Colors.green : Colors.red),
            const SizedBox(height: 16),

            Text(
              success ? "Payment Successful" : "Payment Failed",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: success ? Colors.green : Colors.red),
            ),

            const SizedBox(height: 10),

            Text("Amount: ₹${amount.toStringAsFixed(0)}"),
            Text("Mode: $paymentMode"),
            Text("Ref: $paymentRef"),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  // FIXED BACK BUTTON LOGIC
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/buyer_dashboard',
                        (route) => false,
                  );

                  Navigator.pushNamed(context, '/buyer_orders');
                },
                child: const Text("View My Orders", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
