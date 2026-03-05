class EmotionResult {
  final String label;
  final double score;

  EmotionResult({required this.label, required this.score});

  factory EmotionResult.fromJson(Map<String, dynamic> json) {
    return EmotionResult(
      label: json['label'] as String,
      score: (json['score'] as num).toDouble(),
    );
  }

  String get emoji {
    switch (label.toLowerCase()) {
      case 'joy' || 'happy' || 'hap':
        return '😊';
      case 'sadness' || 'sad':
        return '😢';
      case 'anger' || 'angry' || 'ang':
        return '😠';
      case 'neutral' || 'neu':
        return '😐';
      case 'fear' || 'fearful' || 'fea':
        return '😨';
      case 'disgust' || 'disgusted' || 'dis':
        return '🤢';
      case 'surprise' || 'surprised' || 'sur':
        return '😲';
      case 'calm' || 'cal':
        return '😌';
      default:
        return '🎭';
    }
  }

  String get percentage => '${(score * 100).toStringAsFixed(1)}%';
}
