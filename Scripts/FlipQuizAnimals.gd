extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null

# Animal data with images and sounds
var animals = [
	{"name": "cat", "image": preload("res://gui/animalsquiz/split_images/cat.png"), "sound_node": "cat_sfx"},
	{"name": "duck", "image": preload("res://gui/animalsquiz/split_images/duck.png"), "sound_node": "duck_sfx"},
	{"name": "elephant", "image": preload("res://gui/animalsquiz/split_images/elephant.png"), "sound_node": "elephant_sfx"},
	{"name": "fox", "image": preload("res://gui/animalsquiz/split_images/fox.png"), "sound_node": "fox_sfx"},
	{"name": "frog", "image": preload("res://gui/animalsquiz/split_images/frog.png"), "sound_node": "frog_sfx"},
	{"name": "giraffe", "image": preload("res://gui/animalsquiz/split_images/giraffe.png"), "sound_node": "giraffe_sfx"},
	{"name": "monkey", "image": preload("res://gui/animalsquiz/split_images/monkey.png"), "sound_node": "monkey_sfx"},
	{"name": "racoon", "image": preload("res://gui/animalsquiz/split_images/racoon.png"), "sound_node": "racoon_sfx"}
]

# Game state
var current_animal_index = 0
var selected_animals = []
var game_cards = []
var flipped_cards = []
var matched_pairs = 0
var attempts = 0
var is_checking_match = false
var completion_celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")

func _speak_text_simple(text: String):
	"""Simple TTS without captions"""
	if tts:
		tts.speak(text)

func _ready():
	print("FlipQuizAnimals: Animal flip quiz loaded")
	
	# Enhanced fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Initialize helpers
	_init_tts()
	_init_module_progress()
	
	# Connect hover events
	_connect_hover_events()
	
	# Initialize animals for the game
	_initialize_game()
	
	# Load progress from Firestore
	await _load_progress()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window regains focus
		call_deferred("_refresh_progress")

func _refresh_progress():
	"""Refresh progress display when user returns"""
	if module_progress:
		await _load_progress()

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)

func _init_module_progress():
	if Engine.has_singleton("Firebase"):
		module_progress = ModuleProgress.new()
		add_child(module_progress)
	else:
		print("FlipQuizAnimals: Firebase not available; progress won't sync")

func _connect_hover_events():
	# Connect all button hover events and press events
	var buttons = [
		$MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton,
		$MainContainer/ContentContainer/InstructionPanel/GuideButton,
		$MainContainer/ContentContainer/InstructionPanel/TTSSettingButton,
		$MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton,
		$MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/HearButton,
		$MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	]
	
	for button in buttons:
		if button and not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)
	
	# Connect specific button presses
	var back_btn = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton
	if back_btn and not back_btn.pressed.is_connected(_on_back_button_pressed):
		back_btn.pressed.connect(_on_back_button_pressed)
	
	var guide_btn = $MainContainer/ContentContainer/InstructionPanel/GuideButton
	if guide_btn and not guide_btn.pressed.is_connected(_on_guide_button_pressed):
		guide_btn.pressed.connect(_on_guide_button_pressed)

	var tts_btn = $MainContainer/ContentContainer/InstructionPanel/TTSSettingButton
	if tts_btn and not tts_btn.pressed.is_connected(_on_tts_setting_button_pressed):
		tts_btn.pressed.connect(_on_tts_setting_button_pressed)
	
	var prev_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton
	if prev_btn and not prev_btn.pressed.is_connected(_on_previous_button_pressed):
		prev_btn.pressed.connect(_on_previous_button_pressed)
	
	var hear_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/HearButton
	if hear_btn and not hear_btn.pressed.is_connected(_on_hear_button_pressed):
		hear_btn.pressed.connect(_on_hear_button_pressed)
	
	var next_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	if next_btn and not next_btn.pressed.is_connected(_on_next_button_pressed):
		next_btn.pressed.connect(_on_next_button_pressed)

func _initialize_game():
	"""Initialize the flip quiz game with 4 animals"""
	# Select 4 animals randomly for the game
	animals.shuffle()
	selected_animals = animals.slice(0, 4)
	current_animal_index = 0
	matched_pairs = 0
	attempts = 0
	
	# Update instruction for current animal
	_update_instruction()
	_update_navigation_buttons()
	
	# Create flip cards
	_create_flip_cards()
	_update_score_display()

func _update_instruction():
	"""Update the instruction text for current animal"""
	if current_animal_index < selected_animals.size():
		var animal = selected_animals[current_animal_index]
		var instruction_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
		instruction_label.text = "Find pairs for: " + animal.name.capitalize() + "!"
	else:
		var instruction_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
		instruction_label.text = "Great job! You've seen all animals!"

func _update_navigation_buttons():
	"""Update visibility of previous/next buttons"""
	var prev_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton
	var next_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	
	# Previous button only visible if not at the beginning
	prev_btn.visible = current_animal_index > 0
	
	# Next button always visible for practice mode
	next_btn.visible = true

func _create_flip_cards():
	"""Create flip cards for the memory game"""
	var cards_container = $MainContainer/ContentContainer/GamePanel/GameContainer/CardsContainer
	
	# Clear existing cards
	for child in cards_container.get_children():
		child.queue_free()
	
	# Clear game state
	game_cards.clear()
	flipped_cards.clear()
	
	# Create cards: 4 image cards + 4 text cards = 8 total
	var all_cards = []
	
	# Add image cards
	for animal in selected_animals:
		all_cards.append({"type": "image", "animal": animal, "id": animal.name})
	
	# Add text cards
	for animal in selected_animals:
		all_cards.append({"type": "text", "animal": animal, "id": animal.name})
	
	# Shuffle the cards
	all_cards.shuffle()
	
	# Create card buttons with dyslexia-friendly design
	for i in range(all_cards.size()):
		var card_data = all_cards[i]
		var card_button = Button.new()
		card_button.custom_minimum_size = Vector2(140, 120) # Large, easy to click
		card_button.name = "Card_" + str(i)
		
		# Style the card
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color.WHITE
		card_style.border_width_left = 3
		card_style.border_width_right = 3
		card_style.border_width_top = 3
		card_style.border_width_bottom = 3
		card_style.border_color = Color.BLACK
		card_style.corner_radius_top_left = 10
		card_style.corner_radius_top_right = 10
		card_style.corner_radius_bottom_left = 10
		card_style.corner_radius_bottom_right = 10
		card_button.add_theme_stylebox_override("normal", card_style)
		card_button.add_theme_stylebox_override("hover", card_style)
		card_button.add_theme_stylebox_override("pressed", card_style)
		
		# Set card face-down initially
		card_button.text = "?"
		card_button.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
		card_button.add_theme_font_size_override("font_size", 48)
		
		# Store card data
		card_button.set_meta("card_data", card_data)
		card_button.set_meta("is_flipped", false)
		card_button.set_meta("is_matched", false)
		
		# Connect signal
		card_button.pressed.connect(_on_card_pressed.bind(card_button))
		card_button.mouse_entered.connect(_on_button_hover)
		
		cards_container.add_child(card_button)
		game_cards.append(card_button)

func _on_card_pressed(card: Button):
	"""Handle card flip with dyslexia-friendly feedback"""
	$ButtonClick.play()
	
	# Don't flip if already flipped, matched, or checking match
	if card.get_meta("is_flipped") or card.get_meta("is_matched") or is_checking_match:
		return
	
	# Don't allow more than 2 cards flipped at once
	if flipped_cards.size() >= 2:
		return
	
	# Flip the card
	var card_data = card.get_meta("card_data")
	card.set_meta("is_flipped", true)
	
	# Show card content
	if card_data.type == "image":
		card.icon = card_data.animal.image
		card.text = ""
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.expand_icon = true
	else: # text card
		card.text = card_data.animal.name.capitalize()
		card.icon = null
		card.add_theme_font_size_override("font_size", 24)
	
	flipped_cards.append(card)
	
	# Check for matches when 2 cards are flipped
	if flipped_cards.size() == 2:
		is_checking_match = true
		await get_tree().create_timer(1.5).timeout # Give time to see both cards
		_check_match()

func _check_match():
	"""Check if flipped cards match with encouraging feedback"""
	if flipped_cards.size() != 2:
		is_checking_match = false
		return
	
	var card1 = flipped_cards[0]
	var card2 = flipped_cards[1]
	var data1 = card1.get_meta("card_data")
	var data2 = card2.get_meta("card_data")
	
	attempts += 1
	
	if data1.id == data2.id: # Match found!
		# Mark as matched
		card1.set_meta("is_matched", true)
		card2.set_meta("is_matched", true)
		
		# Visual feedback for match
		var match_style = StyleBoxFlat.new()
		match_style.bg_color = Color(0.2, 0.8, 0.2, 1) # Green background
		match_style.border_width_left = 3
		match_style.border_width_right = 3
		match_style.border_width_top = 3
		match_style.border_width_bottom = 3
		match_style.border_color = Color.BLACK
		match_style.corner_radius_top_left = 10
		match_style.corner_radius_top_right = 10
		match_style.corner_radius_bottom_left = 10
		match_style.corner_radius_bottom_right = 10
		
		card1.add_theme_stylebox_override("normal", match_style)
		card2.add_theme_stylebox_override("normal", match_style)
		
		matched_pairs += 1
		print("FlipQuizAnimals: Match found! ", data1.animal.name)
		
		# Play animal sound (animals category uniquely uses SFX)
		var sound_node = get_node_or_null(data1.animal.sound_node)
		if sound_node:
			sound_node.play()
		
		# Give encouraging feedback
		_show_match_feedback(data1.animal.name)
		
		# Check if all pairs are matched
		if matched_pairs >= selected_animals.size():
			await get_tree().create_timer(2.0).timeout
			_complete_game()
	else:
		# No match - flip cards back after a moment
		await get_tree().create_timer(1.0).timeout
		
		# Reset cards to face-down
		card1.text = "?"
		card1.icon = null
		card1.add_theme_font_size_override("font_size", 48)
		card1.set_meta("is_flipped", false)
		
		card2.text = "?"
		card2.icon = null
		card2.add_theme_font_size_override("font_size", 48)
		card2.set_meta("is_flipped", false)
		
		# Reset to default style
		var default_style = StyleBoxFlat.new()
		default_style.bg_color = Color.WHITE
		default_style.border_width_left = 3
		default_style.border_width_right = 3
		default_style.border_width_top = 3
		default_style.border_width_bottom = 3
		default_style.border_color = Color.BLACK
		default_style.corner_radius_top_left = 10
		default_style.corner_radius_top_right = 10
		default_style.corner_radius_bottom_left = 10
		default_style.corner_radius_bottom_right = 10
		
		card1.add_theme_stylebox_override("normal", default_style)
		card2.add_theme_stylebox_override("normal", default_style)
	
	flipped_cards.clear()
	is_checking_match = false
	_update_score_display()

func _show_match_feedback(animal_name: String):
	"""Show encouraging feedback for matches"""
	var encouragement_label = $MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/EncouragementLabel
	encouragement_label.text = "Great match! " + animal_name.capitalize() + " found!"
	
	# Use TTS to give positive feedback
	if tts:
		_speak_text_simple("Great job! You found " + animal_name + "!")

func _complete_game():
	"""Handle game completion with celebration"""
	print("FlipQuizAnimals: Game completed!")
	
	# Update progress in Firebase using generic set completion
	if module_progress:
		var success = await module_progress.set_flip_quiz_set_completed("Animals")
		if success:
			print("FlipQuizAnimals: Progress saved to Firebase (Animals set)")
	
	# Show completion celebration
	_show_completion_celebration()

func _show_completion_celebration():
	"""Show completion celebration popup"""
	var celebration = completion_celebration_scene.instantiate()
	add_child(celebration)
	
	# Calculate progress for celebration display
	var progress_data = {
		"current": matched_pairs,
		"total": selected_animals.size(),
		"percentage": 100.0
	}
	
	celebration.show_completion("flip_quiz", "Animal Memory Game", progress_data, "animals")
	
	# Connect celebration signals
	if celebration.has_signal("try_again_pressed"):
		celebration.try_again_pressed.connect(_on_celebration_try_again)
	if celebration.has_signal("next_item_pressed"):
		celebration.next_item_pressed.connect(_on_celebration_continue)

func _on_celebration_try_again():
	"""Restart the game"""
	_initialize_game()

func _on_celebration_continue():
	"""Continue to next or restart"""
	_initialize_game()

func _update_score_display():
	"""Update score display with encouraging messages"""
	var score_label = get_node_or_null("MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/ScoreLabel")
	var attempts_label = get_node_or_null("MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/AttemptsLabel")
	var encouragement_label = get_node_or_null("MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/EncouragementLabel")

	if score_label:
		score_label.text = "Matches: " + str(matched_pairs) + "/" + str(selected_animals.size())
	if attempts_label:
		attempts_label.text = "Attempts: " + str(attempts)

	if encouragement_label:
		if matched_pairs == 0:
			encouragement_label.text = "Take your time!"
		elif matched_pairs < float(selected_animals.size()) / 2.0:
			encouragement_label.text = "Great start!"
		elif matched_pairs < selected_animals.size():
			encouragement_label.text = "Almost there!"
		else:
			encouragement_label.text = "Amazing work!"

func _load_progress():
	"""Load progress from Firebase"""
	if not module_progress:
		return
	
	var firebase_modules = await module_progress.fetch_modules()
	if firebase_modules.size() > 0:
		_update_progress_display(firebase_modules)

func _update_progress_display(firebase_modules: Dictionary):
	"""Update progress display using unified flip_quiz module"""
	var progress_percent = 0.0
	if firebase_modules.has("flip_quiz"):
		var fq = firebase_modules["flip_quiz"]
		if typeof(fq) == TYPE_DICTIONARY:
			var sets_completed = fq.get("sets_completed", [])
			# Animals set counts as 1 of the 10 total
			if sets_completed.has("Animals"):
				# Show partial progress relative to the Animals game itself
				progress_percent = 100.0
	
	# Update progress display
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	
	if progress_label:
		progress_label.text = str(int(progress_percent)) + "% Complete"
	if progress_bar:
		progress_bar.value = progress_percent

func _on_button_hover():
	$ButtonHover.play()

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to the Animal Memory Game! This is a flip card game where you match animals with their words. Flip two cards to find a pair. Animal sounds will help you remember. Take your time and have fun learning!"
		_speak_text_simple(guide_text)

func _on_tts_setting_button_pressed():
	$ButtonClick.play()
	print("FlipQuizAnimals: Looking for TTSSettingsPopup (robust lookup)...")
	var tts_popup = get_node_or_null("TTSSettingsPopup")
	if not tts_popup:
		tts_popup = find_child("TTSSettingsPopup", true, false)
	if not tts_popup:
		print("FlipQuizAnimals: TTSSettingsPopup not found - instantiating dynamically")
		var popup_scene: PackedScene = load("res://Scenes/TTSSettingsPopup.tscn")
		if popup_scene:
			tts_popup = popup_scene.instantiate()
			tts_popup.name = "TTSSettingsPopup"
			add_child(tts_popup)
	print("FlipQuizAnimals: TTSSettingsPopup final status:", tts_popup != null)
	if tts_popup:
		# Setup popup with current settings
		var current_voice = SettingsManager.get_setting("accessibility", "tts_voice_id")
		var current_rate = SettingsManager.get_setting("accessibility", "tts_rate")
		
		# Provide safe defaults
		if current_voice == null or current_voice == "":
			current_voice = "default"
		if current_rate == null:
			current_rate = 1.0
		
		# Pass current TTS instance to popup for voice testing
		if tts_popup.has_method("set_tts_instance"):
			tts_popup.set_tts_instance(tts)
		
		if tts_popup.has_method("setup"):
			tts_popup.setup(tts, current_voice, current_rate, "Testing Text to Speech")
		
		# Connect to save signal if not already connected
		if not tts_popup.settings_saved.is_connected(_on_tts_settings_saved):
			tts_popup.settings_saved.connect(_on_tts_settings_saved)
		
		tts_popup.visible = true
		print("FlipQuizAnimals: TTS Settings popup opened")
	else:
		print("FlipQuizAnimals: Warning - TTSSettingsPopup still not found after dynamic attempt")

func _on_tts_settings_saved(voice_id: String, rate: float):
	"""Handle TTS settings save"""
	print("FlipQuizAnimals: Saving TTS preferences - Voice: ", voice_id, " Rate: ", rate)
	
	# Update current TTS instance
	if tts:
		if voice_id != null and voice_id != "":
			tts.set_voice(voice_id)
		if rate != null:
			tts.set_rate(rate)
	
	# Store in SettingsManager for persistence
	if SettingsManager:
		SettingsManager.set_setting("accessibility", "tts_voice_id", voice_id)
		SettingsManager.set_setting("accessibility", "tts_rate", rate)

func _on_back_button_pressed():
	$ButtonClick.play()
	print("FlipQuizAnimals: Returning to flip quiz module")
	_fade_out_and_change_scene("res://Scenes/FlipQuizModule.tscn")

func _on_previous_button_pressed():
	$ButtonClick.play()
	if current_animal_index > 0:
		current_animal_index -= 1
		_update_instruction()
		_update_navigation_buttons()
		
		# Speak the animal name
		if current_animal_index < selected_animals.size():
			var animal = selected_animals[current_animal_index]
			if tts:
				_speak_text_simple("Now focusing on " + animal.name)

func _on_hear_button_pressed():
	$ButtonClick.play()
	if current_animal_index < selected_animals.size():
		var animal = selected_animals[current_animal_index]
		
		# Play animal sound
		var sound_node = get_node_or_null(animal.sound_node)
		if sound_node:
			sound_node.play()
		
		# Also speak the animal name
		if tts:
			_speak_text_simple(animal.name.capitalize())

func _on_next_button_pressed():
	$ButtonClick.play()
	if current_animal_index < selected_animals.size() - 1:
		current_animal_index += 1
	else:
		# Loop back to beginning for practice mode
		current_animal_index = 0
	
	_update_instruction()
	_update_navigation_buttons()
	
	# Speak the animal name
	if current_animal_index < selected_animals.size():
		var animal = selected_animals[current_animal_index]
		if tts:
			_speak_text_simple("Now focusing on " + animal.name)

func _fade_out_and_change_scene(scene_path: String):
	# Stop any playing TTS before changing scenes
	_stop_tts()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _stop_tts():
	if tts and tts.has_method("stop"):
		tts.stop()
		print("FlipQuizAnimals: TTS stopped before scene change")

func _exit_tree():
	_stop_tts()
