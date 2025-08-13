extends Control

# Load dyslexia-friendly font
var dyslexia_font: FontFile

func _ready():
	print("FlipQuizModule: Flip Quiz module loaded")
	
	# Connect button hover events
	if $BackButton:
		$BackButton.mouse_entered.connect(_on_button_hover)

func _on_button_hover():
	$ButtonHover.play()


func _on_back_button_pressed():
	$ButtonClick.play()
	print("FlipQuizModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")
