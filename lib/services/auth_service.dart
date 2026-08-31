import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hesen/web_utils.dart'
    if (dart.library.io) 'package:hesen/web_utils_stub.dart';
import 'package:hesen/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hesen/services/resend_service.dart';

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
      final user = result.user;
      if (user == null) throw Exception("User creation succeeded but user is null");

      if (!kIsWeb) {
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'name': displayName,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'isSubscribed': false,
            'platform': defaultTargetPlatform.toString(),
            if (deviceId != null) 'activeDeviceId': deviceId,
            'image_url': imageUrl,
            'photoUrl': imageUrl,
          });
        } catch (e) {
          debugPrint("Firestore SignUp Error: $e");
        }
      }
      await user.updateDisplayName(displayName);
      if (user.email != null) {
        ApiService.registerUser(user.uid, user.email!);
      }
      ApiService.sendTelemetry(user.uid);
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
      final user = cred.user;
      if (user != null) {
        if (user.email != null) {
          ApiService.registerUser(user.uid, user.email!);
        }
        ApiService.sendTelemetry(user.uid);
        if (deviceId != null && !kIsWeb) {
          try {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .set({'activeDeviceId': deviceId}, SetOptions(merge: true));
          } catch (e) {
            debugPrint("Firestore SignIn DeviceId Error: $e");
          }
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

  // Send Email Verification
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user == null) return;
    await user.sendEmailVerification();
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    if (!isFirebaseInitialized) throw Exception("Firebase not initialized");
    await _auth!.sendPasswordResetEmail(email: email);
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

      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get().timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data() != null) {
        final firestoreData = doc.data()!;
        
        // Auto-save activeDeviceId if missing/different
        final deviceId = prefs.getString('device_id');
        if (deviceId != null && firestoreData['activeDeviceId'] != deviceId) {
          docRef.set({'activeDeviceId': deviceId}, SetOptions(merge: true)).catchError((e) {
            debugPrint("Error auto-updating activeDeviceId in getUserData: $e");
          });
          firestoreData['activeDeviceId'] = deviceId; // Update local map too
        }

        final merged = <String, dynamic>{};
        merged.addAll(firestoreData); // Base
        if (apiData != null) {
          merged.addAll(apiData); // API overrides
          
          // Smart merge: if either says subscribed, then user is subscribed.
          // This prevents stale API responses from overriding a fresh Firestore update.
          if (firestoreData['isSubscribed'] == true || apiData['isSubscribed'] == true) {
            merged['isSubscribed'] = true;
          }
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
      ).timeout(const Duration(seconds: 15));

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

  /// Activates a one-time 3-day free trial for the current user.
  /// Works on both Web (via API) and Native (via Firestore).
  Future<bool> startTrial() async {
    if (!isFirebaseInitialized) return false;
    User? user = currentUser;
    if (user == null) return false;

    // ✅ On Web: Use backend API to activate trial
    if (kIsWeb) {
      try {
        final token = await user.getIdToken();
        if (token == null) return false;

        final response = await http.post(
          Uri.parse('https://7esentvbackend.vercel.app/api/mobile/start-trial'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'uid': user.uid}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            debugPrint("3-day trial activated via API for: ${user.uid}");
            return true;
          } else {
            debugPrint("startTrial API error: ${data['error']}");
            return false;
          }
        } else if (response.statusCode == 409) {
          // 409 = Trial already used
          debugPrint("Trial already used (409): ${response.body}");
          return false;
        }
        debugPrint("startTrial API HTTP error: ${response.statusCode}");
        return false;
      } catch (e) {
        debugPrint("startTrial Web Error: $e");
        return false;
      }
    }

    // ✅ On Native: Use Firestore directly
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      // 1. Strict Device Check: Has ANY account on this device used a trial?
      if (deviceId != null) {
        final deviceDocs = await _firestore
            .collection('users')
            .where('activeDeviceId', isEqualTo: deviceId)
            .get();
            
        for (var d in deviceDocs.docs) {
          final dData = d.data();
          if (dData['trialUsed'] == true) {
            debugPrint("Trial already used on this device by account: ${d.id}");
            return false; // Block trial for new account on same device!
          }
        }
      }

      // 2. Account Check: Has this specific account used it?
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
        final expiry = now.add(const Duration(days: 3));

        await docRef.update({
          'isSubscribed': true,
          'subscriptionExpiry': expiry,
          'subscriptionPlan': 'تجربة مجانية (3 أيام)',
          'trialUsed': true,
          'trialStartedAt': FieldValue.serverTimestamp(),
        });

        debugPrint("3-day trial activated for user: ${user.uid}");
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

      // 2. Update Firestore User Document
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': url,
        'image_url': url,
      });

      ApiService.sendTelemetry(user.uid);
    } catch (e) {
      debugPrint("Update Profile Picture Error: $e");
      rethrow;
    }
  }

  /// Cancels subscription at any time.
  /// Works on both Web (clears local cache and triggers backend API) and Native (directly updates Firestore).
  Future<bool> cancelSubscription() async {
    if (!isFirebaseInitialized) return false;
    User? user = currentUser;
    if (user == null) return false;

    // 1. Send cancellation email
    if (user.email != null) {
      try {
        await ResendService.sendSubscriptionCancellationConfirmation(email: user.email!);
      } catch (e) {
        debugPrint("Error sending cancellation email: $e");
      }
    }

    // 2. Web specific logic
    if (kIsWeb) {
      try {
        final token = await user.getIdToken();
        if (token == null) return false;

        final response = await http.post(
          Uri.parse('https://7esentvbackend.vercel.app/api/mobile/cancel-subscription'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'uid': user.uid}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            debugPrint("Subscription cancelled via API for: ${user.uid}");
          }
        }
      } catch (e) {
        debugPrint("cancelSubscription API error: $e");
      }
    }

    // 3. Update Firestore (Native) or fall back
    try {
      if (!kIsWeb) {
        final docRef = _firestore.collection('users').doc(user.uid);
        await docRef.update({
          'isSubscribed': false,
          'subscriptionExpiry': null,
          'subscriptionPlan': null,
        });
      }

      // Clear local cache to force status update
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userCacheKey);

      debugPrint("Subscription cancelled successfully for: ${user.uid}");
      return true;
    } catch (e) {
      debugPrint("cancelSubscription Error: $e");
      return false;
    }
  }

  /// Sign in with Google using Firebase Auth Provider.
  Future<UserCredential?> signInWithGoogle() async {
    if (!isFirebaseInitialized) throw Exception("Firebase not initialized");
    try {
      final googleProvider = GoogleAuthProvider()
        // Always show the Google account chooser instead of silently
        // reusing whatever session Google remembers.
        ..setCustomParameters({'prompt': 'select_account'});
      UserCredential cred;
      if (kIsWeb) {
        final bool isApplePlatform =
            defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS;
        if (!isApplePlatform) {
          cred = await _auth!.signInWithPopup(googleProvider);
        } else if (isIosStandalonePwa) {
          // Installed home-screen PWA on iOS: popups hang silently (window.open
          // never resolves) — go straight to the redirect flow.
          debugPrint('signInWithGoogle: iOS standalone PWA → redirect');
          await _auth!.signInWithRedirect(googleProvider);
          // Page reloads when Google returns; session restored on startup.
          return null;
        } else {
          // Safari tab: popup shares the browser session → account list shows.
          try {
            cred = await _auth!.signInWithPopup(googleProvider);
          } on FirebaseAuthException catch (e) {
            const fallbackCodes = {
              'popup-blocked',
              'popup-closed-by-user',
              'cancelled-popup-request',
              'operation-not-supported-in-this-environment',
            };
            if (fallbackCodes.contains(e.code)) {
              debugPrint(
                  'signInWithGoogle: popup unavailable (${e.code}) → redirect');
              await _auth!.signInWithRedirect(googleProvider);
              return null;
            }
            rethrow;
          }
        }
      } else {
        cred = await _auth!.signInWithProvider(googleProvider);
      }
      final user = cred.user;
      if (user != null) {
        if (user.email != null) {
          ApiService.registerUser(user.uid, user.email!);
        }
        ApiService.sendTelemetry(user.uid);
        // Create Firestore user record if native and it does not exist
        if (!kIsWeb) {
          final docRef = _firestore.collection('users').doc(user.uid);
          final doc = await docRef.get();
          if (!doc.exists) {
            await docRef.set({
              'name': user.displayName ?? 'Google User',
              'email': user.email,
              'createdAt': FieldValue.serverTimestamp(),
              'isSubscribed': false,
              'platform': defaultTargetPlatform.toString(),
            });
            try {
              await startTrial();
            } catch (_) {}
          }
        }
      }
      return cred;
    } catch (e) {
      debugPrint("signInWithGoogle Error: $e");
      rethrow;
    }
  }

  /// Sign in with Apple using Firebase Auth Provider.
  Future<UserCredential?> signInWithApple() async {
    if (!isFirebaseInitialized) throw Exception("Firebase not initialized");
    try {
      final appleProvider = AppleAuthProvider();
      UserCredential cred;
      if (kIsWeb) {
        cred = await _auth!.signInWithPopup(appleProvider);
      } else {
        cred = await _auth!.signInWithProvider(appleProvider);
      }
      final user = cred.user;
      if (user != null) {
        if (user.email != null) {
          ApiService.registerUser(user.uid, user.email!);
        }
        ApiService.sendTelemetry(user.uid);
        // Create Firestore user record if native and it does not exist
        if (!kIsWeb) {
          final docRef = _firestore.collection('users').doc(user.uid);
          final doc = await docRef.get();
          if (!doc.exists) {
            await docRef.set({
              'name': user.displayName ?? 'Apple User',
              'email': user.email,
              'createdAt': FieldValue.serverTimestamp(),
              'isSubscribed': false,
              'platform': defaultTargetPlatform.toString(),
            });
            try {
              await startTrial();
            } catch (_) {}
          }
        }
      }
      return cred;
    } catch (e) {
      debugPrint("signInWithApple Error: $e");
      rethrow;
    }
  }
}
