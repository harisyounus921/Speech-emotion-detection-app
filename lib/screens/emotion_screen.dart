import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/emotion_result.dart';
import '../services/emotion_service.dart';

class EmotionScreen extends StatefulWidget {
  const EmotionScreen({super.key});

  @override
  State<EmotionScreen> createState() => _EmotionScreenState();
}

class _EmotionScreenState extends State<EmotionScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isAnalyzing = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  List<EmotionResult>? _results;
  String? _errorMessage;
  int _listeningDuration = 0;
  Timer? _timer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        debugPrint('❌ [SpeechToText] Error: ${error.errorMsg}');
        if (mounted) {
          setState(() {
            _isListening = false;
            if (_recognizedText.isEmpty) {
              _errorMessage = 'Speech recognition error: ${error.errorMsg}';
            }
          });
          _timer?.cancel();
          // If we have some recognized text, analyze it anyway
          if (_recognizedText.isNotEmpty) {
            _analyzeEmotion(_recognizedText);
          }
        }
      },
      onStatus: (status) {
        debugPrint('🎤 [SpeechToText] Status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
            _timer?.cancel();
            if (_recognizedText.isNotEmpty) {
              _analyzeEmotion(_recognizedText);
            }
          }
        }
      },
    );
    debugPrint('🎤 [SpeechToText] Available: $_speechAvailable');
    setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      setState(
        () =>
            _errorMessage = 'Speech recognition not available on this device.',
      );
      return;
    }

    setState(() {
      _results = null;
      _errorMessage = null;
      _recognizedText = '';
      _listeningDuration = 0;
      _isListening = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _listeningDuration++);
    });

    await _speech.listen(
      onResult: (result) {
        debugPrint(
          '🎤 [SpeechToText] Result: "${result.recognizedWords}" (final: ${result.finalResult})',
        );
        setState(() {
          _recognizedText = result.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
  }

  Future<void> _stopListening() async {
    _timer?.cancel();
    await _speech.stop();
    setState(() => _isListening = false);

    if (_recognizedText.isNotEmpty) {
      await _analyzeEmotion(_recognizedText);
    } else {
      setState(() => _errorMessage = 'No speech detected. Please try again.');
    }
  }

  Future<void> _analyzeEmotion(String transcript) async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final results = await EmotionService.detectEmotion(transcript);
      if (mounted) {
        setState(() {
          _results = results;
          _isAnalyzing = false;
        });
      }
    } on ModelLoadingException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isAnalyzing = false;
        });
        Future.delayed(e.estimatedWait, () {
          if (mounted && _results == null) _analyzeEmotion(transcript);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text(
          'Emotion Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 30),

              // Status text
              Text(
                _isListening
                    ? '🔴 Listening... ${_formatDuration(_listeningDuration)}'
                    : _isAnalyzing
                    ? '🔄 Analyzing emotion...'
                    : '🎤 Tap the mic to start',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),

              if (!_isListening && !_isAnalyzing && _results == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Speak for 2-5 seconds, then tap stop',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),

              const SizedBox(height: 30),

              // Live transcript
              if (_recognizedText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transcript:',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"$_recognizedText"',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              // Mic button
              _buildMicButton(),

              const SizedBox(height: 40),

              // Loading indicator
              if (_isAnalyzing) ...[
                const CircularProgressIndicator(color: Color(0xFFE94560)),
                const SizedBox(height: 12),
                const Text(
                  'Analyzing emotion via HuggingFace...',
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 20),
              ],

              // Error message
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Results
              if (_results != null) _buildResults(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _isAnalyzing
          ? null
          : (_isListening ? _stopListening : _startListening),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? Colors.red
                    : _isAnalyzing
                    ? Colors.grey
                    : const Color(0xFF0F3460),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.red : const Color(0xFF0F3460))
                        .withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic,
                size: 50,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    final sorted = List<EmotionResult>.from(_results!)
      ..sort((a, b) => b.score.compareTo(a.score));
    final top = sorted.first;

    return Column(
      children: [
        // Top emotion card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3460), Color(0xFFE94560)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(top.emoji, style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 8),
              Text(
                top.label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Confidence: ${top.percentage}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // All emotions header
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'All Emotions',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Emotion bars
        ...sorted.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(e.emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 75,
                  child: Text(
                    e.label,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: e.score.clamp(0.0, 1.0),
                      minHeight: 20,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFE94560),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text(
                    e.percentage,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Record again button
        OutlinedButton.icon(
          onPressed: _startListening,
          icon: const Icon(Icons.refresh),
          label: const Text('Record Again'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white30),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
