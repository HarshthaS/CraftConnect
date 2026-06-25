import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  Future<List<QueryDocumentSnapshot>> getRecommendations() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    List viewed = userDoc.data()?["viewed_materials"] ?? [];
    List purchased = userDoc.data()?["purchased_materials"] ?? [];

    final products =
    await FirebaseFirestore.instance.collection("products").get();

    return products.docs.where((doc) {
      final material = doc["material"].toString().toLowerCase();
      return viewed.contains(material) || purchased.contains(material);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recommended For You"),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder(
        future: getRecommendations(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!;

          if (products.isEmpty) {
            return const Center(
              child: Text("No recommendations yet"),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, i) {
              final data = products[i].data() as Map<String, dynamic>;

              return InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/product_details',
                    arguments: {
                      'productId': products[i].id,
                      'data': data,
                    },
                  );
                },
                child: Card(
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.network(
                          data["image_url"],
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data["name"],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text("₹${data["price"]}"),
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