extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null

# Categories: Only Letters and Sight Words
var categories = {
	"letters": {
		"name": "Letters",
		"firestore_key": "phonics_letters",
		"description": "Trace A-Z and hear sounds",
		"scene_path": "res://Scenes/PhonicsLetters.tscn"
	},
	"sight_words": {
		"name": "Sight Words",
		"firestore_key": "phonics_sight_words",
		"description": "Common words like 'the', 'and'",
		"scene_path": "res://Scenes/PhonicsSightWords.tscn"
	}
}

func _speak_text_simple(text: String):
	"""Simple TTS without captions"""
	if tts:
		tts.speak(text)

func _ready():
	print("PhonicsModule: Initializing phonics categories interface")
	
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
	"""Refresh progress display when user returns to phonics module"""
	if module_progress:
		await _load_category_progress()

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	# Don't auto-play welcome message - only when guide button is pressed

func _init_module_progress():
	if Engine.has_singleton("Firebase"):
		module_progress = ModuleProgress.new()
		add_child(module_progress)
	else:
		print("PhonicsModule: Firebase not available; progress won't sync")

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

func _style_category_cards():
	# Style icon containers with #FEB79A background and black borders
	var icon_containers = [
		$MainContainer/ScrollContainer/CategoriesGrid/LettersCard/LettersContent/IconContainer,
		$MainContainer/ScrollContainer/CategoriesGrid/SightWordsCard/SightWordsContent/IconContainer
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
	if not module_progress:
		return
		
	var firebase_modules = await module_progress.fetch_modules()
	if firebase_modules.size() > 0:
		_update_progress_displays(firebase_modules)

func _update_progress_displays(firebase_modules: Dictionary):
	var total_progress = 0.0
	var category_count = 0
	
	for category_key in categories.keys():
		var firestore_key = categories[category_key]["firestore_key"]
		var progress_percent = 0.0
		
		# Get phonics data and calculate specific category progress
		if firebase_modules.has("phonics"):
			var phonics = firebase_modules["phonics"]
			if typeof(phonics) == TYPE_DICTIONARY:
				# Calculate category-specific progress from detailed phonics data
				if category_key == "letters":
					var letters_completed = phonics.get("letters_completed", []).size()
					progress_percent = (float(letters_completed) / 26.0) * 100.0
				elif category_key == "sight_words":
					var words_completed = phonics.get("sight_words_completed", []).size()
					progress_percent = (float(words_completed) / 20.0) * 100.0
		elif firebase_modules.has(firestore_key):
			var fm = firebase_modules[firestore_key]
			if typeof(fm) == TYPE_DICTIONARY:
				progress_percent = float(fm.get("progress", 0))
		
		# Update card progress label - fix the correct path
		var card_path = "MainContainer/ScrollContainer/CategoriesGrid/" + category_key.capitalize() + "Card"
		var progress_label = get_node_or_null(card_path + "/" + category_key.capitalize() + "Content/ProgressContainer/ProgressLabel")
		var progress_bar = get_node_or_null(card_path + "/" + category_key.capitalize() + "Content/ProgressContainer/ProgressBar")
		
		if progress_label:
			progress_label.text = str(int(progress_percent)) + "% Complete"
		if progress_bar:
			progress_bar.value = progress_percent
		
		total_progress += progress_percent
		category_count += 1
	
	# Update overall progress
	var overall_percent = total_progress / max(category_count, 1)
	var overall_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	var overall_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	
	if overall_label:
		overall_label.text = "Overall Progress: " + str(int(overall_percent)) + "%"
	if overall_bar:
		overall_bar.value = overall_percent

func _on_button_hover():
	$ButtonHover.play()

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Phonics Learning! Here you can practice two important skills. Choose 'Letters' to trace the alphabet from A to Z and learn letter sounds. Choose 'Sight Words' to practice common words like 'the', 'and', and 'to' that appear frequently in reading. Both activities will help improve your reading and writing skills!"
		
		# Simplified: just TTS without captions
		_speak_text_simple(guide_text)

func _on_tts_setting_button_pressed():
	$ButtonClick.play()
	print("PhonicsModule: Looking for TTSSettingsPopup (robust lookup)...")
	var tts_popup = get_node_or_null("TTSSettingsPopup")
	if not tts_popup:
		tts_popup = find_child("TTSSettingsPopup", true, false)
	if not tts_popup:
		print("PhonicsModule: TTSSettingsPopup not found - instantiating dynamically")
		var popup_scene: PackedScene = load("res://Scenes/TTSSettingsPopup.tscn")
		if popup_scene:
			tts_popup = popup_scene.instantiate()
			tts_popup.name = "TTSSettingsPopup"
			add_child(tts_popup)
	print("PhonicsModule: TTSSettingsPopup final status:", tts_popup != null)
	if tts_popup:
		# Pass current TTS instance to popup for voice testing
		if tts_popup.has_method("set_tts_instance"):
			tts_popup.set_tts_instance(tts)
		
		# Setup popup with current settings
		var current_voice = SettingsManager.get_setting("accessibility", "tts_voice_id")
		var current_rate = SettingsManager.get_setting("accessibility", "tts_rate")
		
		# Provide safe defaults
		if current_voice == null or current_voice == "":
			current_voice = "default"
		if current_rate == null:
			current_rate = 1.0
		
		if tts_popup.has_method("setup"):
			tts_popup.setup(tts, current_voice, current_rate, "Testing Text to Speech")
		
		# Connect to save signal
		if not tts_popup.settings_saved.is_connected(_on_tts_settings_saved):
			tts_popup.settings_saved.connect(_on_tts_settings_saved)
		
		tts_popup.visible = true
		print("PhonicsModule: TTS Settings popup opened")
	else:
		print("PhonicsModule: Warning - TTSSettingsPopup still not found after dynamic attempt")
		print("PhonicsModule: Available children:")
		for child in get_children():
			print("  - ", child.name, " (", child.get_class(), ")")

func _on_tts_settings_saved(voice_id: String, rate: float):
	"""Handle TTS settings save to update local TTS instance"""
	print("PhonicsModule: Saving TTS preferences - Voice: ", voice_id, " Rate: ", rate)
	
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
	print("PhonicsModule: Returning to module selection")
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
		print("PhonicsModule: TTS stopped before scene change")

# Ensure TTS cleanup on scene exit
func _exit_tree():
	_stop_tts()

func _on_letters_button_pressed():
	$ButtonClick.play()
	print("PhonicsModule: Starting Letters category")
	_launch_category("letters")

func _on_sight_words_button_pressed():
	$ButtonClick.play()
	print("PhonicsModule: Starting Sight Words category")
	_launch_category("sight_words")

func _launch_category(category_key: String):
	# Navigate to category scene
	var scene_path = categories[category_key]["scene_path"]
	_fade_out_and_change_scene(scene_path)
