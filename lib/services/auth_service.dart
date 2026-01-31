import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _premiumApiUrl =
      'https://7esentvbackend.vercel.app/api/mobile/premium';

  // Auth State Stream
  Stream<User?> get user => _auth.authStateChanges();

  // Current User
  User? get currentUser => _auth.currentUser;

  // Sign Up
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Initialize User Data in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'name': displayName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'isSubscribed': false, // Default to false
        'platform': defaultTargetPlatform.toString(),
      });
      // Update Firebase User Display Name
      await result.user!.updateDisplayName(displayName);
      return result;
    } catch (e) {
      debugPrint("SignUp Error: $e");
      rethrow;
    }
  }

  // Sign In
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint("SignIn Error: $e");
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Check Subscription Status
  Future<bool> checkSubscription() async {
    User? user = _auth.currentUser;
    if (user == null) {
      print("DEBUG CHECK SUBSCRIPTION: User is NULL (Not Logged In)");
      return false;
    }

    try {
      print("DEBUG CHECK SUBSCRIPTION: Checking for User UID: ${user.uid}");
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        print(
            "DEBUG CHECK SUBSCRIPTION: IsSubscribed=${data['isSubscribed']} Plan=${data['subscriptionPlan']}");
        return data['isSubscribed'] == true;
      }
      print("DEBUG CHECK SUBSCRIPTION: User Document NOT FOUND in Firestore.");
      return false;
    } catch (e) {
      debugPrint("Subscription Check Error: $e");
      return false;
    }
  }

  // Get User Data (Plan, Expiry, etc.)
  Future<Map<String, dynamic>?> getUserData() async {
    User? user = _auth.currentUser;
    if (user == null) return null;

    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("Get User Data Error: $e");
      return null;
    }
  }

  /// Unlock premium content by calling the backend API.
  /// Returns the full content data with stream URLs if successful, null otherwise.
  ///
  /// [type] can be: "channel", "match", "goal", "news"
  /// [id] is the content ID from the API.
  Future<Map<String, dynamic>?> unlockPremiumContent({
    required String type,
    required int id,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) {
      debugPrint("unlockPremiumContent: No user logged in");
      return null;
    }

    try {
      // Get Firebase ID token for authentication
      final token = await user.getIdToken();
      if (token == null) {
        debugPrint("unlockPremiumContent: Could not get ID token");
        return null;
      }

      final response = await http.post(
        Uri.parse(_premiumApiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': type,
          'id': id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint("unlockPremiumContent: Success for $type/$id");
          return data['data'] as Map<String, dynamic>?;
        } else {
          debugPrint("unlockPremiumContent: ${data['error']}");
          return null;
        }
      } else {
        debugPrint(
            "unlockPremiumContent: HTTP ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("unlockPremiumContent Error: $e");
      return null;
    }
  }
}
