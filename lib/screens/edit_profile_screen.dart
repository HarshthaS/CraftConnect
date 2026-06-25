import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool loading = true;
  bool saving = false;

  Map<String, dynamic>? userData;

  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  File? selectedImage;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (doc.exists) {
      userData = doc.data();
      _nameCtrl.text = userData?['name'] ?? '';
      _mobileCtrl.text = userData?['mobile'] ?? '';
      _addressCtrl.text = userData?['address'] ?? '';
    }

    setState(() => loading = false);
  }

  Future<void> pickImage(ImageSource source) async {
    final picked =
    await ImagePicker().pickImage(source: source, imageQuality: 70);

    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  void showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SizedBox(
          height: 170,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take a Photo"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading:
                const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  "Remove Photo",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => selectedImage = null);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> uploadProfileImage() async {
    if (selectedImage == null) return userData?["profile_image_url"];

    final fileName = "IMG_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final fileBytes = await selectedImage!.readAsBytes();

    await supabase.storage.from("profile_pictures").uploadBinary(
      fileName,
      fileBytes,
      fileOptions: const FileOptions(contentType: "image/jpeg"),
    );

    return supabase.storage
        .from("profile_pictures")
        .getPublicUrl(fileName);
  }

  Future<Map<String, double>?> _getLatLngFromAddress(String address) async {
    if (address.trim().isEmpty) return null;

    const apiKey = "YOUR_GOOGLE_MAPS_API_KEY";

    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/geocode/json"
          "?address=${Uri.encodeComponent(address)}"
          "&key=$apiKey",
    );

    final res = await http.get(url);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data["status"] != "OK") return null;

    final location = data["results"][0]["geometry"]["location"];

    return {
      "lat": location["lat"],
      "lng": location["lng"],
    };
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => saving = true);

    try {
      final imageUrl = await uploadProfileImage();

      final address = _addressCtrl.text.trim();
      final location = await _getLatLngFromAddress(address);

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        "name": _nameCtrl.text.trim(),
        "mobile": _mobileCtrl.text.trim(),
        "address": address,
        "latitude": location?["lat"],
        "longitude": location?["lng"],
        "profile_image_url": imageUrl ?? "",
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update profile: $e")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profileUrl = userData?["profile_image_url"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: showImagePickerSheet,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.orange.shade200,
                backgroundImage: selectedImage != null
                    ? FileImage(selectedImage!)
                    : (profileUrl != null && profileUrl.isNotEmpty)
                    ? NetworkImage(profileUrl)
                    : null,
                child: (selectedImage == null &&
                    (profileUrl == null || profileUrl.isEmpty))
                    ? const Icon(Icons.camera_alt, size: 40)
                    : null,
              ),
            ),

            const SizedBox(height: 25),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Mobile",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Address",
                hintText: "Enter full address",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Save Changes",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
