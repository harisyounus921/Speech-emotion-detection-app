import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/emotion_result.dart';

class AudioEmotionService {
  static const String _modelUrl ='https://api-inference.huggingface.co/models/ehcalabres/wav2vec2-lg-xlsr-en-speech-emotion-recognition';

 static Future<List<EmotionResult>> detectEmotionFromAudio(
    Uint8List audioBytes,
  ) async {
    final apiKey = dotenv.env['HF_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'hf_your_token_here') {
      const msg =
          'HF_API_KEY not set. Add your HuggingFace token to .env file.';
      debugPrint('❌ [AudioEmotionService] $msg');
      throw Exception(msg);
    }

    if (audioBytes.isEmpty) {
      const msg = 'No audio data recorded. Please try again.';
      debugPrint('❌ [AudioEmotionService] $msg');
      throw Exception(msg);
    }

    debugPrint(
      '📤 [AudioEmotionService] Audio size: ${audioBytes.length} bytes',
    );
    debugPrint('📤 [AudioEmotionService] Sending to: $_modelUrl');

    final response = await http.post(
      Uri.parse(_modelUrl),
      headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'audio/wav'},
      body: audioBytes,
    );

    debugPrint('📥 [AudioEmotionService] Response: ${response.statusCode}');
    debugPrint('📥 [AudioEmotionService] Body: ${response.body}');

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      // Response format: [{label, score}, ...] or [[{label, score}, ...]]
      final List<dynamic> data =
          decoded is List && decoded.isNotEmpty && decoded[0] is List
          ? decoded[0] as List<dynamic>
          : decoded as List<dynamic>;
      final results = data
          .map((e) => EmotionResult.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('✅ [AudioEmotionService] Got ${results.length} results');
      for (final r in results) {
        debugPrint('   ${r.emoji} ${r.label}: ${r.percentage}');
      }
      return results;
    } else if (response.statusCode == 503) {
      final body = jsonDecode(response.body);
      final estimatedTime = body['estimated_time'] ?? 20;
      final waitSeconds = (estimatedTime is num) ? estimatedTime.toInt() : 20;
      final msg = 'Model is loading (~${waitSeconds}s cold start). Retrying...';
      debugPrint('⏳ [AudioEmotionService] $msg');
      throw ModelLoadingException(msg, Duration(seconds: waitSeconds));
    } else if (response.statusCode == 410) {
      const msg =
          'Model is no longer available via the public Inference API (410 Gone).';
      debugPrint('❌ [AudioEmotionService] $msg');
      throw AudioModelUnavailableException(msg);
    } else {
      final msg =
          'HuggingFace API error (${response.statusCode}): ${response.body}';
      debugPrint('❌ [AudioEmotionService] $msg');
      throw Exception(msg);
    }
  }
}

class ModelLoadingException implements Exception {
  final String message;
  final Duration estimatedWait;

  ModelLoadingException(this.message, this.estimatedWait);

  @override
  String toString() => message;
}

class AudioModelUnavailableException implements Exception {
  final String message;

  AudioModelUnavailableException(this.message);

  @override
  String toString() => message;
}
