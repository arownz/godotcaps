extends Control

func _ready():
	print("ReadAloudModule: Interactive Read-Aloud module loaded")
	
	# Connect button hover events
	if $BackButton:
		$BackButton.mouse_entered.connect(_on_button_hover)
	if $STTButton:
		$STTButton.mouse_entered.connect(_on_button_hover)

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("ReadAloudModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_stt_button_pressed():
	$ButtonClick.play()
	print("ReadAloudModule: Opening STT interface")
	# Store that we came from read aloud module
	
	get_tree().change_scene_to_file("res://Scenes/WordChallengePanel_STT.tscn")
