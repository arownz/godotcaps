extends Control

var tts: TextToSpeech = null

# Categories: Only Letters and Sight Words
var categories = {
	"letters": {
		"scene_path": "res://Scenes/PhonicsLetters.tscn"
	},
	"sight_words": {
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
	await _load_category_progress()

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
	# Use direct Firebase access like authentication.gd pattern
	if Firebase.Auth.auth:
		print("PhonicsModule: Firebase available for progress tracking")
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
	if not Firebase.Auth.auth:
		print("PhonicsModule: Firebase not available or not authenticated")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Use authentication.gd pattern: direct document fetch
	print("PhonicsModule: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("PhonicsModule: Document fetched successfully")
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY:
			_update_progress_displays(modules)
		else:
			print("PhonicsModule: No modules data found")
	else:
		print("PhonicsModule: Failed to fetch document or document has error")

func _update_progress_displays(firebase_modules: Dictionary):
	# Letters progress
	var letters_percent = 0.0
	if firebase_modules.has("phonics"):
		var phonics = firebase_modules["phonics"]
		if typeof(phonics) == TYPE_DICTIONARY:
			var letters_completed = phonics.get("letters_completed", []).size()
			letters_percent = (float(letters_completed) / 26.0) * 100.0
	var letters_label = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/LettersCard/LettersContent/ProgressLabel")
	if letters_label:
		letters_label.text = str(int(letters_percent)) + "% Complete"

	# Sight Words progress
	var sight_words_percent = 0.0
	if firebase_modules.has("phonics"):
		var phonics = firebase_modules["phonics"]
		if typeof(phonics) == TYPE_DICTIONARY:
			var words_completed = phonics.get("sight_words_completed", []).size()
			sight_words_percent = (float(words_completed) / 20.0) * 100.0
	var sight_label = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/SightWordsCard/SightWordsContent/ProgressLabel")
	if sight_label:
		sight_label.text = str(int(sight_words_percent)) + "% Complete"

	# Overall progress (average)
	var overall_percent = (letters_percent + sight_words_percent) / 2.0
	var overall_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
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
