extends AnimatedSprite2D

# Properties exposed to the Inspector
@export var enemy_type: String = "normal"  # normal, elite, boss
@export var dungeon: int = 1
@export var stage: int = 1

# Scaling parameters that can be adjusted in the editor
@export var base_scale: Vector2 = Vector2(1.0, 1.0)
@export var elite_scale_multiplier: float = 1.5
@export var boss_scale_multiplier: float = 2.0

func _ready():
	# Apply appropriate scale based on enemy type
	apply_enemy_type_scale()
	
	# Load animations if available
	load_animations()

func apply_enemy_type_scale():
	match enemy_type:
		"elite":
			scale = base_scale * elite_scale_multiplier
		"boss":
			scale = base_scale * boss_scale_multiplier
		_:  # normal or any other type
			scale = base_scale

func load_animations():
	# If this enemy has animations, load them
	var anim_path = "res://Sprites/Dungeon_" + str(dungeon) + "/Stage_" + str(stage) + "/" + get_enemy_folder_name() + "/animations"
	
	# Example logic to load animations (implement or customize as needed)
	if ResourceLoader.exists(anim_path + "/sprite_frames.tres"):
		sprite_frames = load(anim_path + "/sprite_frames.tres")
		play("idle")  # Default animation
	else:
		# If no animations, just use the static sprite
		$Sprite2D.visible = true
		visible = false

func get_enemy_folder_name() -> String:
	# This should return the folder name for this enemy type
	# Could be derived from the enemy_type or configured separately
	match enemy_type:
		"elite":
			return "elite_slime"
		"epic":
			return "epic_slime"
		"boss":
			return "boss_slime"
		_:
			return "slime"

# Called by the battle manager to set the enemy type
func set_enemy_type(type: String):
	enemy_type = type
	apply_enemy_type_scale()
	
	# Update sprite based on the new type
	var texture_path = "res://Sprites/Dungeon_" + str(dungeon) + "/Stage_" + str(stage) + "/" + get_enemy_folder_name() + "/sprite.png"
	if ResourceLoader.exists(texture_path):
		$Sprite2D.texture = load(texture_path)
