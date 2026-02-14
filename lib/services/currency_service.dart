import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static const String _baseUrl = 'https://ipwho.is/';
  static String _currencyCode = 'EGP';
  static String _currencySymbol = 'جنية';
  static double _exchangeRate = 1.0;

  static const String _ratesUrl =
      'https://api.exchangerate-api.com/v4/latest/EGP';

  static final Map<String, String> _symbols = {
    'EG': 'جنية',
    'US': '\$',
    'SA': 'ر.س',
    'AE': 'د.إ',
    'KW': 'د.ك',
    'QA': 'ر.ق',
    'BH': 'د.ب',
    'OM': 'ر.ع',
    'JO': 'د.أ',
    'LB': 'ل.ل',
    'DE': '€',
    'FR': '€',
    'IT': '€',
    'ES': '€',
    'GB': '£',
    'CA': 'C\$',
  };

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Get Country & Currency Code
      String? countryCode = prefs.getString('user_country_code');
      String? currencyCode = prefs.getString('user_currency_code');

      if (countryCode == null || currencyCode == null) {
        final response = await http.get(Uri.parse(_baseUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            countryCode = data['country_code'];
            currencyCode = data['currency']?['code'];

            if (countryCode != null)
              await prefs.setString('user_country_code', countryCode);
            if (currencyCode != null)
              await prefs.setString('user_currency_code', currencyCode);
          }
        }
      }

      // 2. Fetch Live Exchange Rates (Proxied)
      final rateResponse = await http.get(Uri.parse(_ratesUrl));
      if (rateResponse.statusCode == 200) {
        final rateData = json.decode(rateResponse.body);
        final fetchedRates = rateData['rates'] as Map<String, dynamic>;

        if (currencyCode != null && fetchedRates.containsKey(currencyCode)) {
          _exchangeRate = (fetchedRates[currencyCode] as num).toDouble();
          _currencyCode = currencyCode;
          _currencySymbol = _symbols[countryCode] ?? currencyCode;
          print('Currency Auto-Init: 1 EGP = $_exchangeRate $_currencyCode');
        }
      }
    } catch (e) {
      print('Currency init failed: $e');
    }
  }

  static String get currencySymbol => _currencySymbol;
  static String get currencyCode => _currencyCode;

  static double convert(double amountInEGP) {
    return amountInEGP * _exchangeRate;
  }

  static String format(dynamic amountInEGP) {
    double val = double.tryParse(amountInEGP.toString()) ?? 0.0;
    double converted = convert(val);
    return '${converted.toStringAsFixed(converted < 10 && _currencyCode != "KWD" ? 1 : 0)} $_currencySymbol';
  }
}
