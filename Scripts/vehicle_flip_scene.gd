extends Control

var tts: TextToSpeech = null

# Vehicle data with images and sounds
var vehicles = [
	{"name": "car", "image": preload("res://gui/vehiclesquiz/car.png"), "sound_node": "car_sfx"},
	{"name": "bus", "image": preload("res://gui/vehiclesquiz/bus.png"), "sound_node": "bus_sfx"},
	{"name": "train", "image": preload("res://gui/vehiclesquiz/train.png"), "sound_node": "train_sfx"},
	{"name": "airplane", "image": preload("res://gui/vehiclesquiz/airplane.png"), "sound_node": "plane_sfx"},
	{"name": "truck", "image": preload("res://gui/vehiclesquiz/truck.png"), "sound_node": "truck_sfx"},
	{"name": "boat", "image": preload("res://gui/vehiclesquiz/boat.png"), "sound_node": "boat_sfx"},
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
	print("VehicleFlip: Vehicle flip quiz loaded")
	_init_tts()
	_init_module_progress()
	_connect_hover_events()
	_initialize_game()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_refresh_progress()

func _refresh_progress():
	await _load_progress()

func _init_tts():
	if Engine.has_singleton("GodotTTS"):
		tts = TextToSpeech.new()
		add_child(tts)

func _init_module_progress():
	if Engine.has_singleton("Firebase"):
		await _load_progress_from_firebase()

func _connect_hover_events():
	var buttons = find_children("*", "Button")
	for button in buttons:
		if not button.is_connected("mouse_entered", _on_button_hover):
			button.mouse_entered.connect(_on_button_hover)

func _initialize_game():
	# Reset game state
	matched_pairs = 0
	flipped_cards.clear()
	# Initialize first set of cards
	_create_flip_cards()
	_update_instruction()
	_update_navigation_buttons()

func _update_instruction():
	var instruction_label = $MainContainer/Content/VBoxContainer/InstructionLabel
	if instruction_label:
		instruction_label.text = "Match the vehicle images with their names"

func _update_navigation_buttons():
	var prev_button = $MainContainer/Content/VBoxContainer/NavigationContainer/PreviousButton
	var next_button = $MainContainer/Content/VBoxContainer/NavigationContainer/NextButton
	
	if prev_button:
		prev_button.disabled = current_set_index == 0
	if next_button:
		next_button.disabled = current_set_index >= total_sets - 1

func _create_flip_cards():
	# Clear existing cards
	for card in game_cards:
		card.queue_free()
	game_cards.clear()
	selected_vehicles.clear()

	# Select vehicles for this set
	var vehicles_per_set = 4
	var start_idx = current_set_index * vehicles_per_set
	for i in range(vehicles_per_set):
		var idx = (start_idx + i) % vehicles.size()
		selected_vehicles.append(vehicles[idx])

	# Create pairs of cards (image and text)
	for vehicle in selected_vehicles:
		# Create image card
		var image_card = Button.new()
		image_card.custom_minimum_size = Vector2(150, 150)
		image_card.icon = vehicle["image"]
		image_card.pressed.connect(_on_card_pressed.bind(image_card))
		
		# Create text card
		var text_card = Button.new()
		text_card.custom_minimum_size = Vector2(150, 150)
		text_card.text = vehicle["name"]
		text_card.pressed.connect(_on_card_pressed.bind(text_card))
		
		game_cards.append(image_card)
		game_cards.append(text_card)

	# Shuffle cards
	game_cards.shuffle()
	
	# Add cards to grid
	var grid = $MainContainer/Content/VBoxContainer/CardGrid
	for card in game_cards:
		grid.add_child(card)

func _on_card_pressed(card: Button):
	if is_checking_match or flipped_cards.has(card):
		return

	flipped_cards.append(card)
	card.disabled = true

	if flipped_cards.size() == 2:
		is_checking_match = true
		await _check_match()

func _check_match():
	await get_tree().create_timer(1.0).timeout
	
	var card1 = flipped_cards[0]
	var card2 = flipped_cards[1]
	
	var match_found = false
	for vehicle in selected_vehicles:
		if (card1.icon == vehicle["image"] and card2.text == vehicle["name"]) or \
		   (card2.icon == vehicle["image"] and card1.text == vehicle["name"]):
			match_found = true
			matched_pairs += 1
			_show_match_feedback(vehicle["name"])
			break
	
	if not match_found:
		card1.disabled = false
		card2.disabled = false
	
	flipped_cards.clear()
	is_checking_match = false
	
	if matched_pairs == selected_vehicles.size():
		_complete_game()

func _show_match_feedback(vehicle_name: String):
	_speak_text_simple("Correct! " + vehicle_name)

func _complete_game():
	var set_id = "vehicle_set_" + str(current_set_index + 1)
	if not sets_completed.has(set_id):
		sets_completed.append(set_id)
		_save_flip_quiz_completion_to_firebase(set_id)
	
	_show_completion_celebration()

func _show_completion_celebration():
	var celebration = completion_celebration_scene.instantiate()
	add_child(celebration)
	celebration.connect("try_again_pressed", _on_celebration_try_again)
	celebration.connect("next_set_pressed", _on_celebration_next_set)

func _on_celebration_try_again():
	_initialize_game()

func _on_celebration_next_set():
	if current_set_index < total_sets - 1:
		current_set_index += 1
		_initialize_game()

func _load_progress_from_firebase():
	if not Firebase.Auth.auth:
		return

	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("VehicleFlip: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if modules and modules.has("flip_quiz"):
			_update_local_progress_from_firebase(modules["flip_quiz"].get("sets_completed", []))

func _update_local_progress_from_firebase(completed_sets: Array):
	print("VehicleFlip: Processing completed sets from Firebase: ", completed_sets)
	sets_completed = completed_sets.filter(func(id): return id.begins_with("vehicle_"))

func _save_flip_quiz_completion_to_firebase(set_id: String) -> bool:
	if not Firebase.Auth.auth:
		return false

	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if not modules.has("flip_quiz"):
			modules["flip_quiz"] = {"completed": false, "progress": 0, "sets_completed": []}
		
		var flip_quiz = modules["flip_quiz"]
		if not set_id in flip_quiz["sets_completed"]:
			flip_quiz["sets_completed"].append(set_id)
			flip_quiz["progress"] = (flip_quiz["sets_completed"].size() / 10.0) * 100
			flip_quiz["completed"] = flip_quiz["progress"] >= 100
		
		document.add_or_update_field("modules", modules)
		var updated = await collection.update(document)
		return !("error" in updated.keys())
	return false

func _on_back_button_pressed():
	_stop_tts()
	_fade_out_and_change_scene("res://Scenes/FlipQuizModule.tscn")

func _on_guide_button_pressed():
	pass # Implement guide popup

func _on_tts_setting_button_pressed():
	var tts_settings = load("res://Scenes/TTSSettingsPopup.tscn").instantiate()
	add_child(tts_settings)
	tts_settings.connect("settings_saved", _on_tts_settings_saved)

func _on_tts_settings_saved(voice_id: String, rate: float):
	if tts:
		tts.set_voice(voice_id)
		tts.set_rate(rate)

func _on_button_hover():
	$ButtonHover.play()

func _stop_tts():
	if tts:
		tts.stop()

func _exit_tree():
	_stop_tts()

func _fade_out_and_change_scene(scene_path: String):
	# Add fade transition if needed
	get_tree().change_scene_to_file(scene_path)
