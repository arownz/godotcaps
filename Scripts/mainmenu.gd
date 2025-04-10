extends Control

func _ready():
	# Add a debug label to show messages
	var debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(500, 100)
	add_child(debug_label)
	debug_label.text = "Main Menu loaded successfully"

func _process(_delta):
	pass

func _on_logout_button_pressed():
	Firebase.Auth.logout()
	# Add a short delay before changing scene
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://Scenes/Authentication.tscn")

func _on_journey_mode_button_pressed() -> void:
	# Use change_scene_to_file instead of manual instantiation
	# This is more reliable and will properly initialize the scene
	get_tree().change_scene_to_file("res://Scenes/BattleScene.tscn")
