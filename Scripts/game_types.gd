extends Node

# This script acts as a central registry for class types
# Add this to your AutoLoad singletons with the name "GameTypes"

# Store references to manager script classes to prevent circular dependencies
const BattleManagerScript = preload("res://Scripts/Manager/battle_manager.gd")
const EnemyManagerScript = preload("res://Scripts/Manager/enemy_manager.gd")
const PlayerManagerScript = preload("res://Scripts/Manager/player_manager.gd")
const LogManagerScript = preload("res://Scripts/Manager/battle_log_manager.gd")
const UIManagerScript = preload("res://Scripts/Manager/ui_manager.gd")
const ChallengeManagerScript = preload("res://Scripts/Manager/challenge_manager.gd")
const DungeonManagerScript = preload("res://Scripts/Manager/dungeon_manager.gd")

func _ready():
	# Print confirmation message
	print("Game types registered successfully")
