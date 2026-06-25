import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArtisanDashboard extends StatelessWidget {
  const ArtisanDashboard({super.key});

  Future<bool> _onBackPressed(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Exit App?"),
        content: const Text("Are you sure you want to exit??"),
        actions: [
          TextButton(
            child: const Text("No"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: const Text("Yes"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return WillPopScope(
      onWillPop: () => _onBackPressed(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F3),
        appBar: AppBar(
          title: const Text('Artisan Dashboard'),
          backgroundColor: Colors.orange,
          elevation: 2,
          actions: [
            IconButton(
              tooltip: 'Profile',
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              icon: const Icon(Icons.person_outline),
            ),
          ],
        ),

        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where("artisan_uid", isEqualTo: uid)
              .snapshots(),
          builder: (context, snap) {
            int totalOrders = 0;
            int pendingOrders = 0;
            int deliveredOrders = 0;

            if (snap.hasData) {
              final docs = snap.data!.docs;

              totalOrders = docs.length;

              for (var d in docs) {
                final data = d.data() as Map<String, dynamic>;
                final status = (data["order_status"] ?? "").toString().toLowerCase();
                if (status == "delivered") {
                  deliveredOrders++;
                } else if (status == "placed" ||
                    status == "accepted" ||
                    status == "confirmed" ||
                    status == "packed" ||
                    status == "shipped") {
                  pendingOrders++;
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome, Artisan 👋",
                      style:
                      TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Create, manage & track your handmade products",
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 22),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _statTile("Total Orders", totalOrders.toString()),
                          const VerticalDivider(),
                          _statTile("Pending", pendingOrders.toString()),
                          const VerticalDivider(),
                          _statTile("Delivered", deliveredOrders.toString()),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 1,
                        childAspectRatio: 4.8,
                        mainAxisSpacing: 16,
                        children: [
                          _actionCard(
                            context,
                            icon: Icons.add_circle_outline,
                            title: "Upload Product (Manual)",
                            subtitle: "Add product details & image",
                            onTap: () => Navigator.pushNamed(
                                context, '/upload_product_manual'),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.mic,
                            title: "Upload Using Voice",
                            subtitle: "Speak product details",
                            onTap: () => Navigator.pushNamed(
                                context, '/upload_product_voice'),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.inventory_2_outlined,
                            title: "My Products",
                            subtitle: "Manage your uploaded items",
                            onTap: () =>
                                Navigator.pushNamed(context, '/my_products'),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.list_alt,
                            title: "Orders Received",
                            subtitle: "Accept / pack / shipped / delivered",
                            onTap: () =>
                                Navigator.pushNamed(context, '/artisan_orders'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: Colors.orange, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
