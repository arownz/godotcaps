extends Node

# Global variables to pass data between scenes
var current_dungeon: int = 1
var current_stage: int = 1

# Reset to defaults
func reset():
	current_dungeon = 1
	current_stage = 1

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
