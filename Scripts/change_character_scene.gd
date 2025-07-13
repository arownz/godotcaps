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
		back_button.mouse_entered.connect(_on_back_button_hover_entered)
		back_button.mouse_exited.connect(_on_back_button_hover_exited)
	
	# Setup hover functionality for navigation buttons
	var next_button = $Background/DungeonContainer/NextButton
	if next_button:
		next_button.mouse_entered.connect(_on_next_button_hover_entered)
		next_button.mouse_exited.connect(_on_next_button_hover_exited)
	
	var previous_button = $Background/DungeonContainer/PreviousButton
	if previous_button:
		previous_button.mouse_entered.connect(_on_previous_button_hover_entered)
		previous_button.mouse_exited.connect(_on_previous_button_hover_exited)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

# Button hover handlers
func _on_back_button_hover_entered():
	var back_label = $Background/BackButton/BackLabel
	if back_label:
		back_label.visible = true

func _on_back_button_hover_exited():
	var back_label = $Background/BackButton/BackLabel
	if back_label:
		back_label.visible = false

func _on_next_button_hover_entered():
	var next_label = $Background/DungeonContainer/NextButton/NextLabel
	if next_label:
		next_label.visible = true

func _on_next_button_hover_exited():
	var next_label = $Background/DungeonContainer/NextButton/NextLabel
	if next_label:
		next_label.visible = false

func _on_previous_button_hover_entered():
	var previous_label = $Background/DungeonContainer/PreviousButton/PreviousLabel
	if previous_label:
		previous_label.visible = true

func _on_previous_button_hover_exited():
	var previous_label = $Background/DungeonContainer/PreviousButton/PreviousLabel
	if previous_label:
		previous_label.visible = false