// lib/screens/signup_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  double? latitude;
  double? longitude;

  String selectedRole = "buyer";
  bool _isLoading = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> checkIfNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please connect to the Internet"), backgroundColor: Colors.red),
      );
      return false;
    }
  }


  Future<void> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
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
              )
            ],
          ),
        );
      },
    );
  }


  Future<String?> _uploadProfileImageIfAny() async {
    if (_profileImage == null) return null;

    final fileName = "PROFILE_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final bytes = await _profileImage!.readAsBytes();

    await _supabase.storage
        .from("profile_pictures")
        .uploadBinary(fileName, bytes,
        fileOptions: const FileOptions(contentType: "image/jpeg"));

    return _supabase.storage.from("profile_pictures").getPublicUrl(fileName);
  }


  Future<void> _convertAddressToLatLng() async {
    String addr = _addressController.text.trim();
    if (addr.isEmpty) return;

    try {
      List<Location> loc = await locationFromAddress(addr);
      if (loc.isNotEmpty) {
        latitude = loc.first.latitude;
        longitude = loc.first.longitude;
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to convert address"), backgroundColor: Colors.red),
      );
    }
  }


  Future<void> _getCurrentLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enable GPS"), backgroundColor: Colors.red),
      );
      return;
    }

    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission denied")),
      );
      return;
    }

    Position pos = await Geolocator.getCurrentPosition();
    latitude = pos.latitude;
    longitude = pos.longitude;

    List<Placemark> mark = await placemarkFromCoordinates(latitude!, longitude!);
    Placemark place = mark.first;

    setState(() {
      _addressController.text =
      "${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
    });
  }


  void _signUp() async {
    if (!await checkIfNetworkAvailable()) return;

    if (latitude == null || longitude == null) {
      await _convertAddressToLatLng();
    }

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid address or use GPS")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final profileUrl = await _uploadProfileImageIfAny();

    Map<String, dynamic> userData = {
      "name": _nameController.text.trim(),
      "mobile": _mobileController.text.trim(),
      "role": selectedRole,
      "address": _addressController.text.trim(),
      "lat": latitude,
      "lng": longitude,
      "profile_image_url": profileUrl ?? "",
    };

    String? error = await _authService.signUpWithDetails(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      userData: userData,
    );

    if (error == null) {
      Navigator.pushReplacementNamed(context, "/login");
    } else {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EC),
      appBar: AppBar(
        title: const Text("Sign Up - CraftConnect"),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("Create Your Account",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: showImagePickerSheet,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.orange.shade100,
                    backgroundImage:
                    _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null
                        ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const Text("Add profile photo (optional)",
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: "Select Role",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "buyer", child: Text("Buyer")),
                DropdownMenuItem(value: "artisan", child: Text("Artisan")),
              ],
              onChanged: (v) => setState(() => selectedRole = v!),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _mobileController,
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: "Address",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _getCurrentLocation,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Icon(Icons.my_location, color: Colors.white),
                )
              ],
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Sign Up",
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),

            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, "/login"),
              child: const Text("Already have an account? Login",
                  style: TextStyle(color: Colors.orange)),
            )
          ],
        ),
      ),
    );
  }
}
