extends Control

func _ready():
	print("PhonicsModule: Phonics Interactive module loaded")

func _on_back_button_pressed():
	print("PhonicsModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_whiteboard_button_pressed():
	print("PhonicsModule: Opening whiteboard interface")
	# Store that we came from phonics module
	if GlobalData:
		GlobalData.current_module = "phonics"
		GlobalData.previous_scene = "res://Scenes/PhonicsModule.tscn"
	
	get_tree().change_scene_to_file("res://Scenes/WhiteboardInterface.tscn")
