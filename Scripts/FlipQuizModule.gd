extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null
var completion_celebration: CanvasLayer = null

# Load completion celebration scene
var completion_celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")

# Categories metadata (only animals has SFX)
var categories = {
	"animals": {
		"scene_path": "res://Scenes/FlipQuizAnimals.tscn",
	},
	"vehicles": {
		"scene_path": "res://Scenes/FlipQuizVehicle.tscn"
	}
}

var current_set = ""
var current_pairs = []
var flipped_cards = []
var matched_pairs = 0
var attempts = 0
var max_attempts = 15 # Generous attempt allowance; no time pressure

func _speak_text_simple(text: String):
	if tts:
		tts.speak(text)

func _ready():
	print("FlipQuizModule: Flip Quiz module loaded")
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_init_tts()
	_init_module_progress()
	_connect_hover_events()
	_style_category_cards()
	await _load_category_progress()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		call_deferred("_refresh_progress")

func _refresh_progress():
	await _load_category_progress()

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
		print("FlipQuizModule: ModuleProgress initialized")
	else:
		print("FlipQuizModule: Firebase not available, using local tracking")

func _connect_hover_events():
	var back_btn = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton
	if back_btn and not back_btn.mouse_entered.is_connected(_on_button_hover):
		back_btn.mouse_entered.connect(_on_button_hover)

	var guide_btn = $MainContainer/HeaderPanel/GuideButton
	if guide_btn:
		if not guide_btn.mouse_entered.is_connected(_on_button_hover):
			guide_btn.mouse_entered.connect(_on_button_hover)
		if not guide_btn.pressed.is_connected(_on_guide_button_pressed):
			guide_btn.pressed.connect(_on_guide_button_pressed)

	var tts_btn = $MainContainer/HeaderPanel/TTSSettingButton
	if tts_btn:
		if not tts_btn.mouse_entered.is_connected(_on_button_hover):
			tts_btn.mouse_entered.connect(_on_button_hover)
		if not tts_btn.pressed.is_connected(_on_tts_setting_button_pressed):
			tts_btn.pressed.connect(_on_tts_setting_button_pressed)

	var animals_btn = $MainContainer/ScrollContainer/CategoriesGrid/AnimalsCard/AnimalsContent/EnterButton
	if animals_btn:
		if not animals_btn.mouse_entered.is_connected(_on_button_hover):
			animals_btn.mouse_entered.connect(_on_button_hover)
		if not animals_btn.pressed.is_connected(_on_animals_button_pressed):
			animals_btn.pressed.connect(_on_animals_button_pressed)

	var vehicles_btn = $MainContainer/ScrollContainer/CategoriesGrid/VehiclesCard/VehiclesContent/EnterButton
	if vehicles_btn:
		if not vehicles_btn.mouse_entered.is_connected(_on_button_hover):
			vehicles_btn.mouse_entered.connect(_on_button_hover)
		if not vehicles_btn.pressed.is_connected(_on_vehicles_button_pressed):
			vehicles_btn.pressed.connect(_on_vehicles_button_pressed)

func _style_category_cards():
	var icon_containers = [
		$MainContainer/ScrollContainer/CategoriesGrid/AnimalsCard/AnimalsContent/IconContainer,
		$MainContainer/ScrollContainer/CategoriesGrid/VehiclesCard/VehiclesContent/IconContainer
	]
	for icon_container in icon_containers:
		if icon_container:
			var icon_style = StyleBoxFlat.new()
			icon_style.corner_radius_top_left = 10
			icon_style.corner_radius_top_right = 10
			icon_style.corner_radius_bottom_left = 10
			icon_style.corner_radius_bottom_right = 10
			icon_style.bg_color = Color(1, 1, 1, 1)
			icon_style.border_width_left = 2
			icon_style.border_width_right = 2
			icon_style.border_width_top = 2
			icon_style.border_width_bottom = 2
			icon_style.border_color = Color(0, 0, 0, 1)
			icon_container.add_theme_stylebox_override("panel", icon_style)

func _load_category_progress():
	if not module_progress or not module_progress.is_authenticated():
		print("FlipQuizModule: ModuleProgress not available or not authenticated")
		return
		
	print("FlipQuizModule: Loading flip quiz progress via ModuleProgress")
	var flip_quiz_progress = await module_progress.get_flip_quiz_progress()
	if flip_quiz_progress:
		_update_progress_displays({"flip_quiz": flip_quiz_progress})
	else:
		print("FlipQuizModule: Failed to fetch flip quiz progress")

func _update_progress_displays(firebase_modules: Dictionary):
	print("FlipQuizModule: Updating progress displays with Firebase data")
	
	var total_sets_per_category := 3 # Always 3 sets per category for Flip Quiz
	
	# Handle Animals progress
	var animals_sets_completed := 0
	if firebase_modules.has("flip_quiz") and firebase_modules["flip_quiz"].has("animals"):
		var animals_data = firebase_modules["flip_quiz"]["animals"]
		if typeof(animals_data) == TYPE_DICTIONARY:
			var completed_array = animals_data.get("sets_completed", [])
			animals_sets_completed = completed_array.size()
			print("FlipQuizModule: Animals sets completed: ", animals_sets_completed)
	
	var animals_percent := (float(animals_sets_completed) / float(total_sets_per_category)) * 100.0
	
	# Update Animals card progress
	var animals_progress_label = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/AnimalsCard/AnimalsContent/ProgressLabel")
	if animals_progress_label:
		animals_progress_label.text = str(int(animals_percent)) + "% Complete"
		print("FlipQuizModule: Updated animals progress label: ", animals_progress_label.text)
	else:
		print("FlipQuizModule: Animals progress label not found")
	
	# Handle Vehicles progress
	var vehicles_sets_completed := 0
	if firebase_modules.has("flip_quiz") and firebase_modules["flip_quiz"].has("vehicles"):
		var vehicles_data = firebase_modules["flip_quiz"]["vehicles"]
		if typeof(vehicles_data) == TYPE_DICTIONARY:
			var completed_array = vehicles_data.get("sets_completed", [])
			vehicles_sets_completed = completed_array.size()
			print("FlipQuizModule: Vehicles sets completed: ", vehicles_sets_completed)
	
	var vehicles_percent := (float(vehicles_sets_completed) / float(total_sets_per_category)) * 100.0
	
	# Update Vehicles card progress
	var vehicles_progress_label = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/VehiclesCard/VehiclesContent/ProgressLabel")
	if vehicles_progress_label:
		vehicles_progress_label.text = str(int(vehicles_percent)) + "% Complete"
		print("FlipQuizModule: Updated vehicles progress label: ", vehicles_progress_label.text)
	else:
		print("FlipQuizModule: Vehicles progress label not found")
	
	# Calculate overall Flip Quiz progress (average of both categories)
	var total_completed := animals_sets_completed + vehicles_sets_completed
	var total_possible := total_sets_per_category * 2 # 2 categories
	var overall_percent := (float(total_completed) / float(total_possible)) * 100.0
	
	# Update overall progress bar/label in header
	var overall_bar = get_node_or_null("MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar")
	if overall_bar:
		overall_bar.value = overall_percent
		print("FlipQuizModule: Updated overall progress bar: ", overall_percent, "%")
	else:
		print("FlipQuizModule: Overall progress bar not found")
	
	var overall_label = get_node_or_null("MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel")
	if overall_label:
		overall_label.text = str(int(overall_percent)) + "%" + " Complete"
		print("FlipQuizModule: Updated overall progress label: ", overall_label.text)

func _on_button_hover():
	$ButtonHover.play()

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Match flippable quiz cards: pictures and words with helpful sounds. Finish all pairs to complete the set."
		_speak_text_simple(guide_text)

func _on_tts_setting_button_pressed():
	"""TTS Settings button - Open settings as popup overlay"""
	$ButtonClick.play()
	print("FlipQuizModule: Settings button pressed")
	
	# Open settings as popup instead of changing scene
	var settings_popup_scene = load("res://Scenes/SettingScene.tscn")
	if settings_popup_scene:
		var popup = settings_popup_scene.instantiate()
		add_child(popup)
		if popup.has_method("set_context"):
			popup.set_context(false) # normal settings; hide battle buttons

func _on_tts_settings_saved(voice_id: String, rate: float):
	print("FlipQuizModule: Saving TTS preferences - Voice: ", voice_id, " Rate: ", rate)
	if tts:
		if voice_id != null and voice_id != "":
			tts.set_voice(voice_id)
		if rate != null:
			tts.set_rate(rate)
	SettingsManager.set_setting("accessibility", "tts_voice_id", voice_id)
	SettingsManager.set_setting("accessibility", "tts_rate", rate)

func _on_back_button_pressed():
	$ButtonClick.play()
	print("FlipQuizModule: Returning to module selection")
	_fade_out_and_change_scene("res://Scenes/ModuleScene.tscn")

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
		print("FlipQuizModule: TTS stopped before scene change")

func _exit_tree():
	_stop_tts()

func _on_animals_button_pressed():
	$ButtonClick.play()
	print("FlipQuizModule: Starting Animals category")
	_launch_category("animals")

func _on_vehicles_button_pressed() -> void:
	$ButtonClick.play()
	print("FlipQuizModule: Starting Vehicles category")
	_launch_category("vehicles")

func _launch_category(category_key: String):
	var scene_path = categories[category_key]["scene_path"]
	_fade_out_and_change_scene(scene_path)
