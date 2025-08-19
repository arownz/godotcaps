extends Control

var module_progress: ModuleProgress
var completion_celebration: CanvasLayer = null
var completion_celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")

# Dyslexia-friendly syllable activities with explicit syllable type instruction
var syllable_activities = [
	{
		"id": "closed_syllables",
		"title": "Closed Syllables (CVC)",
		"type": "closed",
		"description": "Short vowel sounds with consonant endings",
		"examples": [
			{"word": "cat", "syllables": ["cat"], "pattern": "CVC"},
			{"word": "dog", "syllables": ["dog"], "pattern": "CVC"},
			{"word": "run", "syllables": ["run"], "pattern": "CVC"}
		],
		"color": Color.BLUE
	},
	{
		"id": "open_syllables",
		"title": "Open Syllables (CV)",
		"type": "open",
		"description": "Long vowel sounds at the end",
		"examples": [
			{"word": "me", "syllables": ["me"], "pattern": "CV"},
			{"word": "go", "syllables": ["go"], "pattern": "CV"},
			{"word": "hi", "syllables": ["hi"], "pattern": "CV"}
		],
		"color": Color.GREEN
	},
	{
		"id": "magic_e",
		"title": "Magic E Syllables",
		"type": "magic_e",
		"description": "Silent E makes vowels say their name",
		"examples": [
			{"word": "cake", "syllables": ["cake"], "pattern": "CVCe"},
			{"word": "bike", "syllables": ["bike"], "pattern": "CVCe"},
			{"word": "home", "syllables": ["home"], "pattern": "CVCe"}
		],
		"color": Color.PURPLE
	}
]

var selected_syllables = []
var current_activity = null
var current_word_index = 0

func _ready():
	print("SyllableBuildingModule: Syllable Building module loaded")
	module_progress = ModuleProgress.new()
	_setup_activities()
	_connect_signals()

func _connect_signals():
	"""Connect all UI signals"""
	# Header controls
	var back_button = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		back_button.mouse_entered.connect(_on_button_hover)
	
	# Activity selection buttons
	var start_button1 = $MainContainer/ScrollContainer/ContentContainer/ActivitySelectionCard/ActivityContainer/ActivityGrid/Activity1Card/Activity1Container/StartButton1
	if start_button1:
		start_button1.pressed.connect(_on_start_activity_pressed.bind(1))
		start_button1.mouse_entered.connect(_on_button_hover)
	
	var start_button2 = $MainContainer/ScrollContainer/ContentContainer/ActivitySelectionCard/ActivityContainer/ActivityGrid/Activity2Card/Activity2Container/StartButton2
	if start_button2:
		start_button2.pressed.connect(_on_start_activity_pressed.bind(2))
		start_button2.mouse_entered.connect(_on_button_hover)
	
	# Syllable tiles (for building game)
	var tile1 = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard/BuildingContainer/SyllableTilesArea/SyllableTilesContainer/TilesGrid/SyllableTile1
	if tile1:
		tile1.pressed.connect(_on_syllable_tile_pressed.bind("but"))
		tile1.mouse_entered.connect(_on_button_hover)
	
	var tile2 = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard/BuildingContainer/SyllableTilesArea/SyllableTilesContainer/TilesGrid/SyllableTile2
	if tile2:
		tile2.pressed.connect(_on_syllable_tile_pressed.bind("ter"))
		tile2.mouse_entered.connect(_on_button_hover)
	
	var tile3 = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard/BuildingContainer/SyllableTilesArea/SyllableTilesContainer/TilesGrid/SyllableTile3
	if tile3:
		tile3.pressed.connect(_on_syllable_tile_pressed.bind("fly"))
		tile3.mouse_entered.connect(_on_button_hover)
	
	var tile4 = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard/BuildingContainer/SyllableTilesArea/SyllableTilesContainer/TilesGrid/SyllableTile4
	if tile4:
		tile4.pressed.connect(_on_syllable_tile_pressed.bind("pen"))
		tile4.mouse_entered.connect(_on_button_hover)
	
	# Game control buttons
	var check_button = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard/BuildingContainer/GameButtonsContainer/CheckButton
	if check_button:
		check_button.pressed.connect(_on_check_word_pressed)
		check_button.mouse_entered.connect(_on_button_hover)
	
	var clear_button = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard/BuildingContainer/GameButtonsContainer/ClearButton
	if clear_button:
		clear_button.pressed.connect(_on_clear_word_pressed)
		clear_button.mouse_entered.connect(_on_button_hover)
	
	var back_to_menu = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard/BuildingContainer/GameButtonsContainer/BackToMenuButton
	if back_to_menu:
		back_to_menu.pressed.connect(_on_back_to_menu_pressed)
		back_to_menu.mouse_entered.connect(_on_button_hover)

func _setup_activities():
	"""Setup syllable building activities with dyslexia-friendly design"""
	print("SyllableBuildingModule: Setting up dyslexia-friendly syllable activities")

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	print("SyllableBuildingModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_start_activity_pressed(activity_number: int):
	print("SyllableBuildingModule: Starting activity ", activity_number)
	
	if activity_number <= syllable_activities.size():
		current_activity = syllable_activities[activity_number - 1]
		current_word_index = 0
		_show_building_game()
	else:
		_show_activity_placeholder(activity_number)

func _show_building_game():
	"""Switch to building game view"""
	var activity_card = $MainContainer/ScrollContainer/ContentContainer/ActivitySelectionCard
	var building_card = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard
	
	if activity_card and building_card:
		activity_card.visible = false
		building_card.visible = true

func _show_activity_selection():
	"""Switch to activity selection view"""
	var activity_card = $MainContainer/ScrollContainer/ContentContainer/ActivitySelectionCard
	var building_card = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard
	
	if activity_card and building_card:
		building_card.visible = false
		activity_card.visible = true

func _on_syllable_tile_pressed(syllable: String):
	"""Handle syllable tile press for building words"""
	print("SyllableBuildingModule: Syllable tile pressed: ", syllable)
	selected_syllables.append(syllable)
	_update_build_word_display()

func _on_check_word_pressed():
	"""Check if built word is correct"""
	print("SyllableBuildingModule: Checking built word")
	var built_word = " ".join(selected_syllables)
	print("Built word: ", built_word)
	
	# For demo, check if it's "but ter fly" (butterfly)
	if built_word == "but ter fly":
		print("Correct! Word is butterfly")
		_simulate_activity_completion()
	else:
		print("Try again!")

func _on_clear_word_pressed():
	"""Clear the built word"""
	print("SyllableBuildingModule: Clearing built word")
	selected_syllables.clear()
	_update_build_word_display()

func _on_back_to_menu_pressed():
	"""Return to activity selection"""
	print("SyllableBuildingModule: Returning to activity menu")
	_show_activity_selection()

func _update_build_word_display():
	"""Update the display of the word being built"""
	var build_label = $MainContainer/ScrollContainer/ContentContainer/BuildingGameCard/BuildingContainer/DropZoneArea/DropZoneContainer/BuildWord
	if build_label:
		if selected_syllables.size() == 0:
			build_label.text = "___  ___  ___"
		else:
			build_label.text = " - ".join(selected_syllables)

func _start_syllable_activity():
	"""Start syllable building activity with explicit instruction"""
	var dialog = AcceptDialog.new()
	var activity_info = "Syllable Building: " + current_activity.title + "\n\n"
	activity_info += "Learning: " + current_activity.description + "\n"
	activity_info += "Color code: " + str(current_activity.color) + "\n"
	activity_info += "Listen to each syllable\n"
	activity_info += "Build words step by step\n\n"
	
	activity_info += "Example words:\n"
	for example in current_activity.examples:
		activity_info += "• " + example.word + " (" + example.pattern + ")\n"
	
	activity_info += "\nDyslexia-friendly features:\n"
	activity_info += "• Visual syllable boundaries\n"
	activity_info += "• Audio for each part\n"
	activity_info += "• Color-coded patterns\n"
	activity_info += "• No time pressure"
	
	dialog.dialog_text = activity_info
	dialog.title = "Syllable Building - " + current_activity.title
	dialog.custom_minimum_size = Vector2(500, 450)
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	
	# Simulate activity completion
	await _simulate_activity_completion()
	dialog.queue_free()

func _simulate_activity_completion():
	"""Simulate completing a syllable building activity"""
	print("SyllableBuildingModule: Simulating activity completion")
	if module_progress and current_activity:
		var success = await module_progress.set_syllable_activity_completed(current_activity.id, current_activity.type)
		if success:
			_show_completion_celebration()

func _show_completion_celebration():
	"""Show completion celebration for finished activity"""
	var celebration = completion_celebration_scene.instantiate()
	add_child(celebration)
	
	# Calculate progress for celebration display
	var completed_activities = 1 # At least this activity is completed
	var total_activities = syllable_activities.size()
	var progress_data = {
		"current": completed_activities,
		"total": total_activities,
		"percentage": (float(completed_activities) / float(total_activities)) * 100.0
	}
	
	celebration.show_completion("syllable_building", current_activity.title, progress_data, "syllable_building")
	
	# Connect celebration signals
	celebration.try_again_pressed.connect(_on_celebration_try_again)
	celebration.next_item_pressed.connect(_on_celebration_next_activity)

func _on_celebration_try_again():
	"""Try the same activity again"""
	_start_syllable_activity()

func _on_celebration_next_activity():
	"""Move to next activity or show completion"""
	print("SyllableBuildingModule: Moving to next activity")

func _show_activity_placeholder(activity_number: int):
	"""Show placeholder for activities in development"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Activity " + str(activity_number) + " is in development!\n\n" + \
		"Syllable Building features:\n" + \
		"• Explicit syllable type instruction\n" + \
		"• Visual color-coding by pattern\n" + \
		"• Audio pronunciation practice\n" + \
		"• Interactive drag-and-drop\n" + \
		"• Progressive difficulty\n" + \
		"• Multisensory learning approach\n" + \
		"• Celebration for each success"
	
	dialog.title = "Syllable Building - Activity " + str(activity_number)
	dialog.custom_minimum_size = Vector2(400, 300)
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	dialog.queue_free()

# Legacy demo functions for backward compatibility
func _on_syllable_clicked(syllable: String):
	$ButtonClick.play()
	print("SyllableBuildingModule: Legacy syllable clicked: ", syllable)

func _on_build_word_pressed():
	$ButtonClick.play()
	print("SyllableBuildingModule: Legacy build word pressed")

func _reset_demo():
	"""Reset any legacy demo state"""
	selected_syllables.clear()
