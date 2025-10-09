# WEB PERFORMANCE TEST DOCUMENT

**Application/System Name:** Lexia: Dyslexia Gamification Learning Platform (Web-Based Educational Tool)

**Test Cycle No.:** 1

**Date Tested:** October 9, 2025

**Pre-condition:** Chrome, Edge, Brave (Chromium-Based) Browsers

**Used Tool(s):** Chrome DevTools & Lighthouse

**Framework:** Godot Engine 4.4.5 (HTML5/WebAssembly Export)

**Prepared By:** Harold F. Pasion

**Administered/Performed By:** Harold F. Pasion

---

## Application Overview

Lexia is an educational web application designed specifically for dyslexic learners, featuring:

- **Journey Mode**: RPG-style turn-based battles with word challenges (STT/Whiteboard)
- **Module Mode**: Direct educational activities (Phonics, Flip Quiz, Read-Aloud)
- **Firebase Integration**: Real-time authentication and progress tracking
- **Accessibility Features**: Dyslexia-friendly fonts, TTS, STT, visual learning aids
- **Multisensory Learning**: Hear, see, say, and do - targeting phonological processing

---

## Module: Splash Screen & Initial Load

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)         | TBT (ms)       | CLS             |
| ------------------------- | ----------------- | --------------- | --------------- | --------------- | -------------- | --------------- |
| 1                         | 96                | 0.8             | 0.3             | 0.6             | 32             | 0               |
| 2                         | 95                | 0.9             | 0.3             | 0.7             | 38             | 0.003           |
| 3                         | 95                | 0.8             | 0.3             | 0.7             | 35             | 0.002           |
| 4                         | 95                | 0.8             | 0.3             | 0.6             | 34             | 0.001           |
| 5                         | 95                | 0.8             | 0.2             | 0.7             | 36             | 0.004           |
| **Overall Average** | **95.2**    | **0.82s** | **0.28s** | **0.65s** | **35ms** | **0.002** |

**Note:** Initial WASM (36.5MB) + PCK (89.3MB) = 126MB total download. Service worker caching ensures instant subsequent loads.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Authentication (Login/Register)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)         | TBT (ms)       | CLS             |
| ------------------------- | ----------------- | --------------- | --------------- | --------------- | -------------- | --------------- |
| 1                         | 98                | 0.7             | 0.2             | 0.5             | 25             | 0               |
| 2                         | 97                | 0.8             | 0.3             | 0.5             | 28             | 0.001           |
| 3                         | 97                | 0.7             | 0.2             | 0.5             | 30             | 0.002           |
| 4                         | 98                | 0.7             | 0.3             | 0.6             | 26             | 0.001           |
| 5                         | 97                | 0.8             | 0.2             | 0.5             | 31             | 0.001           |
| **Overall Average** | **97.4**    | **0.74s** | **0.24s** | **0.52s** | **28ms** | **0.001** |

**Note:** OR-logic password validation, OAuth token capture, Firebase authentication (180-350ms response time).

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Main Menu Scene

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)         | TBT (ms)       | CLS             |
| ------------------------- | ----------------- | --------------- | --------------- | --------------- | -------------- | --------------- |
| 1                         | 97                | 0.8             | 0.3             | 0.6             | 30             | 0.003           |
| 2                         | 97                | 0.8             | 0.3             | 0.6             | 32             | 0.003           |
| 3                         | 97                | 0.8             | 0.2             | 0.6             | 34             | 0.004           |
| 4                         | 96                | 0.8             | 0.3             | 0.6             | 31             | 0.002           |
| 5                         | 97                | 0.7             | 0.2             | 0.6             | 33             | 0.003           |
| **Overall Average** | **96.8**    | **0.78s** | **0.26s** | **0.58s** | **32ms** | **0.003** |

**Note:** Smooth fade transitions (400ms), instant UI responsiveness. Supports Journey Mode, Module Mode, Profile, Settings, Leaderboard, and Character Customization navigation.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Profile & Settings

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)        | TBT (ms)         | CLS         |
| ------------------------- | ----------------- | --------------- | --------------- | -------------- | ---------------- | ----------- |
| 1                         | 95                | 0.8             | 0.3             | 0.6            | 28               | 0           |
| 2                         | 95                | 0.8             | 0.3             | 0.6            | 30               | 0           |
| 3                         | 94                | 0.9             | 0.3             | 0.6            | 35               | 0           |
| 4                         | 95                | 0.8             | 0.3             | 0.6            | 29               | 0           |
| 5                         | 94                | 0.9             | 0.2             | 0.6            | 32               | 0           |
| **Overall Average** | **94.6**    | **0.84s** | **0.28s** | **0.6s** | **30.8ms** | **0** |

**Note:** Profile data loading: 220-380ms (Firebase), TTS voice loading: 150-300ms (browser-dependent), Settings persistence via localStorage.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Dungeon Selection (Journey Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)         | TBT (ms)       | CLS             |
| ------------------------- | ----------------- | --------------- | --------------- | --------------- | -------------- | --------------- |
| 1                         | 96                | 0.8             | 0.3             | 0.6             | 36             | 0.004           |
| 2                         | 96                | 0.8             | 0.2             | 0.6             | 40             | 0.005           |
| 3                         | 96                | 0.8             | 0.3             | 0.6             | 38             | 0.003           |
| 4                         | 97                | 0.8             | 0.2             | 0.6             | 37             | 0.004           |
| 5                         | 96                | 0.8             | 0.3             | 0.6             | 39             | 0.004           |
| **Overall Average** | **96.2**    | **0.8s**  | **0.25s** | **0.61s** | **38ms** | **0.004** |

**Note:** Displays stage progress with semi-transparent completed icons. Progress data load: 220-380ms (Firebase).

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Dungeon Map Navigation (Journey Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)         | TBT (ms)       | CLS         |
| ------------------------- | ----------------- | --------------- | --------------- | --------------- | -------------- | ----------- |
| 1                         | 96                | 0.9             | 0.3             | 0.7             | 40             | 0           |
| 2                         | 96                | 0.9             | 0.3             | 0.7             | 44             | 0           |
| 3                         | 95                | 0.9             | 0.3             | 0.7             | 42             | 0           |
| 4                         | 96                | 0.9             | 0.2             | 0.7             | 41             | 0           |
| 5                         | 96                | 0.9             | 0.3             | 0.7             | 43             | 0           |
| **Overall Average** | **95.8**    | **0.9s**  | **0.27s** | **0.68s** | **42ms** | **0** |

**Note:** Energy consumption validation (2 energy per battle), stage completion tracking, boss stage identification.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Battle Scene (Journey Mode RPG System)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)         | TBT (ms)       | CLS             |
| ------------------------- | ----------------- | --------------- | --------------- | --------------- | -------------- | --------------- |
| 1                         | 94                | 1.1             | 0.3             | 0.8             | 65             | 0.012           |
| 2                         | 93                | 1.2             | 0.3             | 0.9             | 70             | 0.011           |
| 3                         | 93                | 1.1             | 0.3             | 0.8             | 68             | 0.013           |
| 4                         | 94                | 1.1             | 0.3             | 0.8             | 66             | 0.012           |
| 5                         | 93                | 1.1             | 0.4             | 0.9             | 71             | 0.012           |
| **Overall Average** | **93.4**    | **1.12s** | **0.32s** | **0.84s** | **68ms** | **0.012** |

**Note:** Firebase player stats load: 280-520ms, Enemy resource load: 180-340ms. Manager-based architecture: BattleManager, EnemyManager, PlayerManager, UIManager, ChallengeManager, DungeonManager. Turn execution: 800-1200ms per action.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: STT Word Challenge (Journey Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)        | LCP (s)        | TBT (ms)         | CLS             |
| ------------------------- | ----------------- | --------------- | -------------- | -------------- | ---------------- | --------------- |
| 1                         | 92                | 1.0             | 0.3            | 0.7            | 55               | 0.008           |
| 2                         | 92                | 1.0             | 0.3            | 0.7            | 58               | 0.009           |
| 3                         | 91                | 1.1             | 0.3            | 0.7            | 60               | 0.008           |
| 4                         | 92                | 1.0             | 0.3            | 0.7            | 56               | 0.007           |
| 5                         | 92                | 1.0             | 0.3            | 0.7            | 59               | 0.008           |
| **Overall Average** | **91.8**    | **1.02s** | **0.3s** | **0.7s** | **57.6ms** | **0.008** |

**Note:** Web Speech API recognition: 800-2500ms (variable). Fuzzy matching with 70% Levenshtein threshold. High sensitivity audio: 48kHz sample rate, echo cancellation OFF, noise suppression OFF.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Whiteboard Challenge (Journey Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)        | LCP (s)        | TBT (ms)       | CLS             |
| ------------------------- | ----------------- | --------------- | -------------- | -------------- | -------------- | --------------- |
| 1                         | 90                | 1.1             | 0.3            | 0.8            | 62             | 0.010           |
| 2                         | 89                | 1.2             | 0.3            | 0.8            | 68             | 0.011           |
| 3                         | 89                | 1.2             | 0.3            | 0.8            | 65             | 0.010           |
| 4                         | 89                | 1.2             | 0.3            | 0.8            | 64             | 0.009           |
| 5                         | 89                | 1.2             | 0.3            | 0.8            | 66             | 0.010           |
| **Overall Average** | **89.2**    | **1.18s** | **0.3s** | **0.8s** | **65ms** | **0.010** |

**Note:** Drawing responsiveness: 16-32ms (60fps). Google Cloud Vision API: 1.5-3.5s total (includes preprocessing 400-800ms + network call 800-2500ms). DOCUMENT_TEXT_DETECTION + TEXT_DETECTION for accuracy.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Module Selection Scene

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)         | TBT (ms)       | CLS             |
| ------------------------- | ----------------- | --------------- | --------------- | --------------- | -------------- | --------------- |
| 1                         | 97                | 0.8             | 0.3             | 0.6             | 32             | 0.003           |
| 2                         | 96                | 0.8             | 0.3             | 0.6             | 35             | 0.003           |
| 3                         | 96                | 0.8             | 0.2             | 0.6             | 34             | 0.003           |
| 4                         | 97                | 0.8             | 0.3             | 0.6             | 33             | 0.003           |
| 5                         | 96                | 0.8             | 0.3             | 0.6             | 36             | 0.003           |
| **Overall Average** | **96.4**    | **0.8s**  | **0.26s** | **0.59s** | **34ms** | **0.003** |

**Note:** Displays 3 modules: Phonics Interactive, Flip Practice, Interactive Read-Aloud. Module progress load: 220-380ms (Firebase).

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Phonics Letters (Module Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)         | TBT (ms)       | CLS              |
| ------------------------- | ----------------- | --------------- | --------------- | --------------- | -------------- | ---------------- |
| 1                         | 95                | 0.9             | 0.3             | 0.7             | 46             | 0.005            |
| 2                         | 95                | 0.9             | 0.3             | 0.7             | 49             | 0.006            |
| 3                         | 94                | 0.9             | 0.3             | 0.7             | 48             | 0.005            |
| 4                         | 95                | 0.9             | 0.3             | 0.7             | 47             | 0.005            |
| 5                         | 94                | 0.9             | 0.3             | 0.8             | 50             | 0.006            |
| **Overall Average** | **94.6**    | **0.9s**  | **0.29s** | **0.72s** | **48ms** | **0.0054** |

**Note:** Guided tracing with accurate arrow curves (0.3-0.5 range for C, J, O, G, Q, S). Real-time stroke validation at 60fps (16-32ms). TTS playback: 150-300ms.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Phonics Sight Words (Module Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)         | LCP (s)        | TBT (ms)       | CLS             |
| ------------------------- | ----------------- | --------------- | --------------- | -------------- | -------------- | --------------- |
| 1                         | 96                | 0.8             | 0.3             | 0.7            | 42             | 0.004           |
| 2                         | 96                | 0.9             | 0.3             | 0.7            | 44             | 0.004           |
| 3                         | 95                | 0.9             | 0.3             | 0.7            | 45             | 0.004           |
| 4                         | 96                | 0.8             | 0.3             | 0.7            | 43             | 0.003           |
| 5                         | 96                | 0.9             | 0.2             | 0.7            | 46             | 0.005           |
| **Overall Average** | **95.8**    | **0.86s** | **0.28s** | **0.7s** | **44ms** | **0.004** |

**Note:** 20 high-frequency sight words. Tap-to-hear functionality, visual highlighting, OpenDyslexic font. Progress tracking per word (Firebase: 180-350ms).

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Flip Quiz Animals (Module Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)        | LCP (s)         | TBT (ms)       | CLS              |
| ------------------------- | ----------------- | --------------- | -------------- | --------------- | -------------- | ---------------- |
| 1                         | 95                | 0.9             | 0.3            | 0.7             | 48             | 0.006            |
| 2                         | 94                | 1.0             | 0.3            | 0.7             | 52             | 0.006            |
| 3                         | 94                | 1.0             | 0.3            | 0.7             | 50             | 0.005            |
| 4                         | 94                | 1.0             | 0.3            | 0.7             | 49             | 0.006            |
| 5                         | 94                | 1.0             | 0.3            | 0.8             | 51             | 0.006            |
| **Overall Average** | **94.2**    | **0.98s** | **0.3s** | **0.74s** | **50ms** | **0.0058** |

**Note:** Card flip animation: 300-400ms. Animal images: 120-280ms load time. TTS word playback: 150-300ms. Match detection: <10ms.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Flip Quiz Vehicles (Module Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)        | LCP (s)        | TBT (ms)       | CLS              |
| ------------------------- | ----------------- | --------------- | -------------- | -------------- | -------------- | ---------------- |
| 1                         | 95                | 0.9             | 0.3            | 0.7            | 46             | 0.005            |
| 2                         | 94                | 1.0             | 0.3            | 0.7            | 50             | 0.006            |
| 3                         | 94                | 1.0             | 0.3            | 0.7            | 48             | 0.005            |
| 4                         | 94                | 1.0             | 0.3            | 0.7            | 47             | 0.005            |
| 5                         | 95                | 0.9             | 0.3            | 0.7            | 49             | 0.006            |
| **Overall Average** | **94.4**    | **0.96s** | **0.3s** | **0.7s** | **48ms** | **0.0054** |

**Note:** Card flip animation: 300-400ms. Vehicle images: 115-260ms load time. Performance consistent with Animals module.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Syllable Building (Module Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)        | LCP (s)        | TBT (ms)       | CLS             |
| ------------------------- | ----------------- | --------------- | -------------- | -------------- | -------------- | --------------- |
| 1                         | 93                | 1.0             | 0.3            | 0.8            | 55             | 0.008           |
| 2                         | 93                | 1.1             | 0.3            | 0.8            | 58             | 0.009           |
| 3                         | 92                | 1.1             | 0.3            | 0.8            | 57             | 0.008           |
| 4                         | 93                | 1.0             | 0.3            | 0.8            | 56             | 0.007           |
| 5                         | 93                | 1.1             | 0.3            | 0.8            | 59             | 0.008           |
| **Overall Average** | **92.8**    | **1.06s** | **0.3s** | **0.8s** | **57ms** | **0.008** |

**Note:** Drag-and-drop syllable tiles, STT recognition: 800-2500ms (variable), tile interaction: <16ms (60fps). Visual color coding for closed syllables.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Guided Reading (Module Mode)

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)        | LCP (s)        | TBT (ms)       | CLS              |
| ------------------------- | ----------------- | --------------- | -------------- | -------------- | -------------- | ---------------- |
| 1                         | 94                | 1.0             | 0.3            | 0.8            | 52             | 0.007            |
| 2                         | 94                | 1.0             | 0.3            | 0.8            | 55             | 0.008            |
| 3                         | 93                | 1.1             | 0.3            | 0.8            | 54             | 0.007            |
| 4                         | 94                | 1.0             | 0.3            | 0.8            | 53             | 0.007            |
| 5                         | 93                | 1.1             | 0.3            | 0.8            | 56             | 0.008            |
| **Overall Average** | **93.6**    | **1.04s** | **0.3s** | **0.8s** | **54ms** | **0.0074** |

**Note:** Adjustable reading speed (80-180 WPM). Text highlighting: <50ms. TTS sentence playback: 200-400ms. STT continuous mode: 800-3000ms. Focus mode with dimmed inactive lines.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Leaderboard

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)        | LCP (s)        | TBT (ms)       | CLS              |
| ------------------------- | ----------------- | --------------- | -------------- | -------------- | -------------- | ---------------- |
| 1                         | 95                | 0.9             | 0.3            | 0.7            | 40             | 0.005            |
| 2                         | 94                | 0.9             | 0.3            | 0.7            | 43             | 0.006            |
| 3                         | 94                | 1.0             | 0.3            | 0.7            | 42             | 0.005            |
| 4                         | 95                | 0.9             | 0.3            | 0.7            | 41             | 0.005            |
| 5                         | 94                | 1.0             | 0.3            | 0.7            | 44             | 0.006            |
| **Overall Average** | **94.4**    | **0.94s** | **0.3s** | **0.7s** | **42ms** | **0.0054** |

**Note:** Firebase Firestore query for leaderboard data: 180-450ms. Displays player rankings, levels, and progress.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion

---

## Module: Character Customization

### Web Vitals Results

| Execution Run             | Performance Score | Speed Index (s) | FCP (s)        | LCP (s)        | TBT (ms)       | CLS              |
| ------------------------- | ----------------- | --------------- | -------------- | -------------- | -------------- | ---------------- |
| 1                         | 95                | 0.9             | 0.3            | 0.7            | 38             | 0.004            |
| 2                         | 95                | 0.9             | 0.3            | 0.7            | 40             | 0.005            |
| 3                         | 94                | 0.9             | 0.3            | 0.7            | 42             | 0.004            |
| 4                         | 95                | 0.9             | 0.3            | 0.7            | 39             | 0.004            |
| 5                         | 95                | 0.9             | 0.3            | 0.7            | 41             | 0.005            |
| **Overall Average** | **94.8**    | **0.9s**  | **0.3s** | **0.7s** | **40ms** | **0.0044** |

**Note:** Character selection (Lexia/Ragna), profile picture popup, Firebase save: 200-480ms.

**Prepared By:** Harold F. Pasion
**Administered/Performed By:** Harold F. Pasion
