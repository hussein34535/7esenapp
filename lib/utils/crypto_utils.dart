import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

class CryptoUtils {
  static String decrypt(String base64Encrypted) {
    // A single long secret is retrieved from environment variables.
    final String secret = dotenv.env['CRYPTO_SECRET'] ?? '';

    if (secret.isEmpty || base64Encrypted.isEmpty) {
      print('Decryption failed: Secret key or encrypted data is missing.');
      return '';
    }

    try {
      // We derive a secure 32-byte key and a 16-byte IV from the single secret.
      final keyBytes = sha256.convert(utf8.encode(secret)).bytes;
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      final iv = encrypt.IV(Uint8List.fromList(keyBytes.sublist(0, 16)));
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      
      // The data is Base64 decoded before being decrypted.
      final encryptedData = encrypt.Encrypted.fromBase64(base64Encrypted);
      
      // Decrypt the data using the derived key and IV.
      final decrypted = encrypter.decrypt(encryptedData, iv: iv);
      
      return decrypted;
    } catch (e) {
      print('Decryption failed: $e');
      return '';
    }
  }
}
