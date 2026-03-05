import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emotion_result.dart';
import '../services/audio_emotion_service.dart';

class AudioEmotionScreen extends StatefulWidget {
  const AudioEmotionScreen({super.key});

  @override
  State<AudioEmotionScreen> createState() => _AudioEmotionScreenState();
}

class _AudioEmotionScreenState extends State<AudioEmotionScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isAnalyzing = false;
  List<EmotionResult>? _results;
  String? _errorMessage;
  int _recordingDuration = 0;
  Timer? _timer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _errorMessage = 'Microphone permission denied.');
      return;
    }

    // Check if recorder can record
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _errorMessage = 'Microphone permission not granted.');
      return;
    }

    // Get temp directory for the audio file
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/emotion_audio_${DateTime.now().millisecondsSinceEpoch}.wav';

    setState(() {
      _results = null;
      _errorMessage = null;
      _recordingDuration = 0;
      _isRecording = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingDuration++);
    });

    // Record as WAV (16kHz mono) — best format for HuggingFace audio models
    final config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );

    debugPrint('🎙️ [AudioRecorder] Starting recording to: $path');
    await _recorder.start(config, path: path);
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();

    final path = await _recorder.stop();
    debugPrint('🎙️ [AudioRecorder] Recording stopped. Path: $path');

    setState(() {
      _isRecording = false;
    });

    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        debugPrint(
          '🎙️ [AudioRecorder] Audio file size: ${bytes.length} bytes',
        );
        if (bytes.length < 1000) {
          setState(
            () => _errorMessage =
                'Recording too short. Please record for at least 2 seconds.',
          );
          return;
        }
        await _analyzeAudio(bytes);
      } else {
        setState(() => _errorMessage = 'Recording file not found.');
      }
    } else {
      setState(
        () => _errorMessage = 'No recording produced. Please try again.',
      );
    }
  }

  Future<void> _analyzeAudio(Uint8List audioBytes) async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final results = await AudioEmotionService.detectEmotionFromAudio(
        audioBytes,
      );
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
        // Auto-retry after estimated wait
        Future.delayed(e.estimatedWait, () {
          if (mounted && _results == null) _analyzeAudio(audioBytes);
        });
      }
    } on AudioModelUnavailableException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isAnalyzing = false;
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
          'Audio Emotion Detection',
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
                _isRecording
                    ? '🔴 Recording... ${_formatDuration(_recordingDuration)}'
                    : _isAnalyzing
                    ? '🔄 Analyzing audio emotion...'
                    : '🎙️ Tap to record audio',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),

              if (!_isRecording && !_isAnalyzing && _results == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Record 2-10 seconds of speech, then tap stop',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),

              const SizedBox(height: 12),

              // Info banner
              if (!_isRecording && !_isAnalyzing && _results == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0F3460).withOpacity(0.5),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.graphic_eq, color: Colors.white54, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This mode sends raw audio waveform to detect emotion from voice tone, pitch & rhythm.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              // Recording indicator
              if (_isRecording)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Recording audio — ${_formatDuration(_recordingDuration)}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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
                  'Sending audio to HuggingFace for analysis...',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
          : (_isRecording ? _stopRecording : _startRecording),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? Colors.red
                    : _isAnalyzing
                    ? Colors.grey
                    : const Color(0xFFE94560),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : const Color(0xFFE94560))
                        .withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.graphic_eq,
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
              colors: [Color(0xFFE94560), Color(0xFF0F3460)],
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '🎵 Detected from audio waveform',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
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
          onPressed: _startRecording,
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
