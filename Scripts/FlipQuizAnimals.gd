extends Control

var tts: TextToSpeech = null
var module_progress = null # ModuleProgress.gd instance for centralized Firebase operations

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
	
	# Load progress from ModuleProgress
	await _load_progress_from_firebase()
	
	# Initialize animals for the game
	_initialize_game()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window regains focus
		call_deferred("_refresh_progress")

func _refresh_progress():
	await _load_progress_from_firebase()

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	
	# Load TTS settings for dyslexia-friendly reading
	var voice_id = SettingsManager.get_setting("accessibility", "tts_voice_id")
	var rate = SettingsManager.get_setting("accessibility", "tts_rate")
	
	if voice_id != null and voice_id != "":
		tts.set_voice(voice_id)
	if rate != null:
		tts.set_rate(rate)

func _init_module_progress():
	if Firebase and Firebase.Auth and Firebase.Auth.auth:
		module_progress = ModuleProgress.new()
		print("FlipQuizAnimals: ModuleProgress initialized")
	else:
		print("FlipQuizAnimals: Firebase not available")

func _load_progress_from_firebase():
	"""Load flip quiz progress from Firebase using ModuleProgress"""
	if not module_progress or not module_progress.is_authenticated():
		print("FlipQuizAnimals: Module progress not available or not authenticated")
		return
	
	var flip_quiz_data = await module_progress.get_flip_quiz_progress()
	if flip_quiz_data and flip_quiz_data.has("animals"):
		var animals_data = flip_quiz_data["animals"]
		sets_completed = animals_data.get("sets_completed", [])
		print("FlipQuizAnimals: Loaded completed animal sets: ", sets_completed)
		
		# Set current_set_index to next uncompleted set OR find first uncompleted set
		var resume_set_index = sets_completed.size()
		
		# Load saved current position
		var saved_index = animals_data.get("current_index", 0)
		var saved_set_from_index = saved_index / 4 # Each set has 4 animals
		
		# Check if saved position is in a completed set
		var saved_set_id = "animals_set_" + str(saved_set_from_index + 1)
		if saved_set_id in sets_completed:
			print("FlipQuizAnimals: Saved position is in completed set, advancing to next uncompleted")
			# Use next uncompleted set
			current_set_index = resume_set_index
		else:
			# Resume at saved set position if it's not completed
			current_set_index = saved_set_from_index
		
		# Ensure set index is within bounds
		if current_set_index >= total_sets:
			current_set_index = total_sets - 1
		
		# Set animal index to start of current set
		current_animal_index = saved_index if current_set_index == saved_set_from_index else 0
		
		print("FlipQuizAnimals: Resuming at set ", current_set_index, ", animal index: ", current_animal_index, " (saved was set ", saved_set_from_index, ", index ", saved_index, ")")
		
		# Update progress display
		_update_progress_display(flip_quiz_data)
	else:
		print("FlipQuizAnimals: No animal data found")

func _update_progress_display(flip_quiz_data: Dictionary):
	"""Update animals-specific progress display"""
	var animals_data = flip_quiz_data.get("animals", {})
	var completed_array = animals_data.get("sets_completed", [])
	var percent := (float(completed_array.size()) / float(total_sets)) * 100.0
	
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	if progress_bar:
		progress_bar.value = percent
	
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	if progress_label:
		progress_label.text = str(completed_array.size()) + "/" + str(total_sets) + " sets complete"

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
	"""Update instruction text showing remaining targets with current focus"""
	var instruction_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
	if not instruction_label:
		return
	
	# Get list of remaining (unmatched) animals
	var remaining_animals = []
	var matched_animal_names = []
	
	# Collect names of matched animals
	for card in game_cards:
		if card.get_meta("is_matched", false):
			var card_data = card.get_meta("card_data")
			if card_data and not matched_animal_names.has(card_data.animal.name):
				matched_animal_names.append(card_data.animal.name)
	
	# Build remaining animals list
	for animal in selected_animals:
		if not matched_animal_names.has(animal.name):
			remaining_animals.append(animal)
	
	if remaining_animals.size() > 0:
		# Show remaining targets with current focus highlighted in green for dyslexic children  
		var target_text = "Find: "
		for i in range(remaining_animals.size()):
			var animal = remaining_animals[i]
			if i == current_animal_index and current_animal_index < remaining_animals.size():
				# Highlight current target in green for visual clarity
				target_text += "[color=#00AA00]" + animal.name.capitalize() + "[/color]"
			else:
				target_text += animal.name.capitalize()
			
			if i < remaining_animals.size() - 1:
				target_text += ", "
		
		# Set BBCode text for color highlighting (RichTextLabel)
		instruction_label.bbcode_text = target_text
		
		instruction_label.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
		instruction_label.add_theme_font_size_override("font_size", 36) # Slightly smaller for longer text
		instruction_label.add_theme_color_override("font_color", Color.BLACK) # Default black color
		instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		# All targets completed - show replay message
		instruction_label.text = "Great job! All animals found!"
		instruction_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 1))

func _update_navigation_buttons():
	"""Update visibility of previous/next buttons"""
	var prev_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton
	var next_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	
	# Hide Previous button when at first target (index 0)
	prev_btn.visible = (current_animal_index > 0)
	
	# Hide Next button when at last target (no loop - last is end)
	next_btn.visible = (current_animal_index < selected_animals.size() - 1)

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
	
	# Play animal sound when card is flipped for dyslexic children learning pattern
	var sound_node = get_node_or_null(card_data.animal.sound_node)
	if sound_node:
		sound_node.play()
		print("FlipQuizAnimals: Playing sound on flip for ", card_data.animal.name)
	
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
		card1.add_theme_stylebox_override("hover", match_style)
		card1.add_theme_stylebox_override("pressed", match_style)
		card1.mouse_default_cursor_shape = Control.CURSOR_ARROW # Remove pointer cursor
		
		card2.add_theme_stylebox_override("normal", match_style)
		card2.add_theme_stylebox_override("hover", match_style)
		card2.add_theme_stylebox_override("pressed", match_style)
		card2.mouse_default_cursor_shape = Control.CURSOR_ARROW # Remove pointer cursor
		
		matched_pairs += 1
		print("FlipQuizAnimals: Match found! ", data1.animal.name)
		
		# Play animal sound (animals category uniquely uses SFX)
		var sound_node = get_node_or_null(data1.animal.sound_node)
		if sound_node:
			sound_node.play()
		
		# Update instruction to reflect completed target
		_update_instruction()
		_update_navigation_buttons()
		
		# Auto-advance to next unmatched target if current target was completed
		if current_animal_index < selected_animals.size():
			var current_animal_name = selected_animals[current_animal_index].name
			if current_animal_name == data1.animal.name:
				_advance_to_next_unmatched_target()
		
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

func _complete_game():
	"""Handle game completion"""
	print("FlipQuizAnimals: Game completed!")
	
	# Save progress using ModuleProgress
	if module_progress and module_progress.is_authenticated():
		var set_id = "animals_set_" + str(current_set_index + 1)
		var success = await module_progress.complete_flip_quiz_set("animals", set_id)
		if success:
			print("FlipQuizAnimals: Progress saved (" + set_id + ")")
			# Reload progress to update UI
			await _load_progress_from_firebase()
	
	_show_completion_celebration()

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
	var set_title = "Animal Set " + str(current_set_index + 1)
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
	"""Advance to next set or cycle back for open-ended play"""
	if sets_completed.size() < total_sets:
		# Still have uncompleted sets - advance normally
		current_set_index = sets_completed.size()
		_initialize_game()
	else:
		# All sets completed - cycle back to beginning for open-ended practice
		current_set_index = 0
		print("FlipQuizAnimals: All sets completed! Starting open-ended practice from Set 1")
		_initialize_game()

func _advance_to_next_unmatched_target():
	"""Advance to next unmatched target for focus"""
	var matched_animal_names = []
	
	# Collect matched animal names
	for card in game_cards:
		if card.get_meta("is_matched", false):
			var card_data = card.get_meta("card_data")
			if card_data and not matched_animal_names.has(card_data.animal.name):
				matched_animal_names.append(card_data.animal.name)
	
	# Find next unmatched animal
	var found_unmatched = false
	
	for i in range(selected_animals.size()):
		var check_index = (current_animal_index + i + 1) % selected_animals.size()
		if not matched_animal_names.has(selected_animals[check_index].name):
			current_animal_index = check_index
			found_unmatched = true
			break
	
	# If no unmatched found, cycle back to start of remaining
	if not found_unmatched:
		for i in range(selected_animals.size()):
			if not matched_animal_names.has(selected_animals[i].name):
				current_animal_index = i
				break

func _update_score_display():
	"""Update score display with encouraging messages"""
	var score_label = get_node_or_null("MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/ScoreLabel")
	var attempts_label = get_node_or_null("MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/AttemptsLabel")

	if score_label:
		score_label.text = "Matches: " + str(matched_pairs) + "/" + str(selected_animals.size())
	if attempts_label:
		attempts_label.text = "Attempts: " + str(attempts)

func _on_button_hover():
	$ButtonHover.play()

func _on_guide_button_pressed():
	$ButtonClick.play()
	var guide_button = $MainContainer/ContentContainer/InstructionPanel/GuideButton
	
	if guide_button and guide_button.text == "Stop":
		# Stop TTS
		if tts:
			tts.stop()
		# Immediately reset button text
		guide_button.text = "Guide"
		print("FlipQuizAnimals: Guide TTS stopped by user - button reset")
		return
	
	if tts:
		# Change button to Stop
		if guide_button:
			guide_button.text = "Stop"
		
		# Simpler, clearer instructions for dyslexic children
		var guide_text = "This is a memory game! Find two cards that match. One card has a picture of an animal. The other card has the animal's name. When you find a match, you'll hear the animal sound!"
		_speak_text_simple(guide_text)
		
		# Connect to TTS finished signal to reset button
		if tts.has_signal("utterance_finished"):
			if not tts.utterance_finished.is_connected(_on_guide_tts_finished):
				tts.utterance_finished.connect(_on_guide_tts_finished)
		elif tts.has_signal("finished"):
			if not tts.finished.is_connected(_on_guide_tts_finished):
				tts.finished.connect(_on_guide_tts_finished)

func _on_guide_tts_finished():
	"""Reset guide button when TTS finishes"""
	print("FlipQuizAnimals: _on_guide_tts_finished called - resetting button")
	var guide_button = $MainContainer/ContentContainer/InstructionPanel/GuideButton
	if guide_button:
		guide_button.text = "Guide"
		print("FlipQuizAnimals: Button text reset to 'Guide'")

func _on_tts_setting_button_pressed():
	"""TTS Settings button - Open settings as popup overlay"""
	$ButtonClick.play()
	print("FlipQuizAnimals: Settings button pressed")
	
	# Open settings as popup instead of changing scene
	var settings_popup_scene = load("res://Scenes/SettingScene.tscn")
	if settings_popup_scene:
		var popup = settings_popup_scene.instantiate()
		add_child(popup)
		if popup.has_method("set_context"):
			popup.set_context(false) # normal settings; hide battle buttons

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
	var hear_button = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/HearButton
	
	if hear_button and hear_button.text == "Stop":
		# Stop TTS and any playing sounds
		if tts:
			tts.stop()
		# Immediately reset button text
		hear_button.text = "Hear"
		print("FlipQuizAnimals: Hear TTS stopped by user - button reset")
		return
	
	if current_animal_index < selected_animals.size():
		var animal = selected_animals[current_animal_index]
		
		# Change button to Stop
		if hear_button:
			hear_button.text = "Stop"
		
		# Play animal sound first (primary hint)
		var sound_node = get_node_or_null(animal.sound_node)
		if sound_node:
			sound_node.play()
		
		# Wait a moment, then speak the animal name clearly (secondary hint)
		await get_tree().create_timer(2.0).timeout
		if tts and hear_button and hear_button.text == "Stop": # Check if still in Stop mode
			var hint_text = animal.name.capitalize() + ". Find the picture and the word!"
			_speak_text_simple(hint_text)
			
			# Connect to TTS finished signal to reset button
			if tts.has_signal("utterance_finished"):
				if not tts.utterance_finished.is_connected(_on_hear_tts_finished):
					tts.utterance_finished.connect(_on_hear_tts_finished)
			elif tts.has_signal("finished"):
				if not tts.finished.is_connected(_on_hear_tts_finished):
					tts.finished.connect(_on_hear_tts_finished)
		else:
			# Reset button if interrupted
			if hear_button:
				hear_button.text = "Hear"

func _on_hear_tts_finished():
	"""Reset hear button when TTS finishes"""
	print("FlipQuizAnimals: _on_hear_tts_finished called - resetting button")
	var hear_button = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/HearButton
	if hear_button:
		hear_button.text = "Hear"
		print("FlipQuizAnimals: Button text reset to 'Hear'")
		
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
