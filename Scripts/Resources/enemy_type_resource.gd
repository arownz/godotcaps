@tool
class_name EnemyTypeResource
extends Resource

# Enemy properties - ADD MISSING VARIABLE DECLARATIONS
@export var enemy_name: String = ""
@export var health: int = 100
@export var damage: int = 10
@export var durability: int = 5
@export var exp_reward: int = 10
@export var skill_name: String = ""
@export var description: String = ""
@export var animation_scene: PackedScene

# Getter methods - RENAMED to avoid conflicts with Resource.get_name()
func get_enemy_name():
	return enemy_name

func get_health():
	return health

func get_damage():
	return damage

func get_durability():
	return durability

func get_animation_scene():
	return animation_scene

func get_skill_name():
	return skill_name

func get_description():
	return description

func get_exp_reward():
	return exp_reward