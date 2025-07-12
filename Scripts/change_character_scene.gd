extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_get_node_references()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _get_node_references():
	var back_button = $Background/BackButton
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")