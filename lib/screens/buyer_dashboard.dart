import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'product_details.dart';
import 'package:firebase_auth/firebase_auth.dart';


class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String selectedPriceRange = "All";
  bool isListening = false;
  bool showRecommendations = false;

  late stt.SpeechToText _speech;

  bool cameFromPayment = false;

  final List<String> priceRanges = [
    "All",
    "< ₹500",
    "₹500 - ₹1000",
    "₹1000 - ₹5000",
    "> ₹5000"
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    Future.delayed(Duration.zero, () {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args["fromPayment"] == true) {
        setState(() {
          cameFromPayment = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Future<List<QueryDocumentSnapshot>> _getRecommendedProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final viewed =
    List<String>.from(userDoc.data()?["viewed_materials"] ?? []);
    final purchased =
    List<String>.from(userDoc.data()?["purchased_materials"] ?? []);

    if (viewed.isEmpty && purchased.isEmpty) return [];

    final productsSnap =
    await FirebaseFirestore.instance.collection("products").get();

    final products = productsSnap.docs;

    final scored = <QueryDocumentSnapshot, int>{};

    for (final p in products) {
      final data = p.data() as Map<String, dynamic>;
      final material =
      (data["material"] ?? "").toString().toLowerCase();

      int score = 0;
      if (viewed.contains(material)) score += 1;
      if (purchased.contains(material)) score += 3;

      if (score > 0 && (data["quantity"] ?? 0) > 0) {
        scored[p] = score;
      }
    }

    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key).toList();
  }

  Future<bool> _onWillPop() async {
    if (cameFromPayment) {
      return false;
    }

    return await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Exit App?"),
        content: const Text("Are you sure you want to exit CraftConnect?"),
        actions: [
          TextButton(
            child: const Text("No"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: const Text("Yes"),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ??
        false;
  }

  bool _priceInRange(double price, String range) {
    switch (range) {
      case "< ₹500":
        return price < 500;
      case "₹500 - ₹1000":
        return price >= 500 && price <= 1000;
      case "₹1000 - ₹5000":
        return price > 1000 && price <= 5000;
      case "> ₹5000":
        return price > 5000;
      default:
        return true;
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => isListening = false);
        }
      },
      onError: (error) => setState(() => isListening = false),
    );

    if (available) {
      setState(() => isListening = true);

      _speech.listen(
        onResult: (result) {
          final recognized = result.recognizedWords;
          _searchController.text = recognized;
          setState(() {
            searchQuery = recognized.toLowerCase().trim();
          });
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => isListening = false);
  }

  double? _tryParseQueryPrice(String q) {
    final cleaned = q.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;

    try {
      return double.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EC),

        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: const Text(
            "CraftConnect – Buyer",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
              onPressed: () => Navigator.pushNamed(context, "/buyer_orders"),
            ),
            IconButton(
              icon: const Icon(Icons.recommend),
              tooltip: "Recommendations",
              onPressed: () {
                Navigator.pushNamed(context, "/recommendations");
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.white),
              onPressed: () => Navigator.pushNamed(context, "/profile"),
            ),
          ],
        ),

        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() => searchQuery = val.toLowerCase().trim());
                        },
                        decoration: const InputDecoration(
                          hintText: "Search by product name or price...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.orange,
                      ),
                      onPressed: () {
                        if (isListening) {
                          _stopListening();
                        } else {
                          _startListening();
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton(
                    isExpanded: true,
                    value: selectedPriceRange,
                    items: priceRanges
                        .map(
                          (range) => DropdownMenuItem(
                        value: range,
                        child: Text(range),
                      ),
                    )
                        .toList(),
                    onChanged: (val) => setState(() => selectedPriceRange = val!),
                  ),
                ),
              ),


              const SizedBox(height: 16),


              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("products")
                      .orderBy("timestamp", descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;
                    final queryPrice = _tryParseQueryPrice(searchQuery);

                    final filtered = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;

                      final name = (data["name"] ?? "").toString().toLowerCase();
                      final material = (data["material"] ?? "").toString().toLowerCase();

                      final price = (data["price"] is num)
                          ? (data["price"] as num).toDouble()
                          : double.tryParse(data["price"].toString()) ?? 0;

                      final matchesName = searchQuery.isEmpty || name.contains(searchQuery);
                      final matchesMaterial = searchQuery.isEmpty || material.contains(searchQuery);
                      final matchesPrice = queryPrice != null && price == queryPrice;

                      final matches = matchesName || matchesMaterial || matchesPrice;
                      final priceOk = _priceInRange(price, selectedPriceRange);

                      return matches && priceOk;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text("No matching products"));
                    }

                    return GridView.builder(
                      itemCount: filtered.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: 0.75,
                      ),
                      itemBuilder: (context, i) {
                        final doc = filtered[i];
                        final data = doc.data() as Map<String, dynamic>;

                        final bool outOfStock = (data["quantity"] ?? 0) <= 0;

                        return GestureDetector(
                          onTap: outOfStock
                              ? null
                              : () async {

                            // 🔹 Track viewed material
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final material =
                              (data["material"] ?? "").toString().toLowerCase();

                              if (material.isNotEmpty) {
                                FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(user.uid)
                                    .update({
                                  "viewed_materials": FieldValue.arrayUnion([material])
                                });
                              }
                            }

                            // 🔹 Navigate to product
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailsPage(
                                  productId: doc.id,
                                  data: data,
                                ),
                              ),
                            );
                          },

                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                )
                              ],
                            ),

                            child: Column(
                              children: [

                                Expanded(
                                  flex: 5,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(18)),
                                    child: Stack(
                                      children: [
                                        SizedBox.expand(
                                          child: (data["image_url"] != null &&
                                              data["image_url"] != "")
                                              ? Image.network(
                                            data["image_url"],
                                            fit: BoxFit.cover,
                                          )
                                              : Container(
                                            color: Colors.grey.shade200,
                                            child: const Center(
                                              child: Icon(Icons.image, size: 40),
                                            ),
                                          ),
                                        ),

                                        if (outOfStock)
                                          Container(
                                            color: Colors.black.withOpacity(0.5),
                                            alignment: Alignment.center,
                                            child: const Text(
                                              "OUT OF STOCK",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data["name"] ?? "Product",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        outOfStock
                                            ? Text(
                                          "₹ ${data["price"]}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.lineThrough,
                                            color: Colors.grey.shade500,
                                          ),
                                        )
                                            : Text(
                                          "₹ ${data["price"]}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: outOfStock
                                        ? Container(
                                      padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade300,
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "OUT OF STOCK",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                        : Container(
                                      padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "Buy Now",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
