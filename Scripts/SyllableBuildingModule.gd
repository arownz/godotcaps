extends Control

var selected_syllables = []
var target_word = "butterfly"
var syllable_buttons = []

func _ready():
	print("SyllableBuildingModule: Syllable Building module loaded")
	syllable_buttons = [
		$MainContainer/CenterContainer/ContentPanel/ContentContainer/DemoSection/DemoContainer/SyllableBox1,
		$MainContainer/CenterContainer/ContentPanel/ContentContainer/DemoSection/DemoContainer/SyllableBox2,
		$MainContainer/CenterContainer/ContentPanel/ContentContainer/DemoSection/DemoContainer/SyllableBox3
	]
	
	# Connect button hover events
	if $BackButton:
		$BackButton.mouse_entered.connect(_on_button_hover)

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("SyllableBuildingModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_start_activity_pressed(activity_number: int):
	$ButtonClick.play()
	print("SyllableBuildingModule: Starting activity ", activity_number)
	
	# For now, show a placeholder message
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Activity " + str(activity_number) + " is in development!\n\nThis will feature:\n• Interactive drag-and-drop syllables\n• Audio pronunciation for each syllable\n• Progressive difficulty levels\n• Visual feedback and celebrations"
	dialog.title = "Syllable Building - Activity " + str(activity_number)
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	dialog.queue_free()

func _on_syllable_clicked(syllable: String):
	$ButtonClick.play()
	print("SyllableBuildingModule: Syllable clicked: ", syllable)
	
	# Find the button that was clicked and highlight it
	for button in syllable_buttons:
		if button.text == syllable:
			if button.modulate == Color.WHITE:
				button.modulate = Color.YELLOW # Highlight selected
				selected_syllables.append(syllable)
			else:
				button.modulate = Color.WHITE # Deselect
				selected_syllables.erase(syllable)
			break
	
	print("Selected syllables: ", selected_syllables)

func _on_build_word_pressed():
	$ButtonClick.play()
	print("SyllableBuildingModule: Build word pressed")
	
	# Check if the correct syllables are selected in order
	var correct_syllables = ["but", "ter", "fly"]
	var built_word = ""
	
	for syllable in correct_syllables:
		if syllable in selected_syllables:
			built_word += syllable
	
	var dialog = AcceptDialog.new()
	
	if built_word == target_word:
		dialog.dialog_text = "Excellent! You built the word '" + target_word + "'!\n\nYou combined:\n• but\n• ter\n• fly\n\nWell done!"
		dialog.title = "Success!"
	
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	dialog.queue_free()
	
	# Reset the demo
	_reset_demo()

func _reset_demo():
	"""Reset the demo to initial state"""
	selected_syllables.clear()
	for button in syllable_buttons:
		button.modulate = Color.WHITE
