extends Control

var tts: TextToSpeech = null

# Firebase integration for module progress
var module_progress
var is_firebase_available = false

# UI References - Updated to match actual scene structure
@onready var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
@onready var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
@onready var basic_button = $MainContainer/ScrollContainer/CategoriesGrid/BasicSyllablesCard/Content/EnterButton
@onready var advanced_button = $MainContainer/ScrollContainer/CategoriesGrid/AdvancedSyllablesCard/Content/EnterButton
@onready var basic_progress_label = $MainContainer/ScrollContainer/CategoriesGrid/BasicSyllablesCard/Content/ProgressLabel
@onready var advanced_progress_label = $MainContainer/ScrollContainer/CategoriesGrid/AdvancedSyllablesCard/Content/ProgressLabel

# Audio
@onready var button_click = $ButtonClick
@onready var button_hover = $ButtonHover

func _ready():
	_init_tts()
	await _init_module_progress()
	await _load_progress()
	_setup_ui()
	_connect_buttons()
	
	# Enhanced fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_setup_category_cards()

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

func _setup_category_cards():
	# Apply rounded corners and backgrounds to icon containers
	var icon_containers = [
		$"MainContainer/ScrollContainer/CategoriesGrid/BasicSyllablesCard/Content/IconContainer/CenterContainer",
		$"MainContainer/ScrollContainer/CategoriesGrid/AdvancedSyllablesCard/Content/IconContainer/CenterContainer"
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

func _init_module_progress():
	# Use direct Firebase access like authentication.gd pattern
	if Firebase.Auth.auth:
		print("SyllableBuildingModule: Firebase available for progress tracking")
	else:
		print("SyllableBuildingModule: Firebase not available; progress won't sync")

func _setup_ui():
	# Connect button signals
	if basic_button:
		basic_button.pressed.connect(_on_basic_syllables_pressed)
		basic_button.mouse_entered.connect(_on_button_mouse_entered)
	
	if advanced_button:
		advanced_button.pressed.connect(_on_advanced_syllables_pressed)
		advanced_button.mouse_entered.connect(_on_button_mouse_entered)

func _connect_buttons():
	# Connect back button
	var back_btn = get_node_or_null("MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton")
	if back_btn:
		if not back_btn.mouse_entered.is_connected(_on_button_mouse_entered):
			back_btn.mouse_entered.connect(_on_button_mouse_entered)
		if not back_btn.pressed.is_connected(_on_back_button_pressed):
			back_btn.pressed.connect(_on_back_button_pressed)
	
	# Connect guide button
	var guide_btn = get_node_or_null("MainContainer/HeaderPanel/GuideButton")
	if guide_btn:
		if not guide_btn.mouse_entered.is_connected(_on_button_mouse_entered):
			guide_btn.mouse_entered.connect(_on_button_mouse_entered)
		if not guide_btn.pressed.is_connected(_on_guide_button_pressed):
			guide_btn.pressed.connect(_on_guide_button_pressed)
	
	# Connect TTS settings button
	var tts_btn = get_node_or_null("MainContainer/HeaderPanel/TTSSettingButton")
	if tts_btn:
		if not tts_btn.mouse_entered.is_connected(_on_button_mouse_entered):
			tts_btn.mouse_entered.connect(_on_button_mouse_entered)
		if not tts_btn.pressed.is_connected(_on_tts_setting_button_pressed):
			tts_btn.pressed.connect(_on_tts_setting_button_pressed)

func _load_progress():
	# Load progress from Firebase using the same pattern as other modules
	if not Firebase.Auth.auth:
		print("SyllableBuildingModule: Firebase not available or not authenticated")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("SyllableBuildingModule: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		print("SyllableBuildingModule: Document fetched successfully")
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY:
			_update_progress_displays(modules)
		else:
			print("SyllableBuildingModule: No modules data found")
	else:
		print("SyllableBuildingModule: Failed to fetch document")

func _update_progress_displays(firebase_modules: Dictionary):
	# Basic Syllables progress
	var basic_percent = 0.0
	var advanced_percent = 0.0
	if firebase_modules.has("syllable_building"):
		var syllable_building = firebase_modules["syllable_building"]
		if typeof(syllable_building) == TYPE_DICTIONARY:
			# Get basic syllables progress
			var basic_data = syllable_building.get("basic_syllables", {})
			var basic_words = basic_data.get("basic_completed_words", []).size()
			basic_percent = (float(basic_words) / 12.0) * 100.0
			
			# Get advanced syllables progress
			var advanced_data = syllable_building.get("advanced_syllables", {})
			var advanced_activities = advanced_data.get("activities_completed", []).size()
			advanced_percent = (float(advanced_activities) / 6.0) * 100.0
	
	if basic_progress_label:
		basic_progress_label.text = str(int(basic_percent)) + "% Complete"
	if advanced_progress_label:
		advanced_progress_label.text = str(int(advanced_percent)) + "% Complete"
	
	# Overall progress calculation
	var overall_percent = (basic_percent + advanced_percent) / 2.0
	if progress_bar:
		progress_bar.value = overall_percent
	if progress_label:
		progress_label.text = str(int(overall_percent)) + "% Complete"
	
	print("SyllableBuildingModule: Progress updated - Basic: ", int(basic_percent), "%, Advanced: ", int(advanced_percent), "%, Overall: ", int(overall_percent), "%")

func _update_progress_ui(percent: float):
	if progress_bar:
		progress_bar.value = percent
	if progress_label:
		progress_label.text = "Overall Progress: " + str(int(percent)) + "%"

func _on_basic_syllables_pressed():
	button_click.play()
	print("SyllableBuildingModule: Opening Basic Syllables")
	_fade_out_and_change_scene("res://Scenes/BasicSyllablesScene.tscn")

func _on_advanced_syllables_pressed():
	button_click.play()
	print("SyllableBuildingModule: Opening Advanced Syllables")
	_fade_out_and_change_scene("res://Scenes/AdvancedSyllablesScene.tscn")

func _on_back_button_pressed():
	button_click.play()
	print("SyllableBuildingModule: Returning to module selections")
	_fade_out_and_change_scene("res://Scenes/ModuleScene.tscn")

func _on_guide_button_pressed():
	button_click.play()
	if tts:
		var guide_text = "Welcome to Syllable Building! We have two activities: Basic Syllables helps you break down simple words, and Advanced Syllables teaches complex patterns. Choose an activity to begin!"
		tts.speak(guide_text)

func _on_tts_setting_button_pressed():
	button_click.play()
	var tts_popup = get_node_or_null("TTSSettingsPopup")
	if not tts_popup:
		var popup_scene = load("res://Scenes/TTSSettingsPopup.tscn")
		if popup_scene:
			tts_popup = popup_scene.instantiate()
			tts_popup.name = "TTSSettingsPopup"
			add_child(tts_popup)
			
			# Setup popup
			var current_voice = SettingsManager.get_setting("accessibility", "tts_voice_id")
			var current_rate = SettingsManager.get_setting("accessibility", "tts_rate")
			
			if current_voice == null or current_voice == "":
				current_voice = "default"
			if current_rate == null:
				current_rate = 1.0
			
			if tts_popup.has_method("setup"):
				tts_popup.setup(tts, current_voice, current_rate, "Testing Text to Speech")
			
			# Connect settings saved signal
			if not tts_popup.settings_saved.is_connected(_on_tts_settings_saved):
				tts_popup.settings_saved.connect(_on_tts_settings_saved)
	
	if tts_popup:
		tts_popup.visible = true

func _on_tts_settings_saved(voice_id: String, rate: float):
	if tts:
		if voice_id != null and voice_id != "":
			tts.set_voice(voice_id)
		if rate != null:
			tts.set_rate(rate)
	
	SettingsManager.set_setting("accessibility", "tts_voice_id", voice_id)
	SettingsManager.set_setting("accessibility", "tts_rate", rate)

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

func _on_button_mouse_entered():
	button_hover.play()
