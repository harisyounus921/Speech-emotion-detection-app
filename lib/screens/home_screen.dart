import 'package:flutter/material.dart';
import 'emotion_screen.dart';
import 'audio_emotion_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text(
          'Speech Analyzer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎭', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              const Text(
                'Emotion Detection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to detect emotion',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 50),

              // Button 1: Text-based (speech-to-text → text emotion)
              _buildOptionCard(
                context,
                icon: Icons.text_fields,
                title: 'Send Text to Speech',
                subtitle:
                    'On-device speech recognition → text emotion analysis',
                description:
                    'Uses your device\'s built-in speech-to-text, then analyzes the text for emotions.',
                gradient: const [Color(0xFF0F3460), Color(0xFF533483)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmotionScreen()),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Button 2: Audio wave (record audio → send audio file)
              _buildOptionCard(
                context,
                icon: Icons.graphic_eq,
                title: 'Send Audio Wave',
                subtitle: 'Record audio → audio waveform emotion analysis',
                description:
                    'Sends the raw audio to HuggingFace to detect emotion from voice tone & pitch.',
                gradient: const [Color(0xFFE94560), Color(0xFF0F3460)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AudioEmotionScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
