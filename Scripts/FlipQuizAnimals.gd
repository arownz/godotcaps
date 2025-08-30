extends Control

var tts: TextToSpeech = null

# Animal data with images and sounds - Updated with all available animals
var animals = [
	{"name": "cat", "image": preload("res://gui/animalsquiz/split_images/cat.png"), "sound_node": "cat_sfx"},
	{"name": "duck", "image": preload("res://gui/animalsquiz/split_images/duck.png"), "sound_node": "duck_sfx"},
	{"name": "elephant", "image": preload("res://gui/animalsquiz/split_images/elephant.png"), "sound_node": "elephant_sfx"},
	{"name": "fox", "image": preload("res://gui/animalsquiz/split_images/fox.png"), "sound_node": "fox_sfx"},
	{"name": "frog", "image": preload("res://gui/animalsquiz/split_images/frog.png"), "sound_node": "frog_sfx"},
	{"name": "giraffe", "image": preload("res://gui/animalsquiz/split_images/giraffe.png"), "sound_node": "giraffe_sfx"},
	{"name": "monkey", "image": preload("res://gui/animalsquiz/split_images/monkey.png"), "sound_node": "monkey_sfx"},
	{"name": "racoon", "image": preload("res://gui/animalsquiz/split_images/racoon.png"), "sound_node": "racoon_sfx"},
	{"name": "bear", "image": preload("res://gui/animalsquiz/split_images/bear.jpg"), "sound_node": "bear_sfx"},
	{"name": "bunny", "image": preload("res://gui/animalsquiz/split_images/bunny.jpg"), "sound_node": "bunny_sfx"},
	{"name": "chicken", "image": preload("res://gui/animalsquiz/split_images/chicken.jpg"), "sound_node": "chicken_sfx"},
	{"name": "dog", "image": preload("res://gui/animalsquiz/split_images/dog.jpg"), "sound_node": "dog_sfx"},
	{"name": "lion", "image": preload("res://gui/animalsquiz/split_images/lion.jpg"), "sound_node": "lion_sfx"},
	{"name": "tiger", "image": preload("res://gui/animalsquiz/split_images/tiger.jpg"), "sound_node": "tiger_sfx"}
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

# Track current set index (0-based)
var current_set_index = 0
var total_sets = 3
var sets_completed = []

func _speak_text_simple(text: String):
	"""Simple TTS without captions"""
	if tts:
		tts.speak(text)

func _load_progress_from_firebase():
	"""Load flip quiz progress from Firebase using authentication.gd pattern"""
	if not Firebase.Auth.auth:
		print("FlipQuizAnimals: Firebase not authenticated")
		return
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Use authentication.gd pattern: direct document fetch
	print("FlipQuizAnimals: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("FlipQuizAnimals: Document fetched successfully")
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY:
			var flip_quiz_data = modules.get("flip_quiz", {})
			if typeof(flip_quiz_data) == TYPE_DICTIONARY:
				sets_completed = flip_quiz_data.get("sets_completed", [])
				print("FlipQuizAnimals: Loaded completed sets: ", sets_completed)
				# Set current_set_index to number of completed sets (advance to next set)
				current_set_index = sets_completed.size()
				# Clamp to total_sets
				if current_set_index >= total_sets:
					current_set_index = total_sets - 1
				# Update local progress based on Firebase data
				_update_local_progress_from_firebase(sets_completed)
				# Update progress display
				_update_progress_display(modules)
		else:
			print("FlipQuizAnimals: No modules data found")
	else:
		print("FlipQuizAnimals: Failed to fetch document or document has error")

func _update_local_progress_from_firebase(completed_sets: Array):
	"""Update local progress display based on Firebase data"""
	# Print completed sets for debug
	print("FlipQuizAnimals: Processing completed sets from Firebase: ", completed_sets.size(), " sets completed: ", completed_sets)

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
	
	# Load progress from Firebase
	await _load_progress_from_firebase()
	
	# Initialize animals for the game
	_initialize_game()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window regains focus
		call_deferred("_refresh_progress")

func _refresh_progress():
	"""Refresh progress display when user returns"""
	await _load_progress()

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)

	# Load TTS settings
	var voice_id = SettingsManager.get_setting("accessibility", "tts_voice_id")
	var rate = SettingsManager.get_setting("accessibility", "tts_rate")
	
	if voice_id != null and voice_id != "":
		tts.set_voice(voice_id)
	if rate != null:
		tts.set_rate(rate)

func _init_module_progress():
	# Use same Firebase pattern as authentication.gd (which works)
	print("FlipQuizAnimals: Initializing Firebase access")
	
	# Wait for Firebase to be ready (like authentication.gd does)
	await get_tree().process_frame
	
	# Check Firebase availability using authentication.gd pattern (no Engine.has_singleton check)
	if not Firebase or not Firebase.Auth:
		print("FlipQuizAnimals: Firebase or Firebase.Auth not available")
		return
	
	# Check authentication status (exact authentication.gd pattern)
	if Firebase.Auth.auth == null:
		print("FlipQuizAnimals: No authenticated user")
		return
	
	if not Firebase.Auth.auth.localid:
		print("FlipQuizAnimals: No localid available")
		return
	
	print("FlipQuizAnimals: Firebase authenticated successfully for user: ", Firebase.Auth.auth.localid)
	
	# Test Firestore access (exact authentication.gd pattern)
	if Firebase.Firestore == null:
		print("FlipQuizAnimals: ERROR - Firestore is null")
		return
	
	print("FlipQuizAnimals: Firestore available - ready for progress updates")

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
	"""Initialize the flip quiz game for the current set"""
	# Select 4 animals for the current set (allow repeats, but shuffle for variety)
	animals.shuffle()
	var offset = (current_set_index * 4) % animals.size()
	selected_animals = []
	for i in range(4):
		selected_animals.append(animals[(offset + i) % animals.size()])
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
	"""Update the instruction text for current animal with dyslexia-friendly formatting"""
	if current_animal_index < selected_animals.size():
		var animal = selected_animals[current_animal_index]
		var instruction_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
		if instruction_label:
			instruction_label.text = "Find pairs for: " + animal.name.capitalize() + "!"
			# Apply dyslexia-friendly font and larger size
			instruction_label.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
			instruction_label.add_theme_font_size_override("font_size", 48)
			instruction_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.8, 1)) # Clear blue color
			instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var instruction_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
		if instruction_label:
			instruction_label.text = "Great job! You've seen all animals!"
			instruction_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 1)) # Green for completion

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
		card_button.custom_minimum_size = Vector2(160, 140) # Larger cards for better text display
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
		
		# Add empty style for focus to remove default focus border
		var empty_style = StyleBoxEmpty.new()
		card_button.add_theme_stylebox_override("focus", empty_style)
		
		# Set card face-down initially with black font color
		card_button.text = "?"
		card_button.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
		card_button.add_theme_font_size_override("font_size", 48)
		card_button.add_theme_color_override("font_color", Color.BLACK)
		card_button.add_theme_color_override("font_hover_color", Color.BLACK)
		card_button.add_theme_color_override("font_pressed_color", Color.BLACK)
		card_button.add_theme_color_override("font_focus_color", Color.BLACK)
		
		# Set mouse cursor to pointer for better UX
		card_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
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
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else: # text card - dyslexia-friendly text display
		card.text = card_data.animal.name.capitalize()
		card.icon = null
		# Use larger font size to prevent overlapping and improve readability
		card.add_theme_font_size_override("font_size", 18)
		# Ensure black font color for better readability
		card.add_theme_color_override("font_color", Color.BLACK)
		card.add_theme_color_override("font_hover_color", Color.BLACK)
		card.add_theme_color_override("font_pressed_color", Color.BLACK)
		card.add_theme_color_override("font_focus_color", Color.BLACK)
		# Text centering is handled automatically by Button in Godot 4.x
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Ensure adequate padding to prevent text overlap
		card.add_theme_constant_override("text_margin_left", 8)
		card.add_theme_constant_override("text_margin_right", 8)
		card.add_theme_constant_override("text_margin_top", 8)
		card.add_theme_constant_override("text_margin_bottom", 8)
	
	flipped_cards.append(card)
	
	# Check for matches when 2 cards are flipped
	if flipped_cards.size() == 2:
		is_checking_match = true
		# Give more time for dyslexic children to process information
		await get_tree().create_timer(1.0).timeout
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
		# No match - give more time for dyslexic children to process before flipping back
		await get_tree().create_timer(1.0).timeout # Increased from 1.0 to 2.0 seconds
		
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
	"""Show encouraging feedback for matches with dyslexia-friendly design"""
	var encouragement_label = $MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/EncouragementLabel
	if encouragement_label:
		# Clear, simple positive feedback
		encouragement_label.text = "Great! " + animal_name.capitalize() + " found!"
		
		# Make text larger and easier to read for dyslexic children
		encouragement_label.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
		encouragement_label.add_theme_font_size_override("font_size", 20)
		encouragement_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 1)) # Green color for positive feedback
		
		# Animate the feedback for better visual impact
		encouragement_label.modulate.a = 0.0
		encouragement_label.scale = Vector2(0.8, 0.8)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(encouragement_label, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
		tween.tween_property(encouragement_label, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT)
		
		# Clear the message after some time
	await get_tree().create_timer(3.0).timeout
	if encouragement_label:
		var fade_tween = create_tween()
		fade_tween.tween_property(encouragement_label, "modulate:a", 0.0, 1.0)

	# Play narrator guide first, then animal sound (no overlap)
	if tts:
		var feedback_text = "You found the " + animal_name + "!"
		tts.speak(feedback_text)
		# Wait for TTS to finish using a timer (approximate duration)
		var timer = Timer.new()
		timer.wait_time = 1.5
		timer.one_shot = true
		add_child(timer)
		await timer.timeout
		timer.queue_free()
		var sound_node = get_node_or_null(animal_name + "_sfx")
		if sound_node:
			sound_node.play()

func _complete_game():
	"""Handle game completion with celebration"""
	print("FlipQuizAnimals: Game completed!")
	
	# Update progress in Firebase using direct authentication.gd pattern
	if Firebase.Auth.auth:
		var set_id = "animals_set_" + str(current_set_index + 1)
		var success = await _save_flip_quiz_completion_to_firebase(set_id)
		if success:
			print("FlipQuizAnimals: Progress saved to Firebase (" + set_id + ")")
	
	# Show completion celebration
	_show_completion_celebration()
	# Update progress bar/label after completion
	await _load_progress_from_firebase()

func _show_completion_celebration():
	"""Show completion celebration popup"""
	var celebration = completion_celebration_scene.instantiate()
	add_child(celebration)
	
	# Calculate progress for celebration display
	var percent = (float(sets_completed.size()) / float(total_sets)) * 100.0
	var progress_data = {
		"sets_completed": sets_completed,
		"total_sets": total_sets,
		"percent": percent
	}
	var set_title = "Set " + str(current_set_index + 1)
	celebration.show_completion(celebration.CompletionType.FLIP_ANIMAL, set_title, progress_data, "flip_quiz")

	# Connect celebration signals
	if celebration.has_signal("try_again_pressed"):
		celebration.try_again_pressed.connect(_on_celebration_try_again)
	if celebration.has_signal("next_item_pressed"):
		celebration.next_item_pressed.connect(_on_celebration_next_set)

func _on_celebration_try_again():
	"""Restart the game"""
	_initialize_game()

func _on_celebration_next_set():
	"""Advance to next set and re-initialize game"""
	if sets_completed.size() < total_sets:
		current_set_index = sets_completed.size()
		_initialize_game()
	else:
		print("FlipQuizAnimals: All sets completed!")

func _update_score_display():
	"""Update score display with encouraging messages"""
	var score_label = get_node_or_null("MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/ScoreLabel")
	var attempts_label = get_node_or_null("MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/AttemptsLabel")

	if score_label:
		score_label.text = "Matches: " + str(matched_pairs) + "/" + str(selected_animals.size())
	if attempts_label:
		attempts_label.text = "Attempts: " + str(attempts)

func _load_progress():
	"""Load progress from Firebase"""
	if not Firebase.Auth.auth:
		print("FlipQuizAnimals: Firebase not available or not authenticated")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Use working authentication.gd pattern: direct document fetch
	print("FlipQuizAnimals: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("FlipQuizAnimals: Document fetched successfully")
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY:
			_update_progress_display(modules)
		else:
			print("FlipQuizAnimals: No modules data found")
	else:
		print("FlipQuizAnimals: Failed to fetch document or document has error")

func _update_progress_display(firebase_modules: Dictionary):
	"""Update overall Flip Quiz progress (completed sets/total sets)"""
	var completed_array = []
	if firebase_modules.has("flip_quiz"):
		var fq = firebase_modules["flip_quiz"]
		if typeof(fq) == TYPE_DICTIONARY:
			completed_array = fq.get("sets_completed", [])
	var percent := (float(completed_array.size()) / float(total_sets)) * 100.0
	# Update overall progress bar/label
	var overall_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	if overall_bar:
		overall_bar.value = percent
	# Update Animals card progress bar/label if present
	var animals_label = get_node_or_null("MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel")
	if animals_label:
		animals_label.text = str(completed_array.size()) + "/" + str(total_sets) + " sets" + " Complete"

func _on_button_hover():
	$ButtonHover.play()

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		# Simpler, clearer instructions for dyslexic children
		var guide_text = "This is a memory game! Find two cards that match. One card has a picture of an animal. The other card has the animal's name. When you find a match, you'll hear the animal sound!"
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
		
		# Play animal sound first (primary hint)
		var sound_node = get_node_or_null(animal.sound_node)
		if sound_node:
			sound_node.play()
		
		# Wait a moment, then speak the animal name clearly (secondary hint)
		await get_tree().create_timer(2.0).timeout
		if tts:
			var hint_text = animal.name.capitalize() + ". Find the picture and the word!"
			_speak_text_simple(hint_text)
		
		# Visual hint: briefly highlight the target animal name in the instruction
		var instruction_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
		if instruction_label:
			var original_color = instruction_label.get_theme_color("font_color")
			instruction_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0, 1)) # Orange highlight
			await get_tree().create_timer(2.0).timeout
			instruction_label.add_theme_color_override("font_color", original_color)

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

# Direct Firebase flip quiz completion update using working authentication.gd pattern
func _save_flip_quiz_completion_to_firebase(quiz_set_name: String) -> bool:
	"""Save flip quiz set completion to Firebase using EXACT authentication.gd pattern"""
	print("FlipQuizAnimals: _save_flip_quiz_completion_to_firebase called with set: ", quiz_set_name)
	
	# Check authentication using EXACT authentication.gd pattern
	if Firebase.Auth.auth == null:
		print("FlipQuizAnimals: No authenticated user, returning false")
		return false
	
	var user_id = Firebase.Auth.auth.localid
	print("FlipQuizAnimals: Loading data for user ID: ", user_id)
	
	# Check Firestore using EXACT authentication.gd pattern
	if Firebase.Firestore == null:
		print("FlipQuizAnimals: ERROR - Firestore is null, returning false")
		return false
	
	# Use EXACT authentication.gd collection pattern
	var collection = Firebase.Firestore.collection("dyslexia_users")
	print("FlipQuizAnimals: Attempting to fetch document with ID: ", user_id)
	
	# Use EXACT authentication.gd await pattern
	var document = await collection.get_doc(user_id)
	
	# Use EXACT authentication.gd error checking pattern
	if document != null:
		print("FlipQuizAnimals: Document received")
		
		# Check for errors using EXACT authentication.gd pattern
		var has_error = false
		var error_data = null
		
		if document.has_method("keys"):
			var doc_keys = document.keys()
			
			if "error" in doc_keys:
				error_data = document.get_value("error")
				if error_data:
					has_error = true
					print("FlipQuizAnimals: Error in document: ", error_data)
					return false
			
			if !has_error:
				# Process document using nested structure pattern from authentication.gd
				print("FlipQuizAnimals: Document retrieved successfully")
				
				# Get modules data (create if missing)
				var modules = document.get_value("modules")
				if modules == null or typeof(modules) != TYPE_DICTIONARY:
					print("FlipQuizAnimals: Creating modules structure")
					modules = {
						"flip_quiz": {
							"completed": false,
							"progress": 0,
							"sets_completed": []
						}
					}
				
				# Ensure flip_quiz module exists
				if !modules.has("flip_quiz"):
					print("FlipQuizAnimals: Creating flip_quiz module")
					modules["flip_quiz"] = {
						"completed": false,
						"progress": 0,
						"sets_completed": []
					}
				
				var flip_quiz_data = modules["flip_quiz"]
				sets_completed = flip_quiz_data.get("sets_completed", [])
				
				var set_lower = quiz_set_name.to_lower()
				print("FlipQuizAnimals: Current sets completed: ", sets_completed)
				
				if not sets_completed.has(set_lower):
					print("FlipQuizAnimals: Adding new set: ", set_lower)
					sets_completed.append(set_lower)
					flip_quiz_data["sets_completed"] = sets_completed
					
					# total_sets is already a class variable
					var progress_percent = min(100, (float(sets_completed.size()) / float(total_sets)) * 100)
					
					print("FlipQuizAnimals: Total sets: ", sets_completed.size())
					print("FlipQuizAnimals: Calculated progress: ", progress_percent, "%")
					
					flip_quiz_data["progress"] = progress_percent
					flip_quiz_data["completed"] = progress_percent >= 100
					modules["flip_quiz"] = flip_quiz_data
					
					# Update document using EXACT authentication.gd pattern
					document.add_or_update_field("modules", modules)
					
					# Save using EXACT authentication.gd pattern
					print("FlipQuizAnimals: About to update document with modules: ", modules)
					var updated_document = await collection.update(document)
					
					# Check if update was successful
					if updated_document != null:
						print("FlipQuizAnimals: ✓ Set '", set_lower, "' saved to Firebase. Progress: ", progress_percent, "%")
						return true
					else:
						print("FlipQuizAnimals: Failed to update document")
						return false
				else:
					print("FlipQuizAnimals: Set '", set_lower, "' already completed")
					return true
			else:
				print("FlipQuizAnimals: Document has no keys method")
				return false
	else:
		print("FlipQuizAnimals: Failed to get document for flip quiz completion update")
		return false
	
	# Fallback return (should never be reached)
	return false
