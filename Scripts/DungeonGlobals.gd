extends Node

# Global variables to pass data between scenes
var current_dungeon: int = 1
var current_stage: int = 1

# Flag to prevent auto-login immediately after logout
var logout_just_occurred: bool = false
var engage_button_hidden_session: bool = false # Persist engage hide across popups within battle session

# Reset to defaults
func reset():
	current_dungeon = 1
	current_stage = 1
	logout_just_occurred = false
	engage_button_hidden_session = false

# Store progress for scene transitions
func set_battle_progress(dungeon: int, stage: int):
	current_dungeon = dungeon
	current_stage = stage
	print("DungeonGlobals: Set battle progress to Dungeon ", dungeon, " Stage ", stage)

func get_battle_progress() -> Dictionary:
	return {
		"dungeon": current_dungeon,
		"stage": current_stage
	}
