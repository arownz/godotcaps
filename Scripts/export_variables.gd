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
@export var player_base_damage: int = 15
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

# Apply these settings
func _ready():
	# This must be called from the game initialization
	# This script should be added as an AutoLoad singleton called "GameSettings"
	if Engine.is_editor_hint():
		return
	
	print("Game settings loaded!")

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
