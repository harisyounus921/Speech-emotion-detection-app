# Speech Analyze

A Flutter app that detects **emotions from speech** using the [HuggingFace Inference API](https://huggingface.co/docs/api-inference/).

Record your voice and get real-time emotion classification (happy, sad, angry, neutral, fearful, disgusted, surprised, calm) with confidence scores.

## Features

- 🎤 **Audio Recording** — Record speech directly from the app
- 🧠 **Emotion Detection** — Classify emotions using the `wav2vec2-lg-xlsr-en-speech-emotion-recognition` model
- 📊 **Confidence Scores** — See percentage breakdown for all detected emotions
- 🔄 **Auto-Retry** — Handles HuggingFace model cold starts automatically

## Project Structure

```
lib/
├── main.dart                       # App entry point, loads .env
├── models/
│   └── emotion_result.dart         # Emotion data model with emoji mapping
├── screens/
│   └── emotion_screen.dart         # Recording UI + results display
└── services/
    └── emotion_service.dart        # HuggingFace API integration
```

## Setup

### 1. Get a HuggingFace API Key

1. Go to [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
2. Create a new **Read** token
3. Copy the token (starts with `hf_...`)

### 2. Configure Environment

Create a `.env` file in the project root:

```
HF_API_KEY=hf_your_token_here
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

```bash
flutter run
```

> **Note:** Use a **physical device** for testing. Simulators/emulators may not provide real microphone access.

## How It Works

1. User taps the mic button and speaks for 2–5 seconds
2. Audio is recorded as WAV (16kHz, mono)
3. The WAV file is sent to HuggingFace's Inference API
4. The `wav2vec2` model classifies the emotion
5. Results are displayed with emoji, labels, and confidence bars

## API & Model

- **API:** [HuggingFace Inference API](https://huggingface.co/docs/api-inference/)
- **Model:** [ehcalabres/wav2vec2-lg-xlsr-en-speech-emotion-recognition](https://huggingface.co/ehcalabres/wav2vec2-lg-xlsr-en-speech-emotion-recognition)
- **Cost:** Free tier (~30,000 requests/month)

## Notes

- The **first API call** may take 20–30 seconds while HuggingFace loads the model (cold start). Subsequent calls are fast (~2–3s).
- Audio is recorded in **WAV format at 16kHz mono**, which is what the model expects.
- The `.env` file is excluded from version control via `.gitignore`.
