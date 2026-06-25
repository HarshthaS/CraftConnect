// lib/screens/edit_product.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> data;

  const EditProductScreen({
    super.key,
    required this.productId,
    required this.data,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController quantityController;
  late String material;

  File? newImage;
  final picker = ImagePicker();
  bool isSaving = false;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.data["name"] ?? "");
    priceController = TextEditingController(text: widget.data["price"].toString());
    quantityController = TextEditingController(text: widget.data["quantity"].toString());
    material = widget.data["material"] ?? "Wood";
  }


  Future<void> pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() => newImage = File(picked.path));
    }
  }

  Future<void> deleteOldImage() async {
    String? oldPath = widget.data["image_path"];
    if (oldPath == null || oldPath.isEmpty) return;

    try {
      await supabase.storage.from("product_images").remove([oldPath]);
    } catch (e) {
      debugPrint("Old image delete failed: $e");
    }
  }

  Future<Map<String, String>?> uploadNewImage() async {
    if (newImage == null) return null;

    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    final fileBytes = await newImage!.readAsBytes();

    await supabase.storage
        .from('product_images')
        .uploadBinary(fileName, fileBytes,
        fileOptions: const FileOptions(contentType: "image/jpeg"));

    final publicUrl =
    supabase.storage.from('product_images').getPublicUrl(fileName);

    return {"url": publicUrl, "path": fileName};
  }

  Future<void> saveProduct() async {
    setState(() => isSaving = true);

    String updatedUrl = widget.data["image_url"];
    String updatedPath = widget.data["image_path"];


    if (newImage != null) {
      await deleteOldImage();
      final uploaded = await uploadNewImage();
      updatedUrl = uploaded?["url"] ?? updatedUrl;
      updatedPath = uploaded?["path"] ?? updatedPath;
    }

    final newQty = int.tryParse(quantityController.text.trim()) ?? 0;

    await FirebaseFirestore.instance
        .collection("products")
        .doc(widget.productId)
        .update({
      "name": nameController.text.trim(),
      "price": double.tryParse(priceController.text.trim()) ?? 0,
      "quantity": newQty,
      "material": material,
      "image_url": updatedUrl,
      "image_path": updatedPath,


      "in_stock": newQty > 0,
    });

    setState(() => isSaving = false);
    Navigator.pop(context);
  }

  Widget imagePickerSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 170,
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
    final currentImage = widget.data["image_url"];

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Product")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // IMAGE SECTION
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => imagePickerSheet(),
                );
              },
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: newImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(newImage!, fit: BoxFit.cover),
                )
                    : (currentImage != null && currentImage != "")
                    ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(currentImage,
                        fit: BoxFit.cover))
                    : const Icon(Icons.camera_alt, size: 50),
              ),
            ),

            if (newImage != null)
              TextButton.icon(
                onPressed: () => setState(() => newImage = null),
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text("Remove New Image",
                    style: TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 20),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Product Name",
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Price",
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Quantity",
              ),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField(
              value: material,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Material",
              ),
              items: ["Wood", "Clay", "Glass", "Metal", "Textile"]
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => material = v!),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveProduct,
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes"),
              ),
            ),
          ],
        ),
        ),
    );
  }
}
