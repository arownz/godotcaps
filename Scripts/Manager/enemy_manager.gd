class_name EnemyManager
extends Node

# Add signals for better decoupling
signal enemy_health_changed(current_health, max_health)
signal enemy_defeated(exp_reward)
signal enemy_skill_meter_changed(value)
signal enemy_set_up(enemy_name, enemy_type)

var battle_scene  # Reference to the main battle scene

# Enemy base stats
var enemy_health = 100
var enemy_max_health = 100
var enemy_damage = 10
var enemy_skill_meter = 0
var enemy_name = "Slime"
var enemy_type = "normal" # Can be "normal", "elite", or "boss"

# Resource paths
var enemy_resource_path = "res://Resources/Enemies/"
var current_enemy_resource: EnemyTypeResource

# Cache for loaded resources
var enemy_resources = {}

# Enemy types and their characteristics
var enemy_types = {
	"dungeon1": {
		"normal": {
			"names": ["Slime"],
			"health_multiplier": 1.0,
			"damage_multiplier": 1.0,
			"exp_reward": 10
		},
		"elite": {
			"names": ["Giant Slime"],
			"health_multiplier": 2.0,
			"damage_multiplier": 1.5,
			"exp_reward": 25
		},
		"boss": {
			"names": ["King Slime"],
			"health_multiplier": 3.0,
			"damage_multiplier": 2.0,
			"exp_reward": 50
		}
	},
	"dungeon2": {
		"normal": {
			"names": ["Snake"],
			"health_multiplier": 1.2,
			"damage_multiplier": 1.2,
			"exp_reward": 15
		},
		"elite": {
			"names": ["Cobra"],
			"health_multiplier": 2.2,
			"damage_multiplier": 1.7,
			"exp_reward": 35
		},
		"boss": {
			"names": ["Basilisk"],
			"health_multiplier": 3.2,
			"damage_multiplier": 2.2,
			"exp_reward": 75
		}
	},
	"dungeon3": {
		"normal": {
			"names": ["Goblin"],
			"health_multiplier": 1.5,
			"damage_multiplier": 1.5,
			"exp_reward": 20
		},
		"elite": {
			"names": ["Goblin Warrior"],
			"health_multiplier": 2.5,
			"damage_multiplier": 2.0,
			"exp_reward": 45
		},
		"boss": {
			"names": ["Goblin King"],
			"health_multiplier": 3.5,
			"damage_multiplier": 2.5,
			"exp_reward": 100
		}
	}
}

func _init(scene):
	battle_scene = scene

func _ready():
	# Preload enemy type resources
	_preload_enemy_resources()

func _preload_enemy_resources():
	# For testing, only load the basic slime enemy
	var resource_path = enemy_resource_path + "dungeon1_normal.tres"
	if ResourceLoader.exists(resource_path):
		enemy_resources[11] = load(resource_path)  # 11 = dungeon1 normal type
	
	# Comment out other enemy types until needed
	# For each dungeon and enemy type, preload the resources
	# for dungeon_num in range(1, 4):
	#    for type in ["normal", "elite", "boss"]:
	#        var resource_path = enemy_resource_path + "dungeon" + str(dungeon_num) + "_" + type + ".tres"
	#        if ResourceLoader.exists(resource_path):
	#            enemy_resources[dungeon_num * 10 + _type_to_id(type)] = load(resource_path)

func _type_to_id(type_str: String) -> int:
	match type_str:
		"normal": return 1
		"elite": return 2
		"boss": return 3
		_: return 0

func setup_enemy():
	var dungeon_manager = battle_scene.dungeon_manager
	
	# Determine enemy type based on stage progression
	_determine_enemy_type(dungeon_manager.stage_num)
	
	# Get the appropriate enemy resource
	var resource_key = dungeon_manager.dungeon_num * 10 + _type_to_id(enemy_type)
	current_enemy_resource = enemy_resources.get(resource_key)
	
	if current_enemy_resource:
		# Use the resource for enemy stats
		var names = current_enemy_resource.names
		enemy_name = names[randi() % names.size()]
		
		# Calculate enemy stats based on dungeon, stage, and type
		# Fix here as well to only add stage bonus from stage 2 onwards
		var base_health = 80 + (dungeon_manager.dungeon_num * 20) + ((dungeon_manager.stage_num - 1) * 5)
		var base_damage = 8 + (dungeon_manager.dungeon_num * 2) + ((dungeon_manager.stage_num - 1) * 1)
		
		# Apply multiplier from resource
		enemy_max_health = base_health * current_enemy_resource.health_multiplier
		enemy_health = enemy_max_health
		enemy_damage = base_damage * current_enemy_resource.damage_multiplier
	else:
		# Fallback to old method if resource not found
		_setup_enemy_fallback()
	
	# Reset skill meter
	enemy_skill_meter = 0
	
	# Emit signal that enemy is set up
	emit_signal("enemy_set_up", enemy_name, enemy_type)

func _setup_enemy_fallback():
	# This uses the old dictionary-based implementation as fallback
	var dungeon_key = "dungeon" + str(battle_scene.dungeon_manager.dungeon_num)
	
	# Simplified enemy types for testing
	enemy_types = {
		"dungeon1": {
			"normal": {
				"names": ["Slime"],
				"health_multiplier": 1.0,
				"damage_multiplier": 1.0,
				"exp_reward": 10
			},
			"elite": {
				"names": ["Giant Slime"],
				"health_multiplier": 2.0,
				"damage_multiplier": 1.5,
				"exp_reward": 25
			},
			"boss": {
				"names": ["King Slime"],
				"health_multiplier": 3.0,
				"damage_multiplier": 2.0,
				"exp_reward": 50
			}
		}
	}
	
	var current_dungeon = enemy_types.get(dungeon_key, enemy_types["dungeon1"])
	var enemy_list = current_dungeon[enemy_type]["names"]
	
	# Always use the first name in the list for testing
	enemy_name = enemy_list[0]
	
	# Calculate enemy stats based on dungeon, stage, and type
	var dungeon_manager = battle_scene.dungeon_manager
	
	# Fix the calculation to only add stage bonus from stage 2 onwards
	var base_health = 80 + (dungeon_manager.dungeon_num * 20) + ((dungeon_manager.stage_num - 1) * 5)
	var base_damage = 8 + (dungeon_manager.dungeon_num * 2) + ((dungeon_manager.stage_num - 1) * 1)
	
	# Apply multiplier based on enemy type
	enemy_max_health = base_health * current_dungeon[enemy_type]["health_multiplier"]
	enemy_health = enemy_max_health
	enemy_damage = base_damage * current_dungeon[enemy_type]["damage_multiplier"]

func _determine_enemy_type(_stage_num):
	# For testing, always use normal enemy type
	enemy_type = "normal"
	
	# Comment out type selection logic until needed for testing multiple enemy types
	# if stage_num % 5 == 0:
	#    # Every 5th stage is a boss
	#    enemy_type = "boss"
	# elif stage_num % 3 == 0:
	#    # Every 3rd stage is an elite
	#    enemy_type = "elite"
	# else:
	#    # Regular stages have normal enemies
	#    enemy_type = "normal"

func get_exp_reward():
	var dungeon_num = battle_scene.dungeon_manager.dungeon_num
	var dungeon_key = "dungeon" + str(dungeon_num)
	
	if enemy_types.has(dungeon_key) and enemy_types[dungeon_key].has(enemy_type):
		return enemy_types[dungeon_key][enemy_type]["exp_reward"] * dungeon_num
	
	# Fallback
	return 10 * dungeon_num

func update_from_tester(tester):
	# Update enemy stats directly from tester values without any multipliers
	enemy_health = tester.get_enemy_health()
	enemy_max_health = enemy_health  # Use the exact same value
	enemy_damage = tester.get_enemy_damage()
	
	# Update skill label visibility if the function exists
	if tester.has_method("get_show_skill_label"):
		battle_scene.get_node("MainContainer/BattleAreaContainer/BattleContainer/EnemyContainer/EnemySkillLabel").visible = tester.get_show_skill_label()

# This method will be called when player attacks
func take_damage(damage: int):
	enemy_health -= damage
	enemy_health = max(enemy_health, 0)  # Ensure health doesn't go below 0
	
	# Emit signal for health change
	emit_signal("enemy_health_changed", enemy_health, enemy_max_health)
	
	# Check if defeated
	if enemy_health <= 0:
		emit_signal("enemy_defeated", get_exp_reward())

# This method will be called when enemy uses abilities
func increase_skill_meter(amount):
	enemy_skill_meter += amount
	enemy_skill_meter = min(enemy_skill_meter, 100)  # Cap at 100
	
	# Emit signal that skill meter changed
	emit_signal("enemy_skill_meter_changed", enemy_skill_meter)
	
	return enemy_skill_meter >= 100  # Return true if skill is ready

# Reset skill meter to zero
func reset_skill_meter():
	enemy_skill_meter = 0
	emit_signal("enemy_skill_meter_changed", enemy_skill_meter)
