import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_product.dart';

class MyProductsScreen extends StatelessWidget {
  const MyProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final supabase = Supabase.instance.client;

    Future<void> deleteProduct(String docId, String imagePath) async {
      await FirebaseFirestore.instance.collection("products").doc(docId).delete();

      if (imagePath.isNotEmpty) {
        await supabase.storage.from("product_images").remove([imagePath]);
      }
    }

    Future<void> toggleStock(
        String docId,
        bool currentStatus,
        int currentQty,
        ) async {
      final prodRef =
      FirebaseFirestore.instance.collection("products").doc(docId);

      if (currentStatus == true) {
        await prodRef.update({
          "in_stock": false,
          "quantity": 0,
        });
      } else {
        await prodRef.update({
          "in_stock": true,
        });
      }
    }


    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EC),
      appBar: AppBar(
        title: const Text("My Products"),
        backgroundColor: Colors.orange,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("products")
            .where("artisan_uid", isEqualTo: uid)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No products uploaded yet.", style: TextStyle(fontSize: 16)),
            );
          }

          final products = snapshot.data!.docs;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final doc = products[index];
              final data = doc.data() as Map<String, dynamic>;

              final imageUrl = data["image_url"] ?? "";
              final imagePath = data["image_path"] ?? "";
              final inStock = data["in_stock"] ?? true;

              return Card(
                margin: const EdgeInsets.all(12),
                elevation: 4,
                child: Row(
                  children: [
                    Container(
                      height: 90,
                      width: 90,
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.shade300,
                      ),
                      child: imageUrl.isEmpty
                          ? const Icon(Icons.image, size: 40, color: Colors.grey)
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (data["name"] ?? "").toString(),
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text("₹${data['price']} • Qty: ${data['quantity']}"),
                            Text(
                              inStock ? "In Stock" : "Out of Stock",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: inStock ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditProductScreen(
                                  productId: doc.id,
                                  data: data,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            inStock ? Icons.visibility : Icons.visibility_off,
                            color: Colors.orange,
                          ),
                          onPressed: () =>
                              toggleStock(doc.id, inStock, data["quantity"] ?? 0),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteProduct(doc.id, imagePath),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

