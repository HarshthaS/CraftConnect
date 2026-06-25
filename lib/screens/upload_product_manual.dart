// lib/screens/upload_product_manual.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadProductManual extends StatefulWidget {
  const UploadProductManual({super.key});
  @override
  State<UploadProductManual> createState() => _UploadProductManualState();
}

class _UploadProductManualState extends State<UploadProductManual> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  final picker = ImagePicker();
  File? selectedImage;
  bool isLoading = false;

  String material = "Wood";
  final supabase = Supabase.instance.client;

  Future<void> pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  Future<Map<String, String>?> uploadImageIfAvailable() async {
    if (selectedImage == null) return null;

    try {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final fileBytes = await selectedImage!.readAsBytes();

      // ✅ Upload image
      final response = await supabase.storage
          .from('product_images')
          .uploadBinary(
        fileName,
        fileBytes,
        fileOptions: const FileOptions(contentType: "image/jpeg"),
      );

      print("UPLOAD RESPONSE: $response");

      // ✅ Get public URL properly
      final publicUrlData =
      supabase.storage.from('product_images').getPublicUrl(fileName);

      final imageUrl = publicUrlData;

      print("IMAGE URL: $imageUrl");

      return {
        "url": imageUrl,
        "path": fileName,
      };
    } catch (e) {
      print("UPLOAD ERROR: $e");
      return null;
    }
  }

  Future<void> uploadProduct() async {
    if (nameController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty ||
        quantityController.text.trim().isEmpty ||
        selectedImage == null) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields and product image are required")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final artisanDoc =
      await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      final artisanLat = artisanDoc.data()?["lat"];
      final artisanLng = artisanDoc.data()?["lng"];
      final artisanName = artisanDoc.data()?["name"] ?? "";

      Map<String, String>? uploadedImage = await uploadImageIfAvailable();

      final productRef =
      await FirebaseFirestore.instance.collection("products").add({
        "name": nameController.text.trim(),
        "price": double.tryParse(priceController.text.trim()) ?? 0.0,
        "quantity": int.tryParse(quantityController.text.trim()) ?? 0,
        "material": material,

        "image_url": uploadedImage?["url"] ?? "",
        "image_path": uploadedImage?["path"] ?? "",

        "in_stock": true,
        "artisan_uid": user.uid,
        "artisan_name": artisanName,
        "artisan_lat": artisanLat,
        "artisan_lng": artisanLng,

        "timestamp": FieldValue.serverTimestamp(),
      });

      await productRef.update({"product_id": productRef.id});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product Added Successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  Widget imagePickerOptions() {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 180,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text("Choose from Gallery"),
            onTap: () {
              pickImage(ImageSource.gallery);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Take a Photo"),
            onTap: () {
              pickImage(ImageSource.camera);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Product")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => imagePickerOptions(),
                );
              },
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: selectedImage == null
                    ? const Icon(Icons.camera_alt, size: 50)
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(selectedImage!, fit: BoxFit.cover),
                ),
              ),
            ),

            if (selectedImage != null)
              TextButton.icon(
                onPressed: () => setState(() => selectedImage = null),
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text("Remove Image",
                    style: TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 20),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Product Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Price",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Quantity",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Material",
              ),
              value: material,
              items: ["Wood", "Clay", "Glass", "Metal", "Textile"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => material = v!),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : uploadProduct,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Upload Product"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
