import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static const String _adFreeExpiryKey = 'ad_free_expiry_date';
  static const String _hasUsedCodeKey = 'has_used_promo_code';

  // Checks if the user is currently in an ad-free period.
  static Future<bool> isAdFree() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryDateString = prefs.getString(_adFreeExpiryKey);

    if (expiryDateString == null) {
      return false;
    }

    final expiryDate = DateTime.tryParse(expiryDateString);
    if (expiryDate == null) {
      return false;
    }

    // Return true if the expiry date is still in the future.
    return DateTime.now().isBefore(expiryDate);
  }

  // Extends the ad-free period by a given duration.
  static Future<void> addAdFreePeriod(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final expiryDateString = prefs.getString(_adFreeExpiryKey);
    
    DateTime currentExpiry = DateTime.now();
    if (expiryDateString != null) {
      final storedExpiry = DateTime.tryParse(expiryDateString);
      // If the stored expiry is in the future, use it as the base. Otherwise, start from now.
      if (storedExpiry != null && storedExpiry.isAfter(DateTime.now())) {
        currentExpiry = storedExpiry;
      }
    }
    
    final newExpiryDate = currentExpiry.add(duration);
    await prefs.setString(_adFreeExpiryKey, newExpiryDate.toIso8601String());
    await prefs.setBool(_hasUsedCodeKey, true); // Mark that user has used a code
  }

  // Gets the expiry date of the ad-free period, if one exists.
  static Future<DateTime?> getAdFreeExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryDateString = prefs.getString(_adFreeExpiryKey);
    if (expiryDateString == null) {
      return null;
    }
    return DateTime.tryParse(expiryDateString);
  }

  // Checks if a user has ever successfully redeemed a promo code.
  static Future<bool> hasEverUsedPromoCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasUsedCodeKey) ?? false;
  }

  // For debugging or testing purposes
  static Future<void> clearAdFreePeriod() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_adFreeExpiryKey);
  }
}
