extends Control

var tts: TextToSpeech = null
var completion_celebration: CanvasLayer = null

# Load completion celebration scene
var completion_celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")

# Categories metadata (only animals has SFX)
var categories = {
	"animals": {
		"name": "Animals",
		"firestore_key": "flip_quiz", # unified module key
		"description": "Match animals with their words using sounds",
		"scene_path": "res://Scenes/FlipQuizAnimals.tscn",
		"has_sfx": true
	}
}

# Dyslexia-friendly quiz sets (no emojis; visual assets handled in scene). Animals retains optional sound_base for SFX mapping.
var quiz_sets = {
	"Animals": [
		{"word": "cat", "sound_base": "cat"},
		{"word": "dog", "sound_base": "dog"},
		{"word": "monkey", "sound_base": "monkey"},
		{"word": "elephant", "sound_base": "elephant"},
		{"word": "duck", "sound_base": "duck"},
		{"word": "fox", "sound_base": "fox"},
		{"word": "raccoon", "sound_base": "racoon"},
		{"word": "frog", "sound_base": "frog"}
	]
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

func _init_module_progress():
	# Use same Firebase pattern as authentication.gd (which works)
	print("FlipQuizModule: Initializing Firebase access")
	
	# Wait for Firebase to be ready (like authentication.gd does)
	await get_tree().process_frame
	
	# Check Firebase availability using authentication.gd pattern (no Engine.has_singleton check)
	if not Firebase or not Firebase.Auth:
		print("FlipQuizModule: Firebase or Firebase.Auth not available")
		return
	
	# Check authentication status (exact authentication.gd pattern)
	if Firebase.Auth.auth == null:
		print("FlipQuizModule: No authenticated user")
		return
	
	if not Firebase.Auth.auth.localid:
		print("FlipQuizModule: No localid available")
		return
	
	print("FlipQuizModule: Firebase authenticated successfully for user: ", Firebase.Auth.auth.localid)
	
	# Test Firestore access (exact authentication.gd pattern)
	if Firebase.Firestore == null:
		print("FlipQuizModule: ERROR - Firestore is null")
		return
	
	print("FlipQuizModule: Firestore available - ready for progress updates")

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
	# Food category removed

func _style_category_cards():
	var icon_containers = [
		$MainContainer/ScrollContainer/CategoriesGrid/AnimalsCard/AnimalsContent/IconContainer,
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
	if not Firebase.Auth.auth:
		print("FlipQuizModule: Firebase not available or not authenticated")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Use working authentication.gd pattern: direct document fetch
	print("FlipQuizModule: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("FlipQuizModule: Document fetched successfully")
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY:
			_update_progress_displays(modules)
		else:
			print("FlipQuizModule: No modules data found")
	else:
		print("FlipQuizModule: Failed to fetch document or document has error")

func _update_progress_displays(firebase_modules: Dictionary):
	# Show progress for Animals set (like Phonics)
	var total_sets := 3 # Update this if you add more sets
	var sets_completed := 0
	if firebase_modules.has("flip_quiz"):
		var fq = firebase_modules["flip_quiz"]
		if typeof(fq) == TYPE_DICTIONARY:
			var completed_array = fq.get("sets_completed", [])
			sets_completed = completed_array.size()
	var percent := (float(sets_completed) / float(total_sets)) * 100.0
	# Update Animals card progress
	var animals_card_path = "MainContainer/ScrollContainer/CategoriesGrid/AnimalsCard/AnimalsContent"
	var progress_label = get_node_or_null(animals_card_path + "/ProgressLabel")
	var progress_bar = get_node_or_null(animals_card_path + "/ProgressBar")
	if progress_label:
		progress_label.text = "Flip Quiz Progress: " + str(sets_completed) + "/" + str(total_sets) + " sets (" + str(int(percent)) + "%)"
	if progress_bar:
		progress_bar.value = percent
	# Update overall progress bar/label
	var overall_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	var overall_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	if overall_label:
		overall_label.text = "Flip Quiz Progress: " + str(sets_completed) + "/" + str(total_sets) + " sets (" + str(int(percent)) + "%)"
	if overall_bar:
		overall_bar.value = percent

func _on_button_hover():
	$ButtonHover.play()

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Match animal cards: pictures and words with helpful sounds. Finish all pairs to complete the set."
		_speak_text_simple(guide_text)

func _on_tts_setting_button_pressed():
	$ButtonClick.play()
	print("FlipQuizModule: Looking for TTSSettingsPopup (robust lookup)...")
	var tts_popup = get_node_or_null("TTSSettingsPopup")
	if not tts_popup:
		tts_popup = find_child("TTSSettingsPopup", true, false)
	if not tts_popup:
		print("FlipQuizModule: TTSSettingsPopup not found - instantiating dynamically")
		var popup_scene: PackedScene = load("res://Scenes/TTSSettingsPopup.tscn")
		if popup_scene:
			tts_popup = popup_scene.instantiate()
			tts_popup.name = "TTSSettingsPopup"
			add_child(tts_popup)
	print("FlipQuizModule: TTSSettingsPopup final status:", tts_popup != null)
	if tts_popup:
		var current_voice = SettingsManager.get_setting("accessibility", "tts_voice_id")
		var current_rate = SettingsManager.get_setting("accessibility", "tts_rate")
		if current_voice == null or current_voice == "":
			current_voice = "default"
		if current_rate == null:
			current_rate = 1.0
		if tts_popup.has_method("set_tts_instance"):
			tts_popup.set_tts_instance(tts)
		if tts_popup.has_method("setup"):
			tts_popup.setup(tts, current_voice, current_rate, "Testing Text to Speech")
		if not tts_popup.settings_saved.is_connected(_on_tts_settings_saved):
			tts_popup.settings_saved.connect(_on_tts_settings_saved)
		tts_popup.visible = true
	else:
		print("FlipQuizModule: Warning - TTSSettingsPopup still not found after dynamic attempt")

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

 # Food category removed per requirements

func _launch_category(category_key: String):
	var scene_path = categories[category_key]["scene_path"]
	_fade_out_and_change_scene(scene_path)