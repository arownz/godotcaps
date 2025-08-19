extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null
var completion_celebration: CanvasLayer = null

# Load completion celebration scene
var completion_celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")

# Categories: Animals and Food flip quiz games
var categories = {
	"animals": {
		"name": "Animals",
		"firestore_key": "flip_quiz_animals",
		"description": "Match cats, dogs, birds and fish",
		"scene_path": "res://Scenes/FlipQuizAnimals.tscn"
	},
	"food": {
		"name": "Food",
		"firestore_key": "flip_quiz_food",
		"description": "Match apples, bananas and bread",
		"scene_path": "res://Scenes/FlipQuizFood.tscn"
	}
}

# Load dyslexia-friendly font
var dyslexia_font: FontFile

# Dyslexia-friendly quiz sets with visual associations
var quiz_sets = {
	"Animals": [
		{"word": "cat", "emoji": "🐱", "sound": "meow"},
		{"word": "dog", "emoji": "🐶", "sound": "woof"},
		{"word": "monkey", "emoji": "🐒", "sound": "chirp"},
		{"word": "elephant", "emoji": "🐘", "sound": "trumpet"},
		{"word": "duck", "emoji": "🦆", "sound": "quack"},
		{"word": "fox", "emoji": "🦊", "sound": "yip"},
		{"word": "raccoon", "emoji": "🦝", "sound": "chitter"},
		{"word": "frog", "emoji": "🐸", "sound": "ribbit"}
	],
	"?": [
	]
}

var current_set = ""
var current_pairs = []
var flipped_cards = []
var matched_pairs = 0
var attempts = 0
var max_attempts = 15 # No harsh time limits, generous attempt allowance

func _speak_text_simple(text: String):
	"""Simple TTS without captions"""
	if tts:
		tts.speak(text)

func _ready():
	print("FlipQuizModule: Flip Quiz module loaded")
	
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
	"""Refresh progress display when user returns to flip quiz module"""
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
		print("FlipQuizModule: Firebase not available; progress won't sync")

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
			
	# Connect category buttons
	var animals_btn = $MainContainer/ScrollContainer/CategoriesGrid/AnimalsCard/AnimalsContent/EnterButton
	if animals_btn:
		if not animals_btn.mouse_entered.is_connected(_on_button_hover):
			animals_btn.mouse_entered.connect(_on_button_hover)
		if not animals_btn.pressed.is_connected(_on_animals_button_pressed):
			animals_btn.pressed.connect(_on_animals_button_pressed)

	var food_btn = $MainContainer/ScrollContainer/CategoriesGrid/FoodCard/FoodContent/EnterButton
	if food_btn:
		if not food_btn.mouse_entered.is_connected(_on_button_hover):
			food_btn.mouse_entered.connect(_on_button_hover)
		if not food_btn.pressed.is_connected(_on_food_button_pressed):
			food_btn.pressed.connect(_on_food_button_pressed)

func _style_category_cards():
	# Style icon containers with white background and black borders
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
		
		# Get flip quiz data and calculate specific category progress
		if firebase_modules.has("flip_quiz"):
			var flip_quiz = firebase_modules["flip_quiz"]
			if typeof(flip_quiz) == TYPE_DICTIONARY:
				# Calculate category-specific progress from detailed flip quiz data
				if category_key == "animals":
					var animals_completed = flip_quiz.get("animals_completed", []).size()
					progress_percent = (float(animals_completed) / 4.0) * 100.0 # 4 animal pairs
				elif category_key == "food":
					var food_completed = flip_quiz.get("food_completed", []).size()
					progress_percent = (float(food_completed) / 4.0) * 100.0 # 4 food pairs
		elif firebase_modules.has(firestore_key):
			var fm = firebase_modules[firestore_key]
			if typeof(fm) == TYPE_DICTIONARY:
				progress_percent = float(fm.get("progress", 0))
		
		# Update card progress label - fix the correct path
		var card_path = "MainContainer/ScrollContainer/CategoriesGrid/" + category_key.capitalize() + "Card"
		var progress_label = get_node_or_null(card_path + "/" + category_key.capitalize() + "Content/ProgressLabel")
		
		if progress_label:
			progress_label.text = str(int(progress_percent)) + "% Complete"
		
		total_progress += progress_percent
		category_count += 1
	
	# Update overall progress
	var overall_percent = total_progress / max(category_count, 1)
	var overall_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	
	if overall_label:
		overall_label.text = "Overall Progress: " + str(int(overall_percent)) + "%"

func _on_button_hover():
	$ButtonHover.play()

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Flip Quiz Learning! Here you can practice memory matching games with two fun categories. Choose 'Animals' to match animals. Choose 'Food' to match apples, bananas, bread, and milk with their words. Both activities will help improve your memory and reading skills!"
		
		# Simplified: just TTS without captions
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
		print("FlipQuizModule: TTS Settings popup opened")
	else:
		print("FlipQuizModule: Warning - TTSSettingsPopup still not found after dynamic attempt")

func _on_tts_settings_saved(voice_id: String, rate: float):
	"""Handle TTS settings save to update local TTS instance"""
	print("FlipQuizModule: Saving TTS preferences - Voice: ", voice_id, " Rate: ", rate)
	
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
	print("FlipQuizModule: Returning to module selection")
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
		print("FlipQuizModule: TTS stopped before scene change")

# Ensure TTS cleanup on scene exit
func _exit_tree():
	_stop_tts()

func _on_animals_button_pressed():
	$ButtonClick.play()
	print("FlipQuizModule: Starting Animals category")
	_launch_category("animals")

func _on_food_button_pressed():
	$ButtonClick.play()
	print("FlipQuizModule: Starting Food category")
	_launch_category("food")

func _launch_category(category_key: String):
	# Navigate to category scene
	var scene_path = categories[category_key]["scene_path"]
	_fade_out_and_change_scene(scene_path)