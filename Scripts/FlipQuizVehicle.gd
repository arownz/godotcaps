extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null

# Vehicle data with images and sounds for dyslexic learning
var vehicles = [
	{"name": "car", "image": preload("res://gui/vehiclesquiz/car.png"), "sound_node": "car_sfx"},
	{"name": "truck", "image": preload("res://gui/vehiclesquiz/truck.png"), "sound_node": "truck_sfx"},
	{"name": "train", "image": preload("res://gui/vehiclesquiz/train.png"), "sound_node": "train_sfx"},
	{"name": "airplane", "image": preload("res://gui/vehiclesquiz/airplane.png"), "sound_node": "airplane_sfx"},
	{"name": "boat", "image": preload("res://gui/vehiclesquiz/boat.png"), "sound_node": "boat_sfx"},
	{"name": "bus", "image": preload("res://gui/vehiclesquiz/bus.png"), "sound_node": "bus_sfx"}
]

# Game state
var current_vehicle_index = 0
var selected_vehicles = []
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
	print("FlipQuizVehicle: Vehicle flip quiz loaded")
	
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
	
	# Load progress and initialize game
	await _load_progress_from_firebase()
	_initialize_game()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
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
		print("FlipQuizVehicle: ModuleProgress initialized")
	else:
		print("FlipQuizVehicle: Firebase not available")

func _load_progress_from_firebase():
	"""Load flip quiz progress from Firebase using ModuleProgress"""
	if not module_progress or not module_progress.is_authenticated():
		print("FlipQuizVehicle: Module progress not available or not authenticated")
		return
	
	var flip_quiz_data = await module_progress.get_flip_quiz_progress()
	if flip_quiz_data and flip_quiz_data.has("vehicles"):
		var vehicles_data = flip_quiz_data["vehicles"]
		sets_completed = vehicles_data.get("sets_completed", [])
		print("FlipQuizVehicle: Loaded completed vehicle sets: ", sets_completed)
		
		# Set current_set_index to next uncompleted set OR find first uncompleted set
		var resume_set_index = sets_completed.size()
		
		# Load saved current position
		var saved_index = vehicles_data.get("current_index", 0)
		var saved_set_from_index = saved_index / 4 # Each set has 4 vehicles
		
		# Check if saved position is in a completed set
		var saved_set_id = "vehicles_set_" + str(saved_set_from_index + 1)
		if saved_set_id in sets_completed:
			print("FlipQuizVehicle: Saved position is in completed set, advancing to next uncompleted")
			# Use next uncompleted set
			current_set_index = resume_set_index
		else:
			# Resume at saved set position if it's not completed
			current_set_index = saved_set_from_index
		
		# Ensure set index is within bounds
		if current_set_index >= total_sets:
			current_set_index = total_sets - 1
		
		# Set vehicle index to start of current set
		current_vehicle_index = saved_index if current_set_index == saved_set_from_index else 0
		
		print("FlipQuizVehicle: Resuming at set ", current_set_index, ", vehicle index: ", current_vehicle_index, " (saved was set ", saved_set_from_index, ", index ", saved_index, ")")
		
		# Update progress display
		_update_progress_display(flip_quiz_data)
	else:
		print("FlipQuizVehicle: No vehicle data found")

func _update_progress_display(flip_quiz_data: Dictionary):
	"""Update vehicle-specific progress display"""
	var vehicles_data = flip_quiz_data.get("vehicles", {})
	var completed_array = vehicles_data.get("sets_completed", [])
	var percent := (float(completed_array.size()) / float(total_sets)) * 100.0
	
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	if progress_bar:
		progress_bar.value = percent
	
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	if progress_label:
		progress_label.text = str(completed_array.size()) + "/" + str(total_sets) + " sets complete"

func _connect_hover_events():
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
	"""Initialize the flip quiz game for vehicles"""
	# Select 4 vehicles for the current set
	vehicles.shuffle()
	var offset = (current_set_index * 4) % vehicles.size()
	selected_vehicles = []
	for i in range(4):
		selected_vehicles.append(vehicles[(offset + i) % vehicles.size()])
	
	current_vehicle_index = 0
	matched_pairs = 0
	attempts = 0
	
	_update_instruction()
	_update_navigation_buttons()
	_create_flip_cards()
	_update_score_display()

func _update_instruction():
	"""Update instruction text showing remaining targets with current focus"""
	var instruction_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
	if not instruction_label:
		return
	
	# Get list of remaining (unmatched) vehicles
	var remaining_vehicles = []
	var matched_vehicle_names = []
	
	# Collect names of matched vehicles
	for card in game_cards:
		if card.get_meta("is_matched", false):
			var card_data = card.get_meta("card_data")
			if card_data and not matched_vehicle_names.has(card_data.vehicle.name):
				matched_vehicle_names.append(card_data.vehicle.name)
	
	# Build remaining vehicles list
	for vehicle in selected_vehicles:
		if not matched_vehicle_names.has(vehicle.name):
			remaining_vehicles.append(vehicle)
	
	if remaining_vehicles.size() > 0:
		# Show remaining targets with current focus highlighted in green for dyslexic children
		var target_text = "Find: "
		for i in range(remaining_vehicles.size()):
			var vehicle = remaining_vehicles[i]
			if i == current_vehicle_index and current_vehicle_index < remaining_vehicles.size():
				# Highlight current target in green for visual clarity
				target_text += "[color=#00AA00]" + vehicle.name.capitalize() + "[/color]"
			else:
				target_text += vehicle.name.capitalize()
			
			if i < remaining_vehicles.size() - 1:
				target_text += ", "
		
		# Set BBCode text for color highlighting (RichTextLabel)
		instruction_label.bbcode_text = target_text
		
		instruction_label.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
		instruction_label.add_theme_font_size_override("font_size", 36) # Slightly smaller for longer text
		instruction_label.add_theme_color_override("font_color", Color.BLACK) # Default black color
		instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		# All targets completed - show replay message
		instruction_label.text = "Great job! All vehicles found!"
		instruction_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 1))

func _update_navigation_buttons():
	"""Update visibility of previous/next buttons"""
	var prev_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton
	var next_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	
	# Hide Previous button when at first target (index 0)
	prev_btn.visible = (current_vehicle_index > 0)
	
	# Hide Next button when at last target (no loop - last is end)
	next_btn.visible = (current_vehicle_index < selected_vehicles.size() - 1)

func _create_flip_cards():
	"""Create flip cards for the memory game"""
	var cards_container = $MainContainer/ContentContainer/GamePanel/GameContainer/CardsContainer
	
	# Clear existing cards
	for child in cards_container.get_children():
		child.queue_free()
	
	game_cards.clear()
	flipped_cards.clear()
	
	# Create cards: 4 image cards + 4 text cards = 8 total
	var all_cards = []
	
	# Add image cards
	for vehicle in selected_vehicles:
		all_cards.append({"type": "image", "vehicle": vehicle, "id": vehicle.name})
	
	# Add text cards
	for vehicle in selected_vehicles:
		all_cards.append({"type": "text", "vehicle": vehicle, "id": vehicle.name})
	
	all_cards.shuffle()
	
	# Create card buttons with dyslexia-friendly design
	for i in range(all_cards.size()):
		var card_data = all_cards[i]
		var card_button = Button.new()
		card_button.custom_minimum_size = Vector2(160, 140)
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
		
		# Remove focus border
		var empty_style = StyleBoxEmpty.new()
		card_button.add_theme_stylebox_override("focus", empty_style)
		
		# Set card face-down initially
		card_button.text = "?"
		card_button.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
		card_button.add_theme_font_size_override("font_size", 48)
		card_button.add_theme_color_override("font_color", Color.BLACK)
		card_button.add_theme_color_override("font_hover_color", Color.BLACK)
		card_button.add_theme_color_override("font_pressed_color", Color.BLACK)
		card_button.add_theme_color_override("font_focus_color", Color.BLACK)
		
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
	
	if card.get_meta("is_flipped") or card.get_meta("is_matched") or is_checking_match:
		return
	
	if flipped_cards.size() >= 2:
		return
	
	# Flip the card
	var card_data = card.get_meta("card_data")
	card.set_meta("is_flipped", true)
	
	# Show card content
	if card_data.type == "image":
		card.icon = card_data.vehicle.image
		card.text = ""
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else: # text card
		card.text = card_data.vehicle.name.capitalize()
		card.icon = null
		card.add_theme_font_size_override("font_size", 18)
		card.add_theme_color_override("font_color", Color.BLACK)
		card.add_theme_color_override("font_hover_color", Color.BLACK)
		card.add_theme_color_override("font_pressed_color", Color.BLACK)
		card.add_theme_color_override("font_focus_color", Color.BLACK)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Add padding to prevent text overlap
		card.add_theme_constant_override("text_margin_left", 8)
		card.add_theme_constant_override("text_margin_right", 8)
		card.add_theme_constant_override("text_margin_top", 8)
		card.add_theme_constant_override("text_margin_bottom", 8)
	
	# Play vehicle sound when card is flipped for dyslexic children learning pattern
	var sound_node = get_node_or_null(card_data.vehicle.sound_node)
	if sound_node:
		sound_node.play()
		print("FlipQuizVehicle: Playing sound on flip for ", card_data.vehicle.name)
	else:
		print("FlipQuizVehicle: Sound node not found: ", card_data.vehicle.sound_node)
	
	flipped_cards.append(card)
	
	# Check for matches when 2 cards are flipped
	if flipped_cards.size() == 2:
		is_checking_match = true
		await get_tree().create_timer(1.0).timeout
		_check_match()

func _check_match():
	"""Check if flipped cards match"""
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
		
		# Visual feedback for match - GREEN like animals
		var match_style = StyleBoxFlat.new()
		match_style.bg_color = Color(0.2, 0.8, 0.2, 1) # Green background like animals
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
		print("FlipQuizVehicle: Match found! ", data1.vehicle.name)
		
		# Play vehicle sound
		var sound_node = get_node_or_null(data1.vehicle.sound_node)
		if sound_node:
			sound_node.play()
			print("FlipQuizVehicle: Playing sound for ", data1.vehicle.name)
		else:
			print("FlipQuizVehicle: Sound node not found for ", data1.vehicle.sound_node)
		
		# Update instruction to reflect completed target
		_update_instruction()
		_update_navigation_buttons()
		
		# Auto-advance to next unmatched target if current target was completed
		if current_vehicle_index < selected_vehicles.size():
			var current_vehicle_name = selected_vehicles[current_vehicle_index].name
			if current_vehicle_name == data1.vehicle.name:
				_advance_to_next_unmatched_target()
		
		# Check if all pairs are matched
		if matched_pairs >= selected_vehicles.size():
			await get_tree().create_timer(2.0).timeout
			_complete_game()
	else:
		# No match - reset cards
		await get_tree().create_timer(1.0).timeout
		
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
	print("FlipQuizVehicle: Game completed!")
	
	# Save progress using ModuleProgress
	if module_progress and module_progress.is_authenticated():
		var set_id = "vehicles_set_" + str(current_set_index + 1)
		var success = await module_progress.complete_flip_quiz_set("vehicles", set_id)
		if success:
			print("FlipQuizVehicle: Progress saved (" + set_id + ")")
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
	var set_title = "Vehicle Set " + str(current_set_index + 1)
	celebration.show_completion(celebration.CompletionType.FLIP_VEHICLE, set_title, progress_data, "flip_quiz")

	# Connect celebration signals
	if celebration.has_signal("try_again_pressed"):
		celebration.try_again_pressed.connect(_on_celebration_try_again)
	if celebration.has_signal("next_item_pressed"):
		celebration.next_item_pressed.connect(_on_celebration_next_set)

func _on_celebration_try_again():
	"""Restart the current game"""
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
		print("FlipQuizVehicle: All sets completed! Starting open-ended practice from Set 1")
		_initialize_game()

func _advance_to_next_unmatched_target():
	"""Advance to next unmatched target for focus"""
	var matched_vehicle_names = []
	
	# Collect matched vehicle names
	for card in game_cards:
		if card.get_meta("is_matched", false):
			var card_data = card.get_meta("card_data")
			if card_data and not matched_vehicle_names.has(card_data.vehicle.name):
				matched_vehicle_names.append(card_data.vehicle.name)
	
	# Find next unmatched vehicle
	var found_unmatched = false
	
	for i in range(selected_vehicles.size()):
		var check_index = (current_vehicle_index + i + 1) % selected_vehicles.size()
		if not matched_vehicle_names.has(selected_vehicles[check_index].name):
			current_vehicle_index = check_index
			found_unmatched = true
			break
	
	# If no unmatched found, cycle back to start of remaining
	if not found_unmatched:
		for i in range(selected_vehicles.size()):
			if not matched_vehicle_names.has(selected_vehicles[i].name):
				current_vehicle_index = i
				break

func _update_score_display():
	"""Update score display"""
	var score_label = get_node_or_null("MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/ScoreLabel")
	var attempts_label = get_node_or_null("MainContainer/ContentContainer/GamePanel/GameContainer/ScoreContainer/AttemptsLabel")

	if score_label:
		score_label.text = "Matches: " + str(matched_pairs) + "/" + str(selected_vehicles.size())
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
		print("FlipQuizVehicle: Guide TTS stopped by user - button reset")
		return
	
	if tts:
		# Change button to Stop
		if guide_button:
			guide_button.text = "Stop"
		
		var guide_text = "This is a vehicle memory game! Find two cards that match. One card has a picture of a vehicle. The other card has the vehicle's name. Match them all to complete the set!"
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
	print("FlipQuizVehicle: _on_guide_tts_finished called - resetting button")
	var guide_button = $MainContainer/ContentContainer/InstructionPanel/GuideButton
	if guide_button:
		guide_button.text = "Guide"
		print("FlipQuizVehicle: Button text reset to 'Guide'")

func _on_tts_setting_button_pressed():
	"""TTS Settings button - Open settings as popup overlay"""
	$ButtonClick.play()
	print("FlipQuizVehicle: Settings button pressed")
	
	# Open settings as popup instead of changing scene
	var settings_popup_scene = load("res://Scenes/SettingScene.tscn")
	if settings_popup_scene:
		var popup = settings_popup_scene.instantiate()
		add_child(popup)
		if popup.has_method("set_context"):
			popup.set_context(false) # normal settings; hide battle buttons

func _on_tts_settings_saved(voice_id: String, rate: float):
	"""Handle TTS settings save"""
	if tts:
		if voice_id != null and voice_id != "":
			tts.set_voice(voice_id)
		if rate != null:
			tts.set_rate(rate)
	
	if SettingsManager:
		SettingsManager.set_setting("accessibility", "tts_voice_id", voice_id)
		SettingsManager.set_setting("accessibility", "tts_rate", rate)

func _on_back_button_pressed():
	$ButtonClick.play()
	_fade_out_and_change_scene("res://Scenes/FlipQuizModule.tscn")

func _on_previous_button_pressed():
	$ButtonClick.play()
	if current_vehicle_index > 0:
		current_vehicle_index -= 1
		_update_instruction()
		_update_navigation_buttons()
		
		if current_vehicle_index < selected_vehicles.size():
			var vehicle = selected_vehicles[current_vehicle_index]
			if tts:
				_speak_text_simple("Now focusing on " + vehicle.name)

func _on_hear_button_pressed():
	$ButtonClick.play()
	var hear_button = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/HearButton
	
	if hear_button and hear_button.text == "Stop":
		# Stop TTS
		if tts:
			tts.stop()
		# Immediately reset button text
		hear_button.text = "Hear"
		print("FlipQuizVehicle: Hear TTS stopped by user - button reset")
		return
	
	if current_vehicle_index < selected_vehicles.size():
		var vehicle = selected_vehicles[current_vehicle_index]
		
		# Change button to Stop
		if hear_button:
			hear_button.text = "Stop"
		
		# TTS pronunciation and hint for vehicles
		if tts:
			var hint_text = vehicle.name.capitalize() + ". Find the picture and the word!"
			_speak_text_simple(hint_text)
			
			# Connect to TTS finished signal to reset button
			if tts.has_signal("utterance_finished"):
				if not tts.utterance_finished.is_connected(_on_hear_tts_finished):
					tts.utterance_finished.connect(_on_hear_tts_finished)
			elif tts.has_signal("finished"):
				if not tts.finished.is_connected(_on_hear_tts_finished):
					tts.finished.connect(_on_hear_tts_finished)

func _on_hear_tts_finished():
	"""Reset hear button when TTS finishes"""
	print("FlipQuizVehicle: _on_hear_tts_finished called - resetting button")
	var hear_button = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/HearButton
	if hear_button:
		hear_button.text = "Hear"
		print("FlipQuizVehicle: Button text reset to 'Hear'")
		
		# Visual hint: highlight the target vehicle name
		var instruction_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
		if instruction_label:
			var original_color = instruction_label.get_theme_color("font_color")
			instruction_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0, 1))
			await get_tree().create_timer(2.0).timeout
			instruction_label.add_theme_color_override("font_color", original_color)

func _on_next_button_pressed():
	$ButtonClick.play()
	if current_vehicle_index < selected_vehicles.size() - 1:
		current_vehicle_index += 1
	else:
		current_vehicle_index = 0
	
	_update_instruction()
	_update_navigation_buttons()
	
	if current_vehicle_index < selected_vehicles.size():
		var vehicle = selected_vehicles[current_vehicle_index]
		if tts:
			_speak_text_simple("Now focusing on " + vehicle.name)

func _fade_out_and_change_scene(scene_path: String):
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

func _exit_tree():
	_stop_tts()
