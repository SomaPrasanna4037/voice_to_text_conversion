import 'package:http/http.dart' as http;
import 'dart:convert';

/// Utility class to validate Azure Speech credentials
class AzureCredentialsValidator {
  /// Validates Azure Speech subscription key and region
  /// Returns true if credentials are valid, false otherwise
  static Future<bool> validateCredentials({
    required String subscriptionKey,
    required String region,
  }) async {
    try {
      print('🔍 Validating Azure credentials...');
      print('  - Key: ${subscriptionKey.substring(0, 4)}...${subscriptionKey.substring(subscriptionKey.length - 4)}');
      print('  - Region: $region');

      // Step 1: Check if key format is valid
      if (subscriptionKey.isEmpty || subscriptionKey.length < 10) {
        print('❌ Subscription key format invalid (too short)');
        return false;
      }

      if (region.isEmpty) {
        print('❌ Region is empty');
        return false;
      }

      // Step 2: Try to call Azure Speech API to validate credentials
      final url =
          'https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US';

      print('📡 Testing API endpoint: $url');

      // Make a test request with the credentials
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Ocp-Apim-Subscription-Key': subscriptionKey,
          'Content-Type': 'audio/wav',
        },
        body: _generateSilentWavFile(), // Send a small silent audio file
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Request timeout - check your internet connection');
        },
      );

      print('📊 Response status: ${response.statusCode}');
      print('📊 Response headers: ${response.headers}');

      // Status codes that indicate valid credentials:
      // 200: Success with recognized text
      // 400: Bad request (often means bad audio, but credentials are valid)
      // 401: Unauthorized (invalid key or region)
      // 403: Forbidden (subscription expired or region blocked)
      // 404: Not found (invalid region)

      switch (response.statusCode) {
        case 200:
          print('✅ Credentials valid! Speech recognized successfully');
          return true;

        case 400:
          print('✅ Credentials valid! (Audio was silent/invalid, but auth passed)');
          return true;

        case 401:
          print('❌ UNAUTHORIZED: Invalid subscription key or region mismatch');
          print('   Response: ${response.body}');
          return false;

        case 403:
          print('❌ FORBIDDEN: Subscription might be expired or blocked');
          print('   Response: ${response.body}');
          return false;

        case 404:
          print('❌ NOT FOUND: Invalid region or endpoint');
          print('   Response: ${response.body}');
          return false;

        default:
          print('⚠️  Unexpected status code: ${response.statusCode}');
          print('   Response: ${response.body}');
          // Try to parse error message
          try {
            final json = jsonDecode(response.body);
            if (json is Map && json.containsKey('error')) {
              print('   Error details: ${json['error']}');
            }
          } catch (_) {
            // Not JSON, just print the body
          }
          return false;
      }
    } on TimeoutException catch (e) {
      print('❌ Connection timeout: ${e.message}');
      print('   - Check your internet connection');
      print('   - Check if region is correct');
      return false;
    } catch (e) {
      print('❌ Validation error: $e');
      return false;
    }
  }

  /// Generates a minimal silent WAV file for testing
  /// This is the smallest valid WAV file (44 bytes of silence)
  static List<int> _generateSilentWavFile() {
    // WAV header for silent audio (8000 Hz, 16-bit mono, 1 second)
    return [
      // RIFF chunk descriptor
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      0x24, 0x00, 0x00, 0x00, // Chunk size
      0x57, 0x41, 0x56, 0x45, // "WAVE"

      // fmt sub-chunk
      0x66, 0x6d, 0x74, 0x20, // "fmt "
      0x10, 0x00, 0x00, 0x00, // Subchunk1Size
      0x01, 0x00, // AudioFormat (PCM)
      0x01, 0x00, // NumChannels (mono)
      0x40, 0x1f, 0x00, 0x00, // SampleRate (8000)
      0x80, 0x3e, 0x00, 0x00, // ByteRate
      0x02, 0x00, // BlockAlign
      0x10, 0x00, // BitsPerSample

      // data sub-chunk
      0x64, 0x61, 0x74, 0x61, // "data"
      0x00, 0x00, 0x00, 0x00, // Subchunk2Size
    ];
  }

  /// Print credential validation checklist
  static void printCheckList() {
    print("""
╔════════════════════════════════════════════════════════════════╗
║          AZURE SPEECH CREDENTIALS VALIDATION CHECKLIST          ║
╠════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ 1. SUBSCRIPTION KEY (Ocp-Apim-Subscription-Key)                ║
║    ✓ Must be 32 characters or longer                           ║
║    ✓ Contains only alphanumeric characters                     ║
║    ✓ Check that you copied the FULL key (not truncated)       ║
║    ✓ Both primary and secondary keys should work              ║
║                                                                  ║
║ 2. REGION                                                       ║
║    ✓ Must match the region where the resource is created      ║
║    ✓ Common regions: eastus, westus, westeurope, etc.         ║
║    ✓ Check: Portal → Your Resource → Keys and Endpoint       ║
║    ✓ Must be lowercase (e.g., 'eastus' not 'EastUS')         ║
║                                                                  ║
║ 3. ENDPOINT (if using custom endpoint)                         ║
║    ✓ Format: https://<REGION>.stt.speech.microsoft.com        ║
║    ✓ Check: Portal → Your Resource → Keys and Endpoint       ║
║    ✓ Should NOT include '/speech' path for initialization     ║
║                                                                  ║
║ 4. ACCOUNT STATUS                                              ║
║    ✓ Subscription must be active (not expired)                ║
║    ✓ Free tier has 5,000 requests per month limit             ║
║    ✓ Check: Portal → Billing → Free Trial Status             ║
║                                                                  ║
║ 5. INTERNET CONNECTION                                         ║
║    ✓ Verify you have active internet connection               ║
║    ✓ Check firewall/proxy settings                            ║
║    ✓ Try connecting to www.google.com first                   ║
║                                                                  ║
║ 6. API VERSION & PROTOCOL                                      ║
║    ✓ Using correct Speech API endpoint                        ║
║    ✓ Endpoint must support Speech-to-Text (STT)              ║
║    ✓ NOT using Translator or other Azure services            ║
║                                                                  ║
╚════════════════════════════════════════════════════════════════╝
    """);
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
