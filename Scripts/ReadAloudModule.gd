extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null

# Categories for Read Aloud - Guided Reading and Syllable Workshop
var categories = {
	"guided_reading": {
		"title": "Guided Reading",
		"scene_path": "res://Scenes/ReadAloudGuided.tscn"
	},
	"syllable_workshop": {
		"title": "Syllable Workshop",
		"scene_path": "res://Scenes/SyllableBuildingModule.tscn"
	}
}

func _speak_text_simple(text: String):
	"""Simple TTS without captions"""
	if tts:
		tts.speak(text)

func _ready():
	print("ReadAloudModule: Initializing read aloud categories interface")

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
	
	# Style cards with rounded corners and IconContainer backgrounds
	_style_category_cards()
	
	# Load progress from Firestore
	await _load_category_progress()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window regains focus (user returns from practice)
		call_deferred("_refresh_progress")

func _refresh_progress():
	"""Refresh progress display when user returns to read aloud module"""
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
		print("ReadAloudModule: ModuleProgress initialized")
	else:
		print("ReadAloudModule: Firebase not available, using local tracking")

func _connect_hover_events():
	# Connect back button hover
	var back_btn = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton
	if back_btn and not back_btn.mouse_entered.is_connected(_on_button_hover):
		back_btn.mouse_entered.connect(_on_button_hover)
	
	# Connect guide button
	var guide_btn = $MainContainer/HeaderPanel/GuideButton
	if guide_btn:
		if not guide_btn.mouse_entered.is_connected(_on_button_hover):
			guide_btn.mouse_entered.connect(_on_button_hover)
		if not guide_btn.pressed.is_connected(_on_guide_button_pressed):
			guide_btn.pressed.connect(_on_guide_button_pressed)
	
	# Connect TTS settings button
	var tts_btn = $MainContainer/HeaderPanel/TTSSettingButton
	if tts_btn:
		if not tts_btn.mouse_entered.is_connected(_on_button_hover):
			tts_btn.mouse_entered.connect(_on_button_hover)
		if not tts_btn.pressed.is_connected(_on_tts_setting_button_pressed):
			tts_btn.pressed.connect(_on_tts_setting_button_pressed)
	
	# Connect category enter buttons
	var guided_enter_btn = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/GuidedReadingCard/GuidedContent/EnterButton")
	if guided_enter_btn:
		if not guided_enter_btn.mouse_entered.is_connected(_on_button_hover):
			guided_enter_btn.mouse_entered.connect(_on_button_hover)
		if not guided_enter_btn.pressed.is_connected(_on_guided_reading_button_pressed):
			guided_enter_btn.pressed.connect(_on_guided_reading_button_pressed)
	
	# Connect syllable workshop button
	var syllable_enter_btn = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/GuidedReadingCard2/GuidedContent/EnterButton")
	if syllable_enter_btn:
		if not syllable_enter_btn.mouse_entered.is_connected(_on_button_hover):
			syllable_enter_btn.mouse_entered.connect(_on_button_hover)
		if not syllable_enter_btn.pressed.is_connected(_on_syllable_workshop_button_pressed):
			syllable_enter_btn.pressed.connect(_on_syllable_workshop_button_pressed)

func _style_category_cards():
	var icon_containers = [
		get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/GuidedReadingCard/GuidedContent/IconContainer"),
		get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/GuidedReadingCard2/GuidedContent/IconContainer")
	]
	
	for icon_container in icon_containers:
		if icon_container:
			var icon_style = StyleBoxFlat.new()
			icon_style.corner_radius_top_left = 10
			icon_style.corner_radius_top_right = 10
			icon_style.corner_radius_bottom_left = 10
			icon_style.corner_radius_bottom_right = 10
			icon_style.bg_color = Color(1, 1, 1, 1) # white color
			icon_style.border_width_left = 2
			icon_style.border_width_right = 2
			icon_style.border_width_top = 2
			icon_style.border_width_bottom = 2
			icon_style.border_color = Color(0, 0, 0, 1) # Black border outline
			icon_container.add_theme_stylebox_override("panel", icon_style)

func _load_category_progress():
	if not module_progress or not module_progress.is_authenticated():
		print("ReadAloudModule: ModuleProgress not available or not authenticated")
		return
		
	print("ReadAloudModule: Loading read aloud progress via ModuleProgress")
	var read_aloud_progress = await module_progress.get_read_aloud_progress()
	if read_aloud_progress:
		_update_progress_displays({"read_aloud": read_aloud_progress})
	else:
		print("ReadAloudModule: Failed to fetch read aloud progress")

func _update_progress_displays(firebase_modules: Dictionary):
	# Overall progress calculation (matches ModuleScene.gd approach)
	var guided_activities = 0
	var syllable_activities = 0
	
	# Guided Reading progress - Enhanced calculation based on actual completion
	var guided_percent = 0.0
	if firebase_modules.has("read_aloud"):
		var read_aloud = firebase_modules["read_aloud"]
		if typeof(read_aloud) == TYPE_DICTIONARY:
			guided_activities = read_aloud.get("guided_reading", {}).get("activities_completed", []).size()
			var total_guided_activities = 4 # Updated to match 4 passages in ReadAloudGuided.gd
			guided_percent = (float(guided_activities) / float(total_guided_activities)) * 100.0
			print("ReadAloudModule: Guided Reading - ", guided_activities, "/", total_guided_activities, " activities completed (", int(guided_percent), "%)")
	
	var guided_label = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/GuidedReadingCard/GuidedContent/ProgressLabel")
	if guided_label:
		guided_label.text = str(int(guided_percent)) + "% Complete"
		print("ReadAloudModule: Updated guided reading progress label to ", int(guided_percent), "%")

	# Syllable Workshop progress - Based on syllable building activities
	var syllable_percent = 0.0
	if firebase_modules.has("read_aloud"):
		var read_aloud = firebase_modules["read_aloud"]
		if typeof(read_aloud) == TYPE_DICTIONARY:
			syllable_activities = read_aloud.get("syllable_workshop", {}).get("activities_completed", []).size()
			var total_syllable_activities = 9 # 9 syllable words in SyllableBuildingModule (matches actual array size)
			syllable_percent = (float(syllable_activities) / float(total_syllable_activities)) * 100.0
			print("ReadAloudModule: Syllable Workshop - ", syllable_activities, "/", total_syllable_activities, " activities completed (", int(syllable_percent), "%)")
	
	var syllable_label = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/GuidedReadingCard2/GuidedContent/ProgressLabel")
	if syllable_label:
		syllable_label.text = str(int(syllable_percent)) + "% Complete"
		print("ReadAloudModule: Updated syllable workshop progress label to ", int(syllable_percent), "%")

	# Overall progress based on total completed activities (matches ModuleScene.gd calculation)
	var total_completed = guided_activities + syllable_activities
	var total_possible = 13 # 4 guided + 9 syllable (matches ModuleScene.gd)
	var overall_percent = (float(total_completed) / float(total_possible)) * 100.0
	var overall_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	if overall_bar:
		overall_bar.value = overall_percent
		print("ReadAloudModule: Updated overall progress bar to ", int(overall_percent), "%")
	
	var overall_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	if overall_label:
		overall_label.text = str(int(overall_percent)) + "% Complete"
		print("ReadAloudModule: Updated overall progress label to ", int(overall_percent), "%")
	
	print("ReadAloudModule: All progress displays updated - Guided: ", int(guided_percent), "%, Syllable: ", int(syllable_percent), "%, Overall: ", int(overall_percent), "% (", total_completed, "/", total_possible, " total activities)")

func _on_button_hover():
	$ButtonHover.play()

func _on_guide_button_pressed():
	$ButtonClick.play()
	var guide_button = $MainContainer/HeaderPanel/GuideButton
	
	if guide_button and guide_button.text == "Stop":
		# Stop TTS
		if tts:
			tts.stop()
		guide_button.text = "Guide"
		print("ReadAloudModule: Guide TTS stopped by user")
		return
	
	if tts:
		# Change button to Stop
		if guide_button:
			guide_button.text = "Stop"
		
		var guide_text = "Welcome to Read Aloud! Here you can listen to words and practice your reading skills."

		# Simplified: just TTS without captions
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
	var guide_button = $MainContainer/HeaderPanel/GuideButton
	if guide_button:
		guide_button.text = "Guide"

func _on_tts_setting_button_pressed():
	"""TTS Settings button - Open settings as popup overlay"""
	$ButtonClick.play()
	print("ReadAloudModule: Settings button pressed")
	
	# Open settings as popup instead of changing scene
	var settings_popup_scene = load("res://Scenes/SettingScene.tscn")
	if settings_popup_scene:
		var popup = settings_popup_scene.instantiate()
		add_child(popup)
		if popup.has_method("set_context"):
			popup.set_context(false) # normal settings; hide battle buttons

func _on_tts_settings_saved(voice_id: String, rate: float):
	"""Handle TTS settings save to update local TTS instance"""
	print("ReadAloudModule: Saving TTS preferences - Voice: ", voice_id, " Rate: ", rate)

	# Update current TTS instance
	if tts:
		if voice_id != null and voice_id != "":
			tts.set_voice(voice_id)
		if rate != null:
			tts.set_rate(rate)
	
	# Store in SettingsManager for persistence
	SettingsManager.set_setting("accessibility", "tts_voice_id", voice_id)
	SettingsManager.set_setting("accessibility", "tts_rate", rate)

func _on_back_button_pressed():
	$ButtonClick.play()
	print("ReadAloudModule: Returning to module selection")
	_fade_out_and_change_scene("res://Scenes/ModuleScene.tscn")

func _fade_out_and_change_scene(scene_path: String):
	# Stop any playing TTS before changing scenes
	_stop_tts()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

# Clean up TTS when leaving scene
func _stop_tts():
	if tts and tts.has_method("stop"):
		tts.stop()
		print("ReadAloudModule: TTS stopped before scene change")

# Ensure TTS cleanup on scene exit
func _exit_tree():
	_stop_tts()
	
func _on_guided_reading_button_pressed():
	$ButtonClick.play()
	print("ReadAloudModule: Starting Guided Reading")
	_launch_category("guided_reading")

func _on_syllable_workshop_button_pressed():
	$ButtonClick.play()
	print("ReadAloudModule: Starting Syllable Workshop")
	_launch_category("syllable_workshop")

func _launch_category(category_key: String):
	# Navigate to category scene
	var scene_path = categories[category_key]["scene_path"]
	_fade_out_and_change_scene(scene_path)
