## Project Overview

This is a Godot 4.4.5 2D web-based educational gamification designed for dyslexic learners with **two distinct core modes**:

1. **Journey Mode**: RPG-style axie inifinity like but in auto turn base battles with STT/Whiteboard word challenges, dungeon progression, and automatic player stats
2. **Module Mode**: Direct educational activities (Phonics, Flip Quiz, Read-Aloud.) with Firebase progress tracking

The architecture uses manager-based patterns for Journey Mode and ModuleProgress.gd for Module Mode persistence.

## Core Game Architecture

### Two-Mode System Design

**Journey Mode** (`Scenes/BattleScene.tscn`, `Scenes/Dungeon*Map.tscn`):

- RPG battles with turn-based combat against fantasy enemies
- Word challenges (STT/Whiteboard) determine battle outcomes
- Progressive difficulty: 3→4→5 letter words across 3 dungeons
- Player leveling, equipment, energy system
- Manager-based battle system in `Scripts/Manager/`

**Module Mode** (`Scenes/ModuleScene.tscn`, `Scenes/Phonics*.tscn`):

- Direct educational activities without RPG elements
- Phonics (letters/sight words), Flip Quiz, Read-Aloud, Chunked Reading
- Progress tracked via `ModuleProgress.gd` with Firebase persistence
- UI-focused with immediate educational feedback

### Navigation Flow

```
MainMenu.tscn
├── Journey Mode → DungeonSelection.tscn → Dungeon*Map.tscn → BattleScene.tscn
└── Module Mode → ModuleScene.tscn → [Phonics|FlipQuiz|ReadAloud]Module.tscn
```

## Journey Mode Architecture

### Manager-Based Battle System

The core battle system uses a decoupled manager pattern in `Scripts/JourneyManager/`:

- **BattleManager**: Victory/defeat flow, Firebase progression, endgame routing
- **BonusDamageCalculator**: Centralize bonus damage of player counter to enemy through whiteboard or speect to text
- **EnemyManager**: Dynamic enemy scaling, resource loading, animation setup
- **PlayerManager**: Experience, leveling, stats, Firebase stat persistence
- **ChallengeManager**: STT/Whiteboard word challenges, UI cleanup, signal coordination
- **UIManager**: Health bars, player info, stage displays, background management
- **DungeonManager**: Stage progression, global state coordination

Each manager takes `battle_scene` reference in constructor: `var manager = ManagerScript.new(self)`

### Progressive Difficulty System

Word challenges scale with dungeon progression:

- **Dungeon 1**: 3-letter words (`sp=???` in Datamuse API but for now we use coded words)
- **Dungeon 2**: 4-letter words (`sp=????` in Datamuse API but for now we use coded words)
- **Dungeon 3**: 5-letter words (`sp=?????` in Datamuse API but for now we use coded words)

Implement via `_get_word_length_for_dungeon()` in challenge panels and `RandomWordAPI.fetch_random_word(word_length)`.

### Firebase Integration Patterns

Always use document retrieval → field update → collection.update() pattern:

```gdscript
var user_doc = await collection.get_doc(user_id)
user_doc.add_or_update_field("field_name", value)
var updated_doc = await collection.update(user_doc)
```

Player stats updated by `PlayerManager`, progression by `BattleManager` - never mix responsibilities.

## Module Mode Architecture

### ModuleProgress.gd Pattern

All educational progress in Module Mode flows through `Scripts/ModulesManager/ModuleProgress.gd`:

```gdscript
# Letter completion example
var save_success = await module_progress.set_phonics_letter_completed("A")
if save_success:
    var phonics_progress = await module_progress.get_phonics_progress()
    _update_progress_ui(phonics_progress.get("progress", 0))
```

### Module Structure Convention

Each module scene follows this pattern:

- Initialize `ModuleProgress.new()` in `_init_module_progress()`
- Load current progress in `_load_progress()`
- Update progress bars/labels via `_update_progress_ui(percent)`
- Save completion via specific ModuleProgress methods (e.g., `set_phonics_letter_completed()`)

### Firebase Document Schema

Module progress stored under `dyslexia_users/{user_id}/modules`:

```
modules: {
  phonics: {
    progress: 0-100,
    completed: boolean,
    letters_completed: ["A", "B", ...],
    sight_words_completed: ["the", "and", ...]
  },
  flip_quiz: { progress: 0-100, sets_completed: [...] },
  // ... other modules
}
```

## Key Development Patterns

### Cross-Mode Communication

**Journey Mode** and **Module Mode** are separate systems that share:

- Firebase user authentication (`Firebase.Auth.auth.localid`)
- User document structure in `dyslexia_users` collection
- Common UI patterns (fade transitions, TTS, accessibility)

**Never mix Journey Mode managers with Module Mode progress** - they operate in different contexts.

### Signal-Driven Architecture (Journey Mode Only)

Managers communicate via signals, not direct method calls:

- `enemy_defeated(exp_reward)` → triggers victory flow
- `challenge_completed(bonus_damage)` → applies counter-attack damage
- Connect signals in `battlescene.gd` `_connect_signals()` method

### Scene Transitions & State Management

**Journey Mode**: Uses `DungeonGlobals` autoload for immediate scene data transfer:

```gdscript
DungeonGlobals.set_battle_progress(dungeon_num, stage_num)
```

**Module Mode**: Direct scene changes with fade transitions:

```gdscript
get_tree().change_scene_to_file("res://Scenes/PhonicsModule.tscn")
```

### Progress Update Patterns

**Journey Mode**: Stats and dungeon progression via managers
**Module Mode**: Educational progress via ModuleProgress async methods

```gdscript
# Module Mode - Always await Firebase operations
var firebase_modules = await module_progress.fetch_modules()
var success = await module_progress.set_phonics_letter_completed(letter)
```

### Challenge System Implementation (Journey Mode Only)

STT/Whiteboard challenges follow this flow:

1. `trigger_enemy_skill()` → `challenge_manager.start_word_challenge(type)`
2. Word fetched via `RandomWordAPI.fetch_random_word(dungeon_word_length)`
3. Recognition results processed with dyslexia-friendly fuzzy matching
4. Success grants bonus damage, failure/cancellation applies enemy skill damage
5. `_cleanup_challenge()` removes overlays to prevent EndgameScreen blocking

### Web Platform Specifics

**Both Modes** use web-compatible approaches:

For Google Cloud integration (Whiteboard Cloud Vision API):

- Use Google Cloud Documentation but through HTTP way

For JavaScript integration (STT):

- Use `JavaScriptBridge.eval()` for all web audio operations
- Implement polling mechanism in `_process()` for async speech results
- Handle microphone permissions gracefully with user-initiated requests
- Web Speech API integration

## Development Guidelines by Mode

### Journey Mode Development

- Always use manager pattern for battle logic
- Test challenge UI cleanup with rapid enemy defeats
- Validate manager initialization in `battlescene.gd` `_ready()`
- Use signal connections for manager communication

### Module Mode Development

- Always initialize `ModuleProgress.new()` for Firebase operations
- Test progress bar updates after completing letters/words
- Use `await` for all ModuleProgress async methods
- Verify Firestore document structure matches expected schema

## File Organization by Mode

**Journey Mode**:

- `/Scripts/Manager/`: Core battle system managers
- `/Scripts/dungeon_*_map.gd`: Dungeon selection and stage logic
- `/Scripts/battlescene.gd`: Main battle coordinator
- `/Resources/Enemies/`: Enemy data resources (.tres files)

**Module Mode**:

ModuleScene.tscn (3 modules for now)
├── PhonicsModule.tscn → PhonicsLetters.tscn + PhonicsSightWords.tscn
├── FlipQuizModule.tscn → FlipQuizAnimals.tscn + FlipQuizVehicle.tscn
├── ReadAloudModule.tscn → SyllableBuildingModule.tscn + ReadAloudGuided.tscn

- `/Scripts/ModulesManager/ModuleProgress.gd`: Central progress persistence

**Shared**:

- `/Scripts/authentication.gd`: User login/signup for both modes
- `/Scripts/DungeonGlobals.gd`: Global state (mainly Journey Mode)
- `/Scripts/SettingsManager.gd`: User preferences
- `/Scenes/`: All game scenes (.tscn files)
- `/gui/`: UI assets and backgrounds

## Testing & Debugging

**Journey Mode**:

- Use `print()` statements liberally for async operations in managers
- Check Firebase responses with `("error" in document.keys())` pattern
- Validate manager initialization in `battlescene.gd` `_ready()`
- Test challenge UI cleanup with rapid enemy defeats

**Module Mode**:

- Check ModuleProgress debug logs in visual studio code output console
- Test progress bar updates after completing letters/sight words
- Verify Firebase authentication with `ModuleProgress.is_authenticated()`
- Ensure progress percentages calculate correctly (letters + sight words / 46 \* 100)

## Important Godot Conventions

- **Always use tab indentation** as space indentation causes errors
- **VS Code setup**: Ensure proper connection to Godot as scripts are edited externally
- **Async patterns**: Always use `await` for Firebase operations in both modes
- **No emojis**: Dyslexia font doesn't support emojis when exported to web

When working on this codebase, always consider dyslexic users' needs: readable fonts, forgiving word matching, clear feedback, and progressive difficulty scaling.

---

## Recent Implementations & Working Conventions

### Journey Mode Implementations

The following reflect the current, working behavior in the codebase and must be preserved in future edits:

- Challenge fail/cancel always uses enemy “skill” flow

  - On failed or cancelled word challenge, enemy plays the skill animation and applies damage at a timed impact point, then returns to original position.
  - Skill SFX plays during this flow; if no skill animation exists, falls back cleanly (timed damage + indicator + fallback SFX).
  - Skill meter resets after the skill. Challenge overlays and result panels are always cleaned up to prevent EndgameScreen blocking.

- Animation and SFX system (robust, name-based)

  - EnemyManager locates AnimatedSprite2D or AnimationPlayer dynamically and plays animations via helpers; resets to "idle" afterward.
  - SFX playback uses a resilient lookup under the enemy animation tree. Naming for enemies: [enemy]\_autoattack, [enemy]\_skill, [enemy]\_hurt; optional [enemy]\_dead.
  - Auto-attack SFX is triggered both from EnemyManager.attack and at the start of BattleManager.enemy_attack to ensure reliability.
  - Lethal hits on enemies play hurt SFX first, then dead SFX if present (graceful if missing). Player hurt SFX plays on any damage, including lethal.
  - Player SFX names in Lexia_Animation.tscn or Ragna_Animation.tscn: sfx_autoattack, sfx_counter, player_hurt.

- UI/UX behavior guarantees

  - Popups follow fade-in/out patterns. Background click-to-close is supported on settings and notification popups.
  - Only the Engage button starts battles; misconnected container signals are guarded. Engage/Leave are TSCN-based textured buttons.
  - Data section scoping fixes prevent unintended visibility or signal crashes.

- Energy consumption and notifications

  - Starting a battle consumes 2 energy using the Firebase pattern: get_doc → add_or_update_field → update().
  - If insufficient energy, a NotificationPopUp shows current/maximum energy and recovery info; no battle starts.

- Dungeon/stage progress UI

  - Completed stage enemy head icons are semi-transparent to indicate progress while maintaining layout and overlays.
  - Boss victory routes to DungeonSelection; regular stages advance sequentially.

### Module Mode Implementations

- Progress persistence pattern

  - All module progress flows through `ModuleProgress.gd` with async Firebase operations
  - Progress calculated as: `(letters_completed.size() + sight_words_completed.size()) / 46.0 * 100`
  - Progress bars update immediately after successful Firebase saves

- UI refresh system

  - Progress displays refresh on window focus (`NOTIFICATION_WM_WINDOW_FOCUS_IN`)
  - Real-time updates after letter/sight word completion
  - Fallback to local session tracking when Firebase unavailable

- Authentication integration

  - Modules check `Engine.has_singleton("Firebase")` before initializing ModuleProgress
  - User authentication status verified via `ModuleProgress.is_authenticated()`
  - Graceful degradation when offline or unauthenticated

## Audio/SFX Conventions (Journey Mode)

- Enemy SFX node naming inside Sprites/Animation scenes:

  - [enemy]\_autoattack → normal attacks
  - [enemy]\_skill → skill usage, including challenge fail/cancel flows
  - [enemy]\_hurt → when taking damage; also plays on lethal before optional [enemy]\_dead
  - [enemy]\_dead (optional) → plays after hurt on lethal if present

- Player SFX nodes:

  - sfx_autoattack_swordslash, sfx_counter_swordslash, player_hurt, etc

- Playback rules:

  - Enemy auto-attack SFX is triggered in both EnemyManager.attack and BattleManager.enemy_attack for reliability.
  - Challenge fail/cancel triggers enemy skill SFX; fallback uses auto-attack SFX if needed.
  - On lethal to enemy: play hurt then dead (if available). On player damage: always play player_hurt.

## Module Mode Design Guide (Dyslexia-focused)

Use these defaults for all learning modules targeting dyslexic children (primary phonological processing deficit):

- Remove speed pressure by default

  - No timers by default; accuracy/strategy over speed since this is for children with dyslexia as this study focus on the improvement.

- Multisensory by default

  - Hear (tap-to-hear at phoneme/word), see (highlighting, visuals), say (STT with confirm), do (trace/drag tiles).

- Readability and motion

  - Line spacing 1.5–1.8, slight letter spacing, cream/light pastel backgrounds, reduce-motion toggle. Avoid italics for body text.

- Color and perception

  - Never rely on color alone. Pair consistent, low-saturation colors with shapes/patterns (e.g., closed syllable = blue square).

- Feedback and scaffolding

  - Errorless learning flow: model → guided → independent. Quick, kind feedback; “Show example” and “Try again” always available.

- STT hygiene

  - Push-to-talk; visible “listening” state; transcript preview with confirm/edit; gentle retry on low confidence.

Module-specific notes:

1. Phonics Interactive

   - Keep tracing (generous tolerance) with start-point cues and directional arrows.
   - Add phoneme–grapheme mapping, minimal pairs (/p/ vs /b/), blends, digraphs, vowel teams; blend into decodable words.
   - Optional mouth-shape cue; “I do → we do → you do” sequence.

2. Flip Practice (rename from “Flip Quiz”)

   - Replace speed with short sets (e.g., best of 3). Picture-supported choices; on miss, reveal phoneme-by-phoneme.
   - STT with confirm/edit; no punitive streak loss.

3. Interactive Read‑Aloud

   - Phrase/sentence highlight with adjustable WPM (80–180). Per-sentence replay and “focus mode” (dim other lines).
   - Tap a word for syllables, definition, picture, and slow playback. Provide decodable/leveled texts and pre-teach hard words.

## Implementation Notes by Mode

**Journey Mode**:

- Battle flow managers are decoupled and signal-driven. Signals connected in `battlescene.gd` ensure one source of truth for turn order and outcome screens.
- Enemy animation/SFX helpers in EnemyManager centralize playback and prevent null lookups; BattleManager triggers auto-attack SFX on attack start.
- ChallengeManager handles success (counter bonus damage) and fail/cancel (skill damage) with proper UI cleanup to avoid EndgameScreen blocking.
- Energy and progression updates always follow: get_doc → add_or_update_field → update().

**Module Mode**:

- All educational progress flows through ModuleProgress.gd with Firebase persistence
- Progress bars/labels update immediately after successful completion saves
- Real-time UI refresh on window focus and after any progress update
- Graceful fallback to local session tracking when Firebase unavailable

## QA & Safety Checklist

**Journey Mode**:

- Battle cannot start unless Engage button is pressed.
- Challenge overlay/result panels are removed on victory/defeat to avoid blocking.
- Enemy hurt and player hurt SFX always fire when damage is applied; lethal ordering on enemies is hurt → dead (if available).
- Stage progress UI keeps completed icons semi-transparent; boss victory routes to DungeonSelection.
- Web STT uses JavaScriptBridge with permission prompts and polling; guard all async paths with prints for debugging.

**Module Mode**:

- ModuleProgress initialization checked before any Firebase operations
- Progress calculations verified: for example: phonics = (letters + sight words) / 46 \* 100
- Authentication status validated before persistence attempts
- Progress bar updates confirmed after successful Firebase saves
- Real-time refresh working on window focus events
