extends Control

var tts: TextToSpeech = null

# Categories for Chunked Reading
var categories = {
	"vocabulary_building": {
		"title": "Vocabulary Building",
		"icon": "📚",
		"description": "Learn new words in context through chunked passages. Build your vocabulary while improving comprehension.",
		"scene_path": "res://Scenes/ChunkedVocabulary.tscn"
	},
	"chunked_question": {
		"title": "Chunked Question",
		"icon": "❓",
		"description": "Answer questions based on chunked passages. Improve comprehension and retention through targeted questioning.",
		"scene_path": "res://Scenes/ChunkedQuestion.tscn"
	}
}

func _ready():
	print("ChunkedReadingModule: Initializing")
	
	# Setup fade-in animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	
	# Initialize components
	_init_tts()
	
	# Setup category cards
	_setup_category_cards()
	
	# Connect button hover events for audio feedback
	_connect_hover_events()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window regains focus
		call_deferred("_refresh_progress")

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
		get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/VocubalaryCard/Content/IconContainer"),
		get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/QuestionCard/Content/IconContainer")
	]
	for icon_container in icon_containers:
		if icon_container:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, 1)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_left = 10
			style.corner_radius_bottom_right = 10
			icon_container.add_theme_stylebox_override("panel", style)
	# Load progress
	_refresh_progress()

func _refresh_progress():
	"""Update progress displays from Firebase data"""
	if not Engine.has_singleton("Firebase") or not Firebase.Auth.auth:
		print("ChunkedReadingModule: Firebase not available or not authenticated")
		return
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("ChunkedReadingModule: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys()):
		print("ChunkedReadingModule: Document fetched successfully")
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY:
			_update_progress_displays(modules)
		else:
			print("ChunkedReadingModule: No modules data found")
	else:
		print("ChunkedReadingModule: Failed to fetch document")

func _update_progress_displays(firebase_modules: Dictionary):
	"""Update all progress displays from Firebase data"""
	# Vocabulary progress
	var vocab_percent = 0.0
	var question_percent = 0.0
	if firebase_modules.has("chunked_reading"):
		var chunked = firebase_modules["chunked_reading"]
		if typeof(chunked) == TYPE_DICTIONARY:
			var completed_vocab = chunked.get("completed_vocabulary", []).size()
			vocab_percent = (float(completed_vocab) / 10.0) * 100.0
			var completed_questions = chunked.get("completed_questions", []).size()
			question_percent = (float(completed_questions) / 10.0) * 100.0
	var vocab_label = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/VocubalaryCard/Content/ProgressLabel")
	if vocab_label:
		vocab_label.text = str(int(vocab_percent)) + "% Complete"
	var question_label = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/QuestionCard/Content/ProgressLabel")
	if question_label:
		question_label.text = str(int(question_percent)) + "% Complete"
	# Overall progress
	var overall_percent = (vocab_percent + question_percent) / 2.0
	var progress_bar = get_node_or_null("MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar")
	if progress_bar:
		progress_bar.value = overall_percent

func _connect_hover_events():
	# Connect back button hover
	var back_btn = get_node_or_null("MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton")
	if back_btn and not back_btn.mouse_entered.is_connected(_on_button_hover):
		back_btn.mouse_entered.connect(_on_button_hover)
		if not back_btn.pressed.is_connected(_on_back_button_pressed):
			back_btn.pressed.connect(_on_back_button_pressed)
	
	# Connect guide button
	var guide_btn = get_node_or_null("MainContainer/HeaderPanel/GuideButton")
	if guide_btn:
		if not guide_btn.mouse_entered.is_connected(_on_button_hover):
			guide_btn.mouse_entered.connect(_on_button_hover)
		if not guide_btn.pressed.is_connected(_on_guide_button_pressed):
			guide_btn.pressed.connect(_on_guide_button_pressed)
	
	# Connect TTS settings button
	var tts_btn = get_node_or_null("MainContainer/HeaderPanel/TTSSettingButton")
	if tts_btn:
		if not tts_btn.mouse_entered.is_connected(_on_button_hover):
			tts_btn.mouse_entered.connect(_on_button_hover)
		if not tts_btn.pressed.is_connected(_on_tts_setting_button_pressed):
			tts_btn.pressed.connect(_on_tts_setting_button_pressed)
	
	# Connect category enter buttons
	var vocab_enter_btn = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/VocubalaryCard/Content/EnterButton")
	if vocab_enter_btn:
		if not vocab_enter_btn.mouse_entered.is_connected(_on_button_hover):
			vocab_enter_btn.mouse_entered.connect(_on_button_hover)
		if not vocab_enter_btn.pressed.is_connected(_on_vocabulary_building_button_pressed):
			vocab_enter_btn.pressed.connect(_on_vocabulary_building_button_pressed)
	
	var question_enter_btn = get_node_or_null("MainContainer/ScrollContainer/CategoriesGrid/QuestionCard/Content/EnterButton")
	if question_enter_btn:
		if not question_enter_btn.mouse_entered.is_connected(_on_button_hover):
			question_enter_btn.mouse_entered.connect(_on_button_hover)
		if not question_enter_btn.pressed.is_connected(_on_chunked_question_button_pressed):
			question_enter_btn.pressed.connect(_on_chunked_question_button_pressed)

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("ChunkedReadingModule: Returning to module selection")
	_fade_out_and_change_scene("res://Scenes/ModuleScene.tscn")

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Chunked Reading! We have two activities: Vocabulary Building helps you learn new words in context, and Chunked Question helps you answer comprehension questions. Choose an activity to begin!"
		tts.speak(guide_text)

func _on_tts_setting_button_pressed():
	$ButtonClick.play()
	var tts_popup = get_node_or_null("TTSSettingsPopup")
	if not tts_popup:
		var popup_scene = load("res://Scenes/TTSSettingsPopup.tscn")
		if popup_scene:
			tts_popup = popup_scene.instantiate()
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


func _on_vocabulary_building_button_pressed():
	$ButtonClick.play()
	print("ChunkedReadingModule: Starting Vocabulary Building")
	_fade_out_and_change_scene(categories["vocabulary_building"]["scene_path"])

func _on_chunked_question_button_pressed():
	$ButtonClick.play()
	print("ChunkedReadingModule: Starting Chunked Question")
	_fade_out_and_change_scene(categories["chunked_question"]["scene_path"])

func _fade_out_and_change_scene(scene_path: String):
	_stop_tts()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _stop_tts():
	if tts and tts.has_method("stop"):
		tts.stop()

func _exit_tree():
	_stop_tts()