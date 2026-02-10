import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hesen/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // 🛑 Static flag set by main.dart on successful init
  static bool isFirebaseInitialized = false;

  FirebaseAuth? get _auth {
    if (!isFirebaseInitialized) return null;
    return FirebaseAuth.instance;
  }

  // 🛑 LAZY Firestore: Only create on non-Web platforms to prevent iOS Safari crash
  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore {
    _firestoreInstance ??= FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  static const String _premiumApiUrl =
      'https://7esentvbackend.vercel.app/api/mobile/premium';

  // Auth State Stream
  Stream<User?> get user {
    if (!isFirebaseInitialized) return const Stream.empty();
    return _auth!.authStateChanges();
  }

  // Current User
  User? get currentUser {
    if (!isFirebaseInitialized) return null;
    return _auth!.currentUser;
  }

  // Sign Up
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String displayName,
    String? deviceId,
    String? imageUrl,
  }) async {
    if (!isFirebaseInitialized) throw Exception("Firebase not initialized");
    try {
      UserCredential result = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Initialize User Data in Firestore (Skip on Web)
      if (!kIsWeb) {
        await _firestore.collection('users').doc(result.user!.uid).set({
          'name': displayName,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'isSubscribed': false,
          'platform': defaultTargetPlatform.toString(),
          if (deviceId != null) 'activeDeviceId': deviceId,
          'image_url': imageUrl,
          'photoUrl': imageUrl,
        });
      }
      // Update Firebase User Display Name
      await result.user!.updateDisplayName(displayName);
      ApiService.sendTelemetry(result.user!.uid);
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
    String? deviceId,
  }) async {
    if (!isFirebaseInitialized) throw Exception("Firebase not initialized");
    try {
      final cred = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        ApiService.sendTelemetry(cred.user!.uid);
        if (deviceId != null && !kIsWeb) {
          await _firestore
              .collection('users')
              .doc(cred.user!.uid)
              .set({'activeDeviceId': deviceId}, SetOptions(merge: true));
        }
      }
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Update User Name
  Future<void> updateUserName(String newName) async {
    User? user = currentUser;
    if (user == null) return;

    try {
      // 1. Update Firebase Auth Display Name
      await user.updateDisplayName(newName);

      // 2. Update Firestore User Document (Skip on Web)
      if (!kIsWeb) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': newName,
        });
      }
    } catch (e) {
      debugPrint("Update User Name Error: $e");
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    if (!isFirebaseInitialized) return;
    await _auth!.signOut();
  }

  // Check Subscription Status
  Future<bool> checkSubscription() async {
    final userData = await getUserData();
    if (userData != null) {
      return userData['isSubscribed'] == true;
    }
    return false;
  }

  // Get User Stream for real-time updates (Banned status, etc.)
  // 🛑 Returns null on Web to prevent iOS Safari crash
  Stream<DocumentSnapshot>? getUserStream() {
    if (kIsWeb || !isFirebaseInitialized) return null;
    User? user = currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  // Get User Data (Plan, Expiry, etc.)
  static const String _userCacheKey = 'cached_user_data';

  Future<Map<String, dynamic>?> getUserData({bool forceRefresh = false}) async {
    User? user = currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();

    // 2. Fetch Fresh Data (Always, unless we implement SWR pattern in UI)
    // Actually, let's keep it simple: If forceRefresh is false AND we have cache,
    // we COULD return cache, but then we never update.
    // So standard behavior: Fetch Fresh, Save to Cache.
    // The UI (main.dart) will be responsible for calling getCachedUserDataOnly() first for instant load.

    final apiData = await ApiService.fetchUserStatus(user.uid);
    Map<String, dynamic> finalData = apiData ?? {};

    // Merge with Firestore data
    try {
      // 🛑 WEB FIX: Skip Firestore read on Web to prevent NullError/Crash
      // We rely on API data for Web users.
      if (kIsWeb) {
        // Return mostly API data + defaults
        return finalData;
      }

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data() != null) {
        final firestoreData = doc.data()!;
        final merged = <String, dynamic>{};
        merged.addAll(firestoreData); // Base
        if (apiData != null) {
          merged.addAll(apiData); // API overrides
        }
        finalData = merged;
      }
    } catch (e) {
      debugPrint("Error fetching Firestore user data: $e");
    }

    // 3. Save to Cache
    if (finalData.isNotEmpty) {
      try {
        prefs.setString(
            _userCacheKey,
            jsonEncode(finalData, toEncodable: (nonEncodable) {
              if (nonEncodable is Timestamp) {
                return nonEncodable.toDate().toIso8601String();
              }
              if (nonEncodable is DateTime) {
                return nonEncodable.toIso8601String();
              }
              return nonEncodable.toString();
            }));
      } catch (e) {
        debugPrint("Error caching user data: $e");
      }
    } else {
      // If network failed (empty finalData), try fallback to cache
      if (prefs.containsKey(_userCacheKey)) {
        final cachedString = prefs.getString(_userCacheKey);
        if (cachedString != null) {
          return jsonDecode(cachedString);
        }
      }
    }

    return finalData.isNotEmpty ? finalData : null;
  }

  Future<Map<String, dynamic>?> getCachedUserDataOnly() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_userCacheKey)) {
      try {
        return jsonDecode(prefs.getString(_userCacheKey)!);
      } catch (_) {}
    }
    return null;
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
    User? user = currentUser;
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

  /// Activates a one-time 24-hour free trial for the current user.
  Future<bool> startTrial() async {
    if (kIsWeb || !isFirebaseInitialized) {
      debugPrint("startTrial: Not supported on Web or Firebase not init.");
      return false;
    }
    User? user = currentUser;
    if (user == null) return false;

    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;

        if (data['trialUsed'] == true) {
          debugPrint("Trial already used for this user.");
          return false;
        }
        if (data['isSubscribed'] == true) {
          debugPrint("User is already subscribed.");
          return false;
        }

        final now = DateTime.now();
        final expiry = now.add(const Duration(hours: 24));

        await docRef.update({
          'isSubscribed': true,
          'subscriptionExpiry': expiry,
          'subscriptionPlan': 'تجربة مجانية (24 ساعة)',
          'trialUsed': true,
          'trialStartedAt': FieldValue.serverTimestamp(),
        });

        debugPrint("24-hour trial activated for user: ${user.uid}");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("startTrial Error: $e");
      return false;
    }
  }

  Future<void> updateProfilePicture(String url) async {
    User? user = currentUser;
    if (user == null) return;

    try {
      // 1. Update Firebase Auth Photo URL
      await user.updatePhotoURL(url);

      // 2. Update Firestore User Document (Skip on Web)
      if (!kIsWeb) {
        await _firestore.collection('users').doc(user.uid).update({
          'photoUrl': url,
          'image_url': url,
        });
      }

      ApiService.sendTelemetry(user.uid);
    } catch (e) {
      debugPrint("Update Profile Picture Error: $e");
      rethrow;
    }
  }
}
