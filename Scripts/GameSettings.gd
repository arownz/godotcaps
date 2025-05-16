@tool
extends Node

# Battle mechanics
@export_category("Battle Settings")
@export var default_battle_speed: float = 3.0 
@export var battle_speed_min: float = 1.0
@export var battle_speed_max: float = 5.0

# Player stats
@export_category("Player Stats")
@export var player_base_health: int = 100
@export var player_base_damage: int = 10
@export var player_level_up_health_bonus: int = 20
@export var player_level_up_damage_bonus: int = 5

# Enemy scaling
@export_category("Enemy Scaling")
@export var normal_enemy_health_multiplier: float = 1.0
@export var normal_enemy_damage_multiplier: float = 1.0
@export var elite_enemy_health_multiplier: float = 2.0
@export var elite_enemy_damage_multiplier: float = 1.5
@export var boss_enemy_health_multiplier: float = 3.0
@export var boss_enemy_damage_multiplier: float = 2.0

# Dungeon progression - Ensure base values are exactly 100/10
@export_category("Dungeon Progression")
@export var base_enemy_health: int = 100
@export var base_enemy_damage: int = 10
@export var dungeon_health_increase: int = 20
@export var dungeon_damage_increase: int = 2
@export var stage_health_increase: int = 5
@export var stage_damage_increase: int = 1

# Add dungeon and stage variables
var current_dungeon = 1
var current_stage = 1

# Add dungeon completion tracking
var dungeons_completed = {
	"1": {"completed": false, "stages_completed": []},
	"2": {"completed": false, "stages_completed": []},
	"3": {"completed": false, "stages_completed": []}
}

# Dungeon names
var dungeon_names = {
	"1": "The Plains",
	"2": "The Forest", 
	"3": "The Demon"
}

# Accessibility settings
var tts_enabled = true
var tts_voice = ""
var tts_rate = 1.0
var speech_recognition_enabled = true
var dyslexic_font_enabled = true

# Apply these settings
func _ready():
	# This must be called from the game initialization
	# This script should be added as an AutoLoad singleton called "GameSettings"
	if Engine.is_editor_hint():
		return
	
	print("Game settings loaded!")
	load_settings()

# Return settings for a specific category
func get_battle_settings() -> Dictionary:
	return {
		"battle_speed": default_battle_speed,
		"battle_speed_min": battle_speed_min,
		"battle_speed_max": battle_speed_max
	}

func get_player_settings() -> Dictionary:
	return {
		"base_health": player_base_health,
		"base_damage": player_base_damage,
		"level_up_health_bonus": player_level_up_health_bonus,
		"level_up_damage_bonus": player_level_up_damage_bonus
	}

func get_enemy_settings() -> Dictionary:
	return {
		"base_health": base_enemy_health,
		"base_damage": base_enemy_damage,
		"dungeon_health_increase": dungeon_health_increase,
		"dungeon_damage_increase": dungeon_damage_increase,
		"stage_health_increase": stage_health_increase,
		"stage_damage_increase": stage_damage_increase,
		"normal_health_multiplier": normal_enemy_health_multiplier,
		"normal_damage_multiplier": normal_enemy_damage_multiplier,
		"elite_health_multiplier": elite_enemy_health_multiplier,
		"elite_damage_multiplier": elite_enemy_damage_multiplier,
		"boss_health_multiplier": boss_enemy_health_multiplier,
		"boss_damage_multiplier": boss_enemy_damage_multiplier
	}

# Add explicit getters for current dungeon/stage for code that expects these methods
func get_current_dungeon() -> int:
	return current_dungeon

func get_current_stage() -> int:
	return current_stage

func save_settings():
	var config = ConfigFile.new()
	
	# Save game state
	config.set_value("game_state", "current_dungeon", current_dungeon)
	config.set_value("game_state", "current_stage", current_stage)
	config.set_value("game_state", "dungeons_completed", dungeons_completed)
	
	# Save accessibility settings
	config.set_value("accessibility", "tts_enabled", tts_enabled)
	config.set_value("accessibility", "tts_voice", tts_voice)
	config.set_value("accessibility", "tts_rate", tts_rate)
	config.set_value("accessibility", "speech_recognition_enabled", speech_recognition_enabled)
	config.set_value("accessibility", "dyslexic_font_enabled", dyslexic_font_enabled)
	
	# Save the config file
	var err = config.save("user://settings.cfg")
	if err != OK:
		print("Error saving settings: " + str(err))

func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err != OK:
		# Config file doesn't exist, use defaults
		print("No settings file found, using defaults")
		return
	
	# Load game state if available
	if config.has_section("game_state"):
		current_dungeon = config.get_value("game_state", "current_dungeon", 1)
		current_stage = config.get_value("game_state", "current_stage", 1)
		var saved_dungeons = config.get_value("game_state", "dungeons_completed", {})
		
		# Only use saved dungeons if it's a valid dictionary
		if typeof(saved_dungeons) == TYPE_DICTIONARY:
			for key in saved_dungeons.keys():
				if dungeons_completed.has(key):
					dungeons_completed[key] = saved_dungeons[key]
	
	# Load accessibility settings
	if config.has_section("accessibility"):
		tts_enabled = config.get_value("accessibility", "tts_enabled", true)
		tts_voice = config.get_value("accessibility", "tts_voice", "")
		tts_rate = config.get_value("accessibility", "tts_rate", 1.0)
		speech_recognition_enabled = config.get_value("accessibility", "speech_recognition_enabled", true)
		dyslexic_font_enabled = config.get_value("accessibility", "dyslexic_font_enabled", true)
