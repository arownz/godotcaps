# iCopilot Instructions for Godot Dyslexia Learning Game

## Project Overview

This is a Godot 4.4.1 2D web-based educational gamification designed for dyslexic learners, featuring a manager-based architecture with Firebase integration, progressive word challenges, modular learning, and accessibility-focused design.

## Architecture Principles

### Journey Manager-Based Battle System

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

- **Dungeon 1**: 3-letter words (`sp=???` in Datamuse API)
- **Dungeon 2**: 4-letter words (`sp=????` in Datamuse API)
- **Dungeon 3**: 5-letter words (`sp=?????` in Datamuse API)

Implement via `_get_word_length_for_dungeon()` in challenge panels and `RandomWordAPI.fetch_random_word(word_length)`.

### Firebase Integration Patterns

Always use document retrieval → field update → collection.update() pattern:

```gdscript
var user_doc = await collection.get_doc(user_id)
user_doc.add_or_update_field("field_name", value)
var updated_doc = await collection.update(user_doc)
```

Player stats updated by `PlayerManager`, progression by `BattleManager` - never mix responsibilities.

## Key Development Patterns

### Signal-Driven Architecture

Managers communicate via signals, not direct method calls:

- `enemy_defeated(exp_reward)` → triggers victory flow
- `challenge_completed(bonus_damage)` → applies counter-attack damage
- Connect signals in `battlescene.gd` `_connect_signals()` method

### Scene Transitions & State Management

Use `DungeonGlobals` autoload for immediate scene data transfer:

```gdscript
DungeonGlobals.set_battle_progress(dungeon_num, stage_num)
```

Boss defeats route to `DungeonSelection.tscn`, regular continues to next stage.

### Challenge System Implementation

STT/Whiteboard challenges follow this flow:

1. `trigger_enemy_skill()` → `challenge_manager.start_word_challenge(type)`
2. Word fetched via `RandomWordAPI.fetch_random_word(dungeon_word_length)`
3. Recognition results processed with dyslexia-friendly fuzzy matching
4. Success grants bonus damage, failure/cancellation applies enemy skill damage
5. `_cleanup_challenge()` removes overlays to prevent EndgameScreen blocking

### Web Platform Specifics

For Google Cloud integration (Whiteboard Cloud Vision API):

- Use Google Cloud Documentation but through HTTP way
-

For JavaScript integration (STT):

- Use `JavaScriptBridge.eval()` for all web audio operations
- Implement polling mechanism in `_process()` for async speech results
- Handle microphone permissions gracefully with user-initiated requests
- Web Speech API

## Important about godot

- Always use tab indentation as the space indentation always made error
- Make sure to always have a connection that are setup to godot as I'm using visuat studio code for scripting instead of built in godot scripter

### UI Cleanup Race Conditions

Always call `_cleanup_challenge()` when enemy defeated during challenge to prevent EndgameScreen blocking.

### Firebase Document Structure

Respect nested structure: `dungeons.completed.{dungeon_id}.stages_completed`, `word_challenges.completed.{type}`

### Enemy Resource Loading

Load enemy resources in dungeon maps: `load("res://Resources/Enemies/dungeon{N}_{type}.tres")` with multipliers for stage scaling.

### Animation State Management

Reset sprites to "idle" after animations, use `await animation_finished` for timing.

## File Organization

- `/Scripts/Manager/`: Core centralize journey mode battle system managers
- `/Scripts/`: Scene-specific scripts (dungeon maps, authentication, etc.)
- `/Resources/Enemies/`: Enemy data resources (.tres files)
- `/Scenes/`: All game scenes (.tscn files)
- `/gui/`: UI assets and backgrounds

## Testing & Debugging (You dont need to test it through cmd command since i will personally test it through godot platform itself)

- Use `print()` statements liberally for async operations
- Check Firebase responses with `("error" in document.keys())` pattern
- Validate manager initialization in `battlescene.gd` `_ready()`
- Test challenge UI cleanup with rapid enemy defeats

When working on this codebase, always consider dyslexic users' needs: readable fonts, forgiving word matching, clear feedback, and progressive difficulty scaling.

---

## Recent Implementations & Working Conventions (Journey Mode)

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
  - Player SFX names in DefaultPlayer_Animation.tscn: sfx_autoattack_swordslash, sfx_counter_swordslash, player_hurt.

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

## Audio/SFX Conventions

- Enemy SFX node naming inside Sprites/Animation scenes:

  - [enemy]\_autoattack → normal attacks
  - [enemy]\_skill → skill usage, including challenge fail/cancel flows
  - [enemy]\_hurt → when taking damage; also plays on lethal before optional [enemy]\_dead
  - [enemy]\_dead (optional) → plays after hurt on lethal if present

- Player SFX nodes:

  - sfx_autoattack_swordslash, sfx_counter_swordslash, player_hurt

- Playback rules:

  - Enemy auto-attack SFX is triggered in both EnemyManager.attack and BattleManager.enemy_attack for reliability.
  - Challenge fail/cancel triggers enemy skill SFX; fallback uses auto-attack SFX if needed.
  - On lethal to enemy: play hurt then dead (if available). On player damage: always play player_hurt.

## Module Mode Design Guide (Dyslexia-focused)

Use these defaults for all learning modules targeting dyslexic children (primary phonological processing deficit):

- Remove speed pressure by default

  - No timers by default; accuracy/strategy over speed since this is for children with dyslexia as this study focus on the improvement.

- Multisensory by default

  - Hear (tap-to-hear at phoneme/syllable/word), see (highlighting, visuals), say (STT with confirm), do (trace/drag tiles).

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

   - Replace speed with short sets (e.g., best of 5). Picture-supported choices; on miss, reveal phoneme-by-phoneme.
   - STT with confirm/edit; no punitive streak loss.

3. Interactive Read‑Aloud

   - Phrase/sentence highlight with adjustable WPM (80–180). Per-sentence replay and “focus mode” (dim other lines).
   - Tap a word for syllables, definition, picture, and slow playback. Provide decodable/leveled texts and pre-teach hard words.

4. Chunked Reading

   - Visible chunk markers; preview key idea → read → 1–2 picture-supported checks (cloze, unscramble, sequence).
   - Pre-teach vocabulary; show/ask with minimal memory load.

5. Syllable Building

   - Explicit syllable types (closed, open, magic‑e, r‑controlled, vowel team, consonant‑le). Color+shape coding.
   - Onset–rime, prefixes/suffixes tiles; decodable set filters by pattern progression.

## Implementation Notes Mapped to Code

- Battle flow managers are decoupled and signal-driven. Signals connected in `battlescene.gd` ensure one source of truth for turn order and outcome screens.
- Enemy animation/SFX helpers in EnemyManager centralize playback and prevent null lookups; BattleManager triggers auto-attack SFX on attack start.
- ChallengeManager handles success (counter bonus damage) and fail/cancel (skill damage) with proper UI cleanup to avoid EndgameScreen blocking.
- Energy and progression updates always follow: get_doc → add_or_update_field → update(). Player stat persistence belongs to PlayerManager; stage/dungeon progression belongs to BattleManager.

## QA & Safety Checklist (keep during future edits)

- Battle cannot start unless Engage button is pressed.
- Challenge overlay/result panels are removed on victory/defeat to avoid blocking.
- Enemy hurt and player hurt SFX always fire when damage is applied; lethal ordering on enemies is hurt → dead (if available).
- Stage progress UI keeps completed icons semi-transparent; boss victory routes to DungeonSelection.
- Web STT uses JavaScriptBridge with permission prompts and polling; guard all async paths with prints for debugging.
- DO NOT USE EMOJI AS MY DYSLEXIA FONT DOES NOT SUPPORT IT WHEN EXPORTED TO WEB
