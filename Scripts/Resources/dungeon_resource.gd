class_name DungeonResource
extends Resource

# EnemyTypeResource is already available as a global class

@export var dungeon_id: int = 1
@export var dungeon_name: String = "Default Dungeon"
@export var background_path: String = "res://gui/Backgrounds/Dungeon1_background.png"
@export var stages_count: int = 5
@export var base_enemy_health: int = 100
@export var base_enemy_damage: int = 10
@export var normal_enemies: EnemyTypeResource
@export var elite_enemies: EnemyTypeResource
@export var boss_enemies: EnemyTypeResource
@export var introduction_messages: Array[String] = ["You have entered a dungeon."]
