# Copilot Instructions for Lexia Dyslexia Learning Game

## Project Overview

This is a **Godot 4.4.1 (stable version) web-based dyslexia learning game** called "Lexia" that combines turn-based combat with educational challenges. Players progress through dungeons (1-3) with 5 stages each, completing Speech-to-Text (STT) and Whiteboard challenges to counter enemy attacks.

## Architecture Patterns

### Manager Pattern Architecture

The battle system uses a **centralized manager pattern** where `battlescene.gd` orchestrates multiple specialized managers:

- `BattleManager`: Combat flow and endgame handling
- `EnemyManager`: Enemy stats, animations, and level scaling
- `PlayerManager`: Player stats, experience, and leveling
- `UIManager`: All UI updates and visual feedback
- `DungeonManager`: Progress tracking and Firebase persistence
- `ChallengeManager`: STT/Whiteboard challenge coordination

**Example**: All managers are instantiated in `battlescene.gd._initialize_managers()` and communicate via signals:

```gdscript
battle_manager.player_attack_performed.connect(_on_player_attack_performed)
enemy_manager.enemy_defeated.connect(_on_enemy_defeated)
```

### Firebase Integration Pattern

User data uses a **nested document structure** in Firestore collection `dyslexia_users`:

```gdscript
{
  "profile": { "username", "email", "profile_picture", "rank" },
  "stats": { "player": { "level", "exp", "health", "damage", "energy" } },
  "dungeons": { "progress": { "current_dungeon", "current_stage" } },
  "word_challenges": { "completed": { "stt": 0, "whiteboard": 0 } }
}
```

**Critical**: Always use `await collection.get_doc(user_id)` then `collection.update(document)` for updates, never `collection.add()` for existing users.

### Stage Progression System

- **Level Calculation**: `enemy_level = stage_num` (1-5 per dungeon, resets per dungeon)
- **Stat Scaling**: Uses `_get_stage_multiplier()` combining stage and dungeon progression
- **Resource Loading**: Each dungeon has `dungeon{N}_normal.tres` and `dungeon{N}_boss.tres` enemy resources

## Critical Development Workflows

### Testing Battle System

1. Use `DungeonGlobals.set_battle_progress(dungeon, stage)` to set specific battle contexts
2. Test progression with `dungeon_manager.advance_stage()`
3. Verify Firebase updates in `_save_current_dungeon_stage()`

### Challenge Development

**STT Challenges** (`WordChallengePanel_STT.gd`):

- Use Google Cloud Speech API with JavaScript bridge for web platform
- Implement fuzzy matching with `levenshtein_distance()` for dyslexia-friendly recognition
- Always call `JavaScriptBridge.eval()` to setup web audio environment

**Whiteboard Challenges** (`WordChallengePanel_Whiteboard.gd`):

- Integrate with Google Cloud Vision API for handwriting recognition
- Use dyslexia-friendly letter swap detection (`common_swaps` dictionary)

### Web Platform Specifics

- **Audio Setup**: Call `_initialize_web_audio_environment()` before any speech operations
- **JavaScript Bridge**: Use `JavaScriptBridge.eval()` with proper error handling and escape sequences
- **Permissions**: Check existing microphone permissions before requesting new ones

## Project-Specific Conventions

### File Organization

- **Managers**: `Scripts/Manager/` - All game logic managers
- **Challenges**: `WordChallengePanel_*.gd` - STT and Whiteboard implementations
- **Dungeons**: `dungeon_*_map.gd` - Stage selection and progression per dungeon
- **Resources**: `Resources/Enemies/` - Enemy stat configurations (.tres files)

### Signal Communication

Use descriptive signal names with typed parameters:

```gdscript
signal enemy_defeated(exp_reward: int)
signal challenge_completed(bonus_damage: int)
signal stage_advanced(dungeon_num: int, stage_num: int)
```

### Error Handling Pattern

Always check for null references and Firebase errors:

```gdscript
if document and !("error" in document.keys() and document.get_value("error")):
    # Safe to proceed with document operations
```

### Dyslexia Accessibility

- **Fonts**: Use OpenDyslexic font family (`Fonts/dyslexiafont/`)
- **Text Comparison**: Implement fuzzy matching for common dyslexic letter swaps (b/d, p/q, m/w)
- **UI Feedback**: Provide audio feedback for all text-based interactions

## Firebase Authentication Flow

1. **Login**: `Firebase.Auth.signup_with_email_and_password()` or Google OAuth
2. **Document Creation**: Use nested structure template from `authentication.gd._create_user_document()`
3. **Progress Persistence**: Update `dungeons.progress` fields for battle continuity
4. **Energy System**: Battle costs 2 energy, regenerates 1 per hour (max 20)

## Common Integration Points

### Dungeon Map → Battle Scene

Transfer uses `DungeonGlobals.set_battle_progress()` → `BattleScene` reads via `DungeonManager.initialize()`

### Battle → Challenge

Instantiate challenge scenes dynamically: `load("res://Scenes/WordChallengePanel_STT.tscn").instantiate()`

### Profile System

- **Popup Management**: Use `_unhandled_input()` or background click detection for modal behavior
- **Firebase Updates**: Always preserve existing document structure when updating fields

## Build and Deploy

- **Target**: Web platform with WebGL compatibility
- **Export**: Uses `export_presets.cfg` for web build configuration
- **Testing**: `WebTest/index.html` provides local testing environment with speech API integration

When implementing new features, follow the manager pattern for separation of concerns and always consider web platform limitations for audio/input handling.
