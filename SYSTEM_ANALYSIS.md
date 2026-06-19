# Lexia — System Analysis & Source Code Documentation

**Project:** Godot 4.6 2D Dyslexia Gamification (Web/Chromium)
**Version:** 1.1 | **Export Preset Features:** `ocr, tts, stt`

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                 index.html                       │
│  ┌───────────────────────────────────────────┐  │
│  │  Engine Bootstrap (Godot WASM + PCK)      │  │
│  │  Service Worker · Cross-Origin Isolation  │  │
│  └───────────────────────────────────────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌────────────────┐  │
│  │ TTS      │ │ STT      │ │ Google Cloud   │  │
│  │ speakText│ │ WebSpeech│ │ Vision OCR     │  │
│  │ (JS API) │ │ API      │ │ (letter_recog.)│  │
│  └──────────┘ └──────────┘ └────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │  OAuth Token Capture (sessionStorage)     │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
         │  JavaScriptBridge.eval / engine.call
         ▼
┌─────────────────────────────────────────────────┐
│           Godot Engine (WASM Runtime)            │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │ Journey Mode │  │ Module Mode             │   │
│  │ RPG Battles  │  │ Phonics·Flip·Read-Aloud │   │
│  │ + Challenges │  │ + Progress Tracking     │   │
│  └─────────────┘  └─────────────────────────┘   │
│  ┌───────────────────────────────────────────┐  │
│  │ Auth: Firebase (Email/Google OAuth)       │  │
│  │ DB: Firestore (dyslexia_users collection) │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## 2. HTML5 Web Export (index.html)

### 2.1 Engine Bootstrap

The Godot engine boots via `index.wasm` + `index.pck` (87 MB). The `GODOT_CONFIG` object drives canvas sizing, threading, and service worker installation.

**Key excerpt (index.html):**
```js
const GODOT_CONFIG = {
  "args":[],"canvasResizePolicy":2,"executable":"index",
  "fileSizes":{"index.pck":87288728,"index.wasm":37024354},
  "serviceWorker":"index.service.worker.js",
  "ensureCrossOriginIsolationHeaders":true
};
const engine = new Engine(GODOT_CONFIG);

engine.startGame({
  'onProgress': function (current, total) {
    statusProgress.value = current;
    statusProgress.max = total;
  }
}).then(() => { setStatusMode('hidden'); }, displayFailureNotice);
```

**Platform detection in GDScript:**
```gdscript
# GoogleCloudVision.gd
if OS.has_feature("web"):
    JavaScriptBridge.eval("window.GOOGLE_CLOUD_API_KEY = '%s';" % api_key)
```

### 2.2 Cross-Origin Isolation & Auth

```html
<meta http-equiv="Cross-Origin-Embedder-Policy" content="require-corp" />
<meta http-equiv="Cross-Origin-Opener-Policy" content="same-origin" />
```

An **early-capture script** (runs before the engine loads) intercepts OAuth tokens from the URL hash/query and stores in `sessionStorage` to prevent token loss during Godot engine initialization.

---

## 3. Text-to-Speech (TTS)

### 3.1 JavaScript Bridge (index.html)

```js
window.speakText = function (text, voiceId, rate, volume) {
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = "en-US";
  utterance.rate = rate || 0.8;     // Slower rate for dyslexic users
  utterance.volume = volume !== undefined ? volume : 1.0;
  window.speechSynthesis.speak(utterance);
};

window.saveTTSSettings = function (voiceId, rate) {
  localStorage.setItem("tts_voice_id", voiceId);
  localStorage.setItem("tts_rate", rate);
};
```

The initialization sequence primes the speech system on first user click (many browsers block autoplay speech):

```js
document.addEventListener("click", function initAudio() {
  if (window.speechSynthesis) {
    const click = new SpeechSynthesisUtterance(".");
    click.volume = 0;
    window.speechSynthesis.speak(click);
    document.removeEventListener("click", initAudio);
  }
});
```

### 3.2 GDScript Controller (TextToSpeech.gd)

| Property     | Range   | Default | Source                          |
|-------------|---------|---------|---------------------------------|
| speech_rate  | 0.1-2.0 | 1.0     | SettingsManager accessibility   |
| speech_volume| 0.0-1.0 | 1.0     | SettingsManager accessibility   |
| speech_pitch | 0.5-2.0 | 1.0     | SettingsManager accessibility   |

**Web dispatch:**
```gdscript
func speak(text):
    if OS.has_feature("web"):
        var js_code = "window.speakText('" + text.replace("'", "\\'") + \
            "', '" + selected_voice_id + "', " + str(speech_rate) + \
            ", " + str(speech_volume) + ");"
        JavaScriptBridge.eval(js_code)
    else:
        DisplayServer.tts_speak(text, selected_voice_id, \
            int(speech_volume * 100), speech_pitch, speech_rate)
```

**Signals:** `speech_started`, `speech_finished`, `speech_ended`, `speech_error`, `voices_loaded`

---

## 4. Speech-to-Text (STT)

### 4.1 JavaScript Bridge (index.html)

The global `window.godot_speech` object holds state and manages the Web Speech API lifecycle:

```js
window.godot_speech = {
  mediaRecorder: null,
  audioChunks: [],
  recording: false,
  permissionState: "prompt",
  sensitivity: 1.0,
};
```

The `window.requestAudioPermission` helper requests high-quality audio:
```js
window.requestAudioPermission = function () {
  return navigator.mediaDevices.getUserMedia({
    audio: {
      echoCancellation: false,
      noiseSuppression: false,
      autoGainControl: true,
      sampleRate: 48000,
      channelCount: 1,
    },
  });
};
```

### 4.2 Web Speech Recognition (WordChallengePanel_STT.gd → JS eval)

The Godot script injects multi-line JavaScript into the browser via `JavaScriptBridge.eval()`:

```
┌─────────────────────────────────────────────────────────┐
│ WordChallengePanel_STT.gd                                │
│  _process(delta) polls for:                              │
│   • window.latestInterimResult (live display)            │
│   • window.latestFinalResult   (final match)             │
│                                                          │
│  _start_live_recognition() → injects JS:                 │
│   1. navigator.mediaDevices.getUserMedia(enhanced audio) │
│   2. new SpeechRecognition()                              │
│   3. recognition.continuous = true                        │
│   4. recognition.interimResults = true                    │
│   5. recognition.maxAlternatives = 10                     │
│   6. recognition.lang = 'en-US'                           │
│   7. onresult → store in window.latest*Result             │
│   8. onerror → engine.call speech_error_callback          │
│   9. onend  → engine.call recognition_ended_callback      │
└─────────────────────────────────────────────────────────┘
```

### 4.3 Phonetic & Dyslexia-Friendly Matching

The STT pipeline applies four matching stages:

| Stage | Criteria | Match Quality |
|-------|----------|--------------|
| 1. Exact | `recognized == target` | `perfect` |
| 2. Phonetic | Sound-alike substitution groups | `close` |
| 3. Word extraction | Best word from phrase via Levenshtein + phonetic | `perfect`/`close` |
| 4. Fuzzy | Similarity ≥ 75% (longer words) | `close` |

**Phonetic substitutions** (from `_apply_phonetic_improvements`):
```
ae↔ay, ee↔ea, oo↔ou, ph→f, th→t, c↔k, f↔v, b↔p
```

**Audio constraints for maximum sensitivity (dyslexic learners):**
```js
echoCancellation: false, noiseSuppression: false,
autoGainControl: true, sampleRate: 48000,
gain: 2.0, // Boost for quiet speakers
```

### 4.4 Live Transcription UI

The `_process_interim_transcription` function:
1. Extracts only the **last word** from the transcript (fixes "ore ore" duplication)
2. Applies phonetic improvements
3. Displays color-coded feedback:
   - **Green** `✓ Perfect!` — exact match
   - **Lime** `✓ Sounds right!` — phonetic match
   - **Yellow** `~ Close!` — near match
   - **White** `| word` — no match

---

## 5. Google Cloud Vision OCR

### 5.1 Pipeline

```
User draws → WhiteboardInterface exports canvas as PNG base64
    → JavaScript Bridge (letter_recognition.js)
    → Preprocess (grayscale, threshold=170, dilation)
    → Google Cloud Vision API (TEXT_DETECTION)
    → Post-process (fix confusions I→1, O→0)
    → Return text to Godot
```

### 5.2 GDScript Entry (GoogleCloudVision.gd)

```gdscript
func recognize_handwriting(image_data):
    if OS.has_feature("web"):
        _recognize_handwriting_web()
    else:
        emit_signal("recognition_error", "Web only")

func _recognize_handwriting_web():
    var js_code = """
    (async function() {
        const preprocessed = await window.preprocessHandwritingImage(%s, 1200, 900, true);
        const result = await window.callGoogleVisionApi(preprocessed, 'LETTER_MODE');
        return result;
    })();
    """ % base64_image
    var result = JavaScriptBridge.eval(js_code)
```

### 5.3 Image Preprocessing (letter_recognition.js)

Two-pass processing pipeline:

**Pass 1 — Binarization:**
```js
for (let i = 0; i < data.length; i += 4) {
  const luminance = 0.299*r + 0.587*g + 0.114*b;
  const threshold = 170;
  const value = luminance < threshold ? 0 : 255;
  data[i] = data[i+1] = data[i+2] = value;
}
```

**Pass 2 — Morphological Dilation:**
```js
function dilate(imageData, radius) {
  // For each pixel, find minimum value in neighborhood
  // (dilates black strokes to make them thicker)
  for (let dy = -radius; dy <= radius; dy++) {
    for (let dx = -radius; dx <= radius; dx++) {
      minValue = Math.min(minValue, data[nIdx]);
    }
  }
  result[idx] = minValue;
}
```

### 5.4 API Request & Post-Processing

```js
window.callGoogleVisionApi = async function(base64Image, mode = 'LETTER_MODE') {
  const response = await fetch(
    `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
    {
      method: 'POST',
      body: JSON.stringify({
        requests: [{
          image: { content: base64Image },
          features: [{ type: 'TEXT_DETECTION', maxResults: 10 }],
          imageContext: {
            languageHints: ['en'],
            textDetectionParams: { enableTextDetectionConfidenceScore: true }
          }
        }]
      })
    }
  );
};
```

**Post-processing** (`postProcessLetterResult`):
- Removes non-alphanumeric artifacts
- For multi-character results, extracts the first alphabetic character
- Returns uppercase single letter

### 5.5 Whiteboard Drawing (WhiteboardInterface.gd)

| Feature | Implementation |
|---------|---------------|
| Stroke capture | `_input(event)` → `_start_stroke` / `_add_point_to_stroke` / `_end_stroke` |
| Smooth rendering | `draw_line` with anti-aliasing + intermediate circles for continuity |
| Undo/Redo | `strokes` array with `undo_history` stack |
| Export | `SubViewport` renders strokes on white background → `get_image()` → `save_png_to_buffer()` → `raw_to_base64()` |
| Stroke width | **Battle mode:** 4.0px, **Module mode:** 8.0px |

The polling mechanism for OCR results uses a unique callback ID:
```gdscript
var unique_callback_id = str(randi())
# Store result in window.godot_ocr_results[id]
# Poll every 200ms, max 30 retries (6 seconds)
```

---

## 6. Data Flow Diagrams

### 6.1 TTS Flow

```
User taps "Read"
  → WordChallengePanel.gd
    → TextToSpeech.speak(text)
      → [Web] JavaScriptBridge.eval → window.speakText()
        → SpeechSynthesisUtterance → browser TTS engine
      → [Desktop] DisplayServer.tts_speak()
    → Timer estimates duration → emit speech_finished
  → Button resets to "Read"
```

### 6.2 STT Flow

```
User taps "Speak"
  → WordChallengePanel_STT.gd
    → _start_live_recognition()
      → JavaScriptBridge.eval (async IIFE)
        → getUserMedia(enhanced audio)
        → new SpeechRecognition()
        → recognition.start()
    → Poll every frame:
      window.latestInterimResult → live transcription display
      window.latestFinalResult   → _on_speech_recognized()
        → Phonetic pipeline (4 stages)
        → BonusDamageCalculator.calculate()
        → Show ChallengeResultPanels.tscn
```

### 6.3 OCR Flow

```
User draws → taps "Done"
  → WhiteboardInterface.gd
    → export_and_recognize_drawing()
      → SubViewport render → PNG buffer → base64
      → process_image_with_javascript(base64, w, h)
        → JavaScriptBridge.eval
          → window.preprocessHandwritingImage()
            (grayscale + threshold + dilation)
          → window.callGoogleVisionApi()
            (TEXT_DETECTION → LETTER_MODE)
          → postProcessLetterResult()
        → Poll window.godot_ocr_results[id]
      → _on_recognition_completed(text)
        → WordChallengePanel_Whiteboard.gd
          → calculate_improved_word_similarity()
          → BonusDamageCalculator.calculate()
          → Show ChallengeResultPanels.tscn
```

---

## 7. Key Accessibility Features

| Feature | Implementation | Rationale |
|---------|---------------|-----------|
| OpenDyslexic font | Custom font asset + theme overrides | Dyslexia-optimized typeface |
| Slower TTS rate | Default 0.8x, configurable 0.1–2.0 | Processing time for dyslexic learners |
| Phonetic matching | Sound-alike groups (ae↔ay, ph→f, etc.) | Recognizes pronunciation variations |
| Dyslexic letter swaps | b↔d, p↔q, m↔w in similarity calc | Common letter confusion tolerance |
| No emoji export | Project convention | Web export compatibility |
| High STT sensitivity | gain: 2.0, no noise suppression | Quieter/dyslexic speech pickup |
| OCR stroke dilation | Morphological dilation on handwritten input | Reduces I→1, O→0 confusions |

---

## 8. Firebase Integration

- **Auth:** Email/Password + Google OAuth (implicit flow via URL hash)
- **OAuth token capture:** Early JS script stores token in `sessionStorage` before Godot loads
- **Firestore collection:** `dyslexia_users` with nested documents for profiles, stats, dungeons, modules
- **Plugin:** `addons/godot-firebase` (custom GDScript Firebase SDK)
- **Autoloads:** `Firebase` (auth/db), `DungeonGlobals`, `SettingsManager`, `BackgroundMusicManager`

---

## 9. Export Configuration

| Preset | Platform | Path | Features |
|--------|----------|------|----------|
| Web (runnable) | HTML5 | `WebTest/index.html` | `ocr, tts, stt` |
| Windows Desktop | Windows | `StandaloneTest/index.exe` | — |
| Android | Android | (not set) | — |

The custom HTML shell in the web export includes `letter_recognition.js`, OAuth capture, speech recognition, Vision API integration, and PWA support (service worker + manifest).
