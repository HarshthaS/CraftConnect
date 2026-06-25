import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> _incrementCounter(String role) async {
    String docId = role == "artisan" ? "artisan_counter" : "buyer_counter";
    DocumentReference ref =
    _firestore.collection('system_counters').doc(docId);

    return _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(ref);

      if (!snapshot.exists) {
        transaction.set(ref, {"value": 1});
        return 1;
      }

      int newValue = (snapshot["value"] ?? 0) + 1;
      transaction.update(ref, {"value": newValue});
      return newValue;
    });
  }

  Future<String> _generateOrderedId(String role) async {
    int num = await _incrementCounter(role);
    String formatted = num.toString().padLeft(3, '0');
    return role == "artisan" ? "ART$formatted" : "BUY$formatted";
  }

  Future<String?> signUpWithDetails({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {

      UserCredential userCred =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCred.user!.uid;

      userData["email"] = email;
      userData["uid"] = uid;

      if (userData["role"] == "artisan") {
        userData["artisan_id"] = await _generateOrderedId("artisan");
      } else {
        userData["buyer_id"] = await _generateOrderedId("buyer");
      }

      userData["artisan_uid"] = uid;
      userData["buyer_uid"] = uid;

      await _firestore.collection("users").doc(uid).set(userData);

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unknown error occurred.";
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } catch (e) {
      return "Login failed.";
    }
  }

  Future<String> getUserRolePath() async {
    User? user = _auth.currentUser;
    if (user == null) return "/login";

    DocumentSnapshot doc =
    await _firestore.collection("users").doc(user.uid).get();

    if (!doc.exists) return "/login";

    String role = doc["role"];
    return role == "artisan" ? "/artisan_dashboard" : "/buyer_dashboard";
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
