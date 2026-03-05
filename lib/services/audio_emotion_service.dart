import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/emotion_result.dart';

class AudioEmotionService {
  // Audio-classification emotion models (tried in order)
  static const List<String> _modelUrls = [
    'https://router.huggingface.co/hf-inference/models/ehcalabres/wav2vec2-lg-xlsr-en-speech-emotion-recognition',
    'https://router.huggingface.co/hf-inference/models/superb/wav2vec2-large-superb-er',
    'https://router.huggingface.co/hf-inference/models/superb/hubert-large-superb-er',
  ];

  /// Send raw audio bytes to HuggingFace for audio-based emotion detection.
  /// The model analyzes voice tone, pitch, and waveform patterns — not text content.
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

    // Try each model URL in order
    String? lastError;
    for (final modelUrl in _modelUrls) {
      debugPrint('📤 [AudioEmotionService] Trying: $modelUrl');

      try {
        final response = await http.post(
          Uri.parse(modelUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'audio/wav',
          },
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
          final waitSeconds = (estimatedTime is num)
              ? estimatedTime.toInt()
              : 20;
          final msg =
              'Model is loading. Please wait ~${waitSeconds}s and try again.';
          debugPrint('⏳ [AudioEmotionService] $msg');
          throw ModelLoadingException(msg, Duration(seconds: waitSeconds));
        } else if (response.statusCode == 404) {
          lastError =
              'Model not available on free tier (404). This model requires a HuggingFace Pro subscription or Dedicated Endpoint.';
          debugPrint('⚠️ [AudioEmotionService] 404 — trying next model...');
          continue; // Try next model
        } else {
          lastError =
              'HuggingFace API error (${response.statusCode}): ${response.body}';
          debugPrint('❌ [AudioEmotionService] $lastError');
          continue; // Try next model
        }
      } catch (e) {
        if (e is ModelLoadingException) rethrow;
        lastError = e.toString();
        debugPrint('❌ [AudioEmotionService] Exception: $lastError');
        continue;
      }
    }

    // All models failed
    throw AudioModelUnavailableException(
      lastError ??
          'All audio emotion models are unavailable. Audio-classification models require a HuggingFace Pro plan.',
    );
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
