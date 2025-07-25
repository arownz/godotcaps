# iCopilot Instructions for Godot Dyslexia Learning Game

## Project Overview

This is a Godot 4.4.1 web-based educational RPG designed for dyslexic learners, featuring a manager-based architecture with Firebase integration, progressive word challenges, and accessibility-focused design.

## Architecture Principles

### Manager-Based Battle System

The core battle system uses a decoupled manager pattern in `Scripts/Manager/`:

- **BattleManager**: Victory/defeat flow, Firebase progression, endgame routing
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

For JavaScript integration (STT):

- Use `JavaScriptBridge.eval()` for all web audio operations
- Implement polling mechanism in `_process()` for async speech results
- Handle microphone permissions gracefully with user-initiated requests
- Google Cloud Speech API integration via `window.godot_speech` object

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

- `/Scripts/Manager/`: Core battle system managers
- `/Scripts/`: Scene-specific scripts (dungeon maps, authentication, etc.)
- `/Resources/Enemies/`: Enemy data resources (.tres files)
- `/Scenes/`: All game scenes (.tscn files)
- `/gui/`: UI assets and backgrounds

## Testing & Debugging

- Use `print()` statements liberally for async operations
- Check Firebase responses with `("error" in document.keys())` pattern
- Validate manager initialization in `battlescene.gd` `_ready()`
- Test challenge UI cleanup with rapid enemy defeats

When working on this codebase, always consider dyslexic users' needs: readable fonts, forgiving word matching, clear feedback, and progressive difficulty scaling.
