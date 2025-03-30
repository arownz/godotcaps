class_name EnemyTypeResource
extends Resource

@export var type_id: String = "normal"  # normal, elite, boss
@export var names: Array[String] = ["Enemy"]
@export var health_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var exp_reward: int = 10
@export var sprite_scale: Vector2 = Vector2(1.0, 1.0)
