import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'ad_service.dart';
// import 'package:hesen/utils/crypto_utils.dart'; // REMOVED: No longer needed for decryption

class PromoCodeService {
  // The encrypted token is fetched from environment variables and decrypted at runtime.
  static final String _githubToken = dotenv.env['GITHUB_TOKEN'] ?? ''; // MODIFIED: Read plain token
  static const String _repoOwner = 'hussein34535';
  static const String _repoName = 'database';
  static const String _filePath = 'database/promo-codes.json';
  static const String _apiUrl = 'https://api.github.com/repos/$_repoOwner/$_repoName/contents/$_filePath';
  
  static const String _usedCodesKey = 'used_promo_codes';

  Future<Map<String, dynamic>> _fetchPromoFile() async {
    final headers = {
      'Authorization': 'Bearer $_githubToken',
      'Accept': 'application/vnd.github.v3+json',
    };
    final response = await http.get(Uri.parse(_apiUrl), headers: headers);

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final contentData = body['content'];
      if (contentData is String && contentData.isNotEmpty) {
        final content = utf8.decode(base64.decode(contentData.replaceAll('\n', '')));
        return {'sha': body['sha'], 'codes': json.decode(content)};
      } else {
        throw Exception('Failed to fetch promo codes: content is empty or invalid.');
      }
    } else {
      throw Exception('Failed to fetch promo codes from GitHub: ${response.body}');
    }
  }

  Future<void> _updatePromoFile(String sha, List<dynamic> codes) async {
    final headers = {
      'Authorization': 'Bearer $_githubToken',
      'Accept': 'application/vnd.github.v3+json',
    };
    final content = json.encode(codes);
    final encodedContent = base64.encode(utf8.encode(content));

    final body = json.encode({
      'message': 'Update promo code usage',
      'content': encodedContent,
      'sha': sha,
    });

    final response = await http.put(Uri.parse(_apiUrl), headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception('Failed to update promo codes on GitHub: ${response.body}');
    }
  }
  
  Future<String> redeemCode(String codeToRedeem) async {
    final prefs = await SharedPreferences.getInstance();
    final usedCodes = prefs.getStringList(_usedCodesKey) ?? [];

    if (usedCodes.contains(codeToRedeem.toUpperCase())) {
      return 'Error: You have already used this code.';
    }

    final fileData = await _fetchPromoFile();
    final String currentSha = fileData['sha'];
    final List<dynamic> codes = fileData['codes'];

    final codeIndex = codes.indexWhere((c) => c['code']?.toString().toUpperCase() == codeToRedeem.toUpperCase());

    if (codeIndex == -1) {
      return 'Error: Invalid promo code.';
    }

    final promoData = codes[codeIndex];
    
    // --- Validation ---
    if (promoData['status'] != 'active') {
        return 'Error: This code is not active.';
    }

    final expiryDate = DateFormat("yyyy-MM-dd").parse(promoData['expiry_date']);
    if (DateTime.now().isAfter(expiryDate.add(const Duration(days: 1)))) { // Add 1 day to make it inclusive
        return 'Error: This code has expired.';
    }

    final int maxUsers = promoData['max_users'] ?? 0;
    final int usedCount = promoData['used_count'] ?? 0;
    if (usedCount >= maxUsers) {
        return 'Error: This code has reached its usage limit.';
    }
    
    // --- Grant Reward & Update ---
    final startDate = DateFormat("yyyy-MM-dd").parse(promoData['start_date']);
    final adFreeDuration = expiryDate.difference(startDate);

    await AdService.addAdFreePeriod(adFreeDuration);
    
    // Update local list of used codes
    usedCodes.add(codeToRedeem.toUpperCase());
    await prefs.setStringList(_usedCodesKey, usedCodes);

    // Update the count in the JSON object
    promoData['used_count'] = usedCount + 1;
    codes[codeIndex] = promoData;

    // Push update to GitHub
    try {
      await _updatePromoFile(currentSha, codes);
    } catch (e) {
      // If updating GitHub fails, we should ideally revert the local changes.
      // For now, we'll just report the error.
      return 'Error: Could not update promo code status. Please try again.';
    }

    return 'Success! ${adFreeDuration.inDays} ad-free days have been added.';
  }
}
