extends Control

func _ready():
	print("PhonicsModule: Phonics Interactive module loaded")
	
	# Connect button hover events
	if $BackButton:
		$BackButton.mouse_entered.connect(_on_button_hover)
	if $WhiteboardButton:
		$WhiteboardButton.mouse_entered.connect(_on_button_hover)

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("PhonicsModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_whiteboard_button_pressed():
	$ButtonClick.play()
	print("PhonicsModule: Opening whiteboard interface")
	# Store that we came from phonics module
	
	get_tree().change_scene_to_file("res://Scenes/WhiteboardInterface.tscn")
