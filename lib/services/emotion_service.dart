import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/emotion_result.dart';

class EmotionService {
  // Text-based emotion model via HuggingFace's new router API
  static const String _modelUrl =
      'https://router.huggingface.co/hf-inference/models/j-hartmann/emotion-english-distilroberta-base';

  /// Send transcript text to HuggingFace and get emotion predictions
  static Future<List<EmotionResult>> detectEmotion(String transcript) async {
    final apiKey = dotenv.env['HF_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'hf_your_token_here') {
      const msg =
          'HF_API_KEY not set. Add your HuggingFace token to .env file.';
      debugPrint('❌ [EmotionService] $msg');
      throw Exception(msg);
    }

    if (transcript.trim().isEmpty) {
      const msg = 'No speech detected. Please try again.';
      debugPrint('❌ [EmotionService] $msg');
      throw Exception(msg);
    }

    debugPrint('📤 [EmotionService] Sending text to HuggingFace...');
    debugPrint('📤 [EmotionService] Transcript: "$transcript"');
    debugPrint('📤 [EmotionService] Model URL: $_modelUrl');

    final response = await http.post(
      Uri.parse(_modelUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'inputs': transcript}),
    );

    debugPrint('📥 [EmotionService] Response status: ${response.statusCode}');
    debugPrint('📥 [EmotionService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      // Response is [[{label, score}, ...]] — a nested array
      final List<dynamic> data =
          decoded is List && decoded.isNotEmpty && decoded[0] is List
          ? decoded[0] as List<dynamic>
          : decoded as List<dynamic>;
      final results = data
          .map((e) => EmotionResult.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('✅ [EmotionService] Got ${results.length} emotion results');
      for (final r in results) {
        debugPrint('   ${r.emoji} ${r.label}: ${r.percentage}');
      }
      return results;
    } else if (response.statusCode == 503) {
      final body = jsonDecode(response.body);
      final estimatedTime = body['estimated_time'] ?? 20;
      final waitSeconds = (estimatedTime is num) ? estimatedTime.toInt() : 20;
      final msg =
          'Model is loading. Please wait ~${waitSeconds}s and try again.';
      debugPrint('⏳ [EmotionService] $msg');
      throw ModelLoadingException(msg, Duration(seconds: waitSeconds));
    } else {
      final msg =
          'HuggingFace API error (${response.statusCode}): ${response.body}';
      debugPrint('❌ [EmotionService] $msg');
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
