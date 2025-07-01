extends Control

func _ready():
	print("ReadAloudModule: Interactive Read-Aloud module loaded")

func _on_back_button_pressed():
	print("ReadAloudModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_stt_button_pressed():
	print("ReadAloudModule: Opening STT interface")
	# Store that we came from read aloud module
	if GlobalData:
		GlobalData.current_module = "read_aloud"
		GlobalData.previous_scene = "res://Scenes/ReadAloudModule.tscn"
	
	get_tree().change_scene_to_file("res://Scenes/WordChallengePanel_STT.tscn")
