extends Resource
class_name PlayerStatsResource

# Player stats that match Firebase structure
@export var level: int = 1
@export var experience: int = 0
@export var health: int = 100
@export var damage: int = 10
@export var durability: int = 5
@export var energy: int = 20
@export var skin: String = "res://Sprites/Animation/DefaultPlayer_Animation.tscn"

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
	return skin