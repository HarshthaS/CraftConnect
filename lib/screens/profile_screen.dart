// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/location_service.dart';
import '../widgets/responsive_layout.dart';
import 'edit_profile_screen.dart';
import 'change_password.dart';
import 'location_map.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = true;
  bool updatingLocation = false;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(u.uid).get();

    setState(() {
      userData = doc.data();
      loading = false;
    });
  }

  Future<void> updateLocation() async {
    setState(() => updatingLocation = true);

    final pos = await LocationService.getCurrentPosition();

    setState(() => updatingLocation = false);

    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text("Couldn't fetch location. Check permissions & location ON."),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
      "lat": pos.latitude,
      "lng": pos.longitude,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Location updated successfully.")),
    );

    loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = userData?['name'] ?? "User";
    final email = userData?['email'] ?? "";
    final mobile = userData?['mobile'] ?? "Not set";
    final address = userData?['address'] ?? "Not set";
    final profileUrl = userData?['profile_image_url'] ?? "";
    final role = userData?['role'] ?? "";

    final lat = userData?['lat'];
    final lng = userData?['lng'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
      ),

      body: ResponsiveLayout(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 58,
                        backgroundColor: Colors.orange.shade100,
                        backgroundImage:
                        profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                        child: profileUrl.isEmpty
                            ? const Icon(Icons.person,
                            size: 60, color: Colors.white)
                            : null,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _sectionCard([
                  _infoTile("Email", email, Icons.email_outlined),
                  _infoTile("Mobile", mobile, Icons.phone),
                  _infoTile("Address", address, Icons.home),
                  _infoTile(
                    "Location",
                    lat != null
                        ? "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}"
                        : "Not set",
                    Icons.location_on_outlined,
                  ),
                ]),

                const SizedBox(height: 20),

                _orangeButton(
                  label: updatingLocation ? "Updating..." : "Update Current Location",
                  icon: Icons.my_location,
                  color: Colors.orange,
                  disabled: updatingLocation,
                  onPressed: updatingLocation ? null : updateLocation,
                ),

                const SizedBox(height: 12),

                _orangeButton(
                  label: "View on Map",
                  icon: Icons.map_outlined,
                  color: Colors.orange,
                  disabled: lat == null,
                  onPressed: lat == null
                      ? null
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LocationMapScreen(lat: lat, lng: lng, name: name),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                _orangeButton(
                  label: "Edit Profile",
                  icon: Icons.edit,
                  color: Colors.orangeAccent,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ).then((_) => loadProfile());
                  },
                ),

                const SizedBox(height: 12),

                _orangeButton(
                  label: "Change Password",
                  icon: Icons.lock,
                  color: Colors.deepOrange,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),

                const Spacer(),

                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, "/login");
                  },
                  child: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _infoTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                    const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _orangeButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
    bool disabled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : onPressed,
        icon: Icon(icon, color: Colors.white),
        label:
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.orange.shade200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
