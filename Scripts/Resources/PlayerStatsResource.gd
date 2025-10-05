extends Resource
class_name PlayerStatsResource

# Player stats that match Firebase structure
@export var level: int = 1
@export var experience: int = 0
@export var health: int = 100
@export var damage: int = 10
@export var durability: int = 5
@export var base_health: int = 100
@export var base_damage: int = 10
@export var base_durability: int = 5
@export var energy: int = 20
@export var current_character: String = "lexia"

# Getter methods
func get_level():
	return level

func get_exp():
	return experience

func get_health():
	return health

func get_damage():
	return damage

func get_durability():
	return durability

func get_energy():
	return energy

func get_skin():
	return get_character_animation_path(current_character)

# Helper function to get character animation path from character name
func get_character_animation_path(character_name: String) -> String:
	match character_name.to_lower():
		"lexia":
			return "res://Sprites/Animation/Lexia_Animation.tscn.tscn"
		"ragna":
			return "res://Sprites/Animation/Ragna_Animation.tscn"
		_:
			return "res://Sprites/Animation/Lexia_Animation.tscn.tscn"

func get_base_health():
	return base_health

func get_base_damage():
	return base_damage

func get_base_durability():
	return base_durability

func get_current_character():
	return current_character