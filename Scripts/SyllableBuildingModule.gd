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
	# Initialize module progress for Firebase integration
	if Engine.has_singleton("Firebase"):
		var ModuleProgressScript = load("res://Scripts/ModulesManager/ModuleProgress.gd")
		if ModuleProgressScript:
			module_progress = ModuleProgressScript.new()
			is_firebase_available = await module_progress.is_authenticated()
			if is_firebase_available:
				print("SyllableBuildingModule: Firebase module progress initialized")
			else:
				print("SyllableBuildingModule: Firebase not authenticated, using local progress")
		else:
			print("SyllableBuildingModule: ModuleProgress script not found")
	else:
		print("SyllableBuildingModule: Firebase not available")

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
	# Load progress from Firebase
	if is_firebase_available and module_progress:
		var syllable_data = await module_progress.get_syllable_building_progress()
		if syllable_data:
			var progress_percent = syllable_data.get("progress", 0)
			_update_progress_ui(progress_percent)
			
			# Update individual category progress
			var basic_data = syllable_data.get("basic_syllables", {})
			var advanced_data = syllable_data.get("advanced_syllables", {})
			
			var basic_words = basic_data.get("basic_completed_words", []).size()
			var basic_percent = (float(basic_words) / 12.0) * 100
			basic_progress_label.text = str(int(basic_percent)) + "% Complete"
			
			var advanced_activities = advanced_data.get("activities_completed", []).size()
			var advanced_percent = (float(advanced_activities) / 6.0) * 100
			advanced_progress_label.text = str(int(advanced_percent)) + "% Complete"
			
			print("SyllableBuildingModule: Loaded progress - Basic:", int(basic_percent), "%, Advanced:", int(advanced_percent), "%")

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
