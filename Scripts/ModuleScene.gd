extends Control

# Module config (presentation + totals). Progress is fetched from Firestore.
var module_data = {
	"phonics": {
		"name": "Phonics Interactive",
		"description": "Trace while hearing sounds",
		"total_lessons": 20,
		"scene_path": "res://Scenes/PhonicsModule.tscn"
	},
	"flip_quiz": {
		"name": "Flip Quiz",
		"description": "Flashcard game with symbols",
		"total_lessons": 20,
		"scene_path": "res://Scenes/FlipQuizModule.tscn"
	},
	"read_aloud": {
		"name": "Interactive Read-Aloud",
		"description": "Follow highlighted text with audio",
		"total_lessons": 20,
		"scene_path": "res://Scenes/ReadAloudModule.tscn"
	},
	"chunked_reading": {
		"name": "Chunked Reading",
		"description": "Small sections with guided questions",
		"total_lessons": 20,
		"scene_path": "res://Scenes/ChunkedReadingModule.tscn"
	}, "syllable_building": {
		"name": "Syllable Building",
		"description": "Drag syllables to build words",
		"total_lessons": 20,
		"scene_path": "res://Scenes/SyllableBuildingModule.tscn"
	},
	"speech": {
		"name": "Speech Recognition",
		"description": "Practice pronunciation with AI feedback",
		"total_lessons": 20,
		"scene_path": "res://Scenes/WordChallengePanel_STT.tscn"
	}
}

# Node references
var title_label

# Module button references
var phonics_button
var flip_quiz_button
var read_aloud_button
var chunked_reading_button
var syllable_building_button

# Progress tracking
var user_progress_data = {}

# Firebase modules progress (Firestore)
var firebase_modules: Dictionary = {}
var module_progress = null

# Load dyslexia-friendly font
var dyslexia_font: FontFile

func _ready():
	print("ModuleScene: Initializing module selection interface")
	
	# Enhanced fade-in animation matching SettingScene style
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Load dyslexia-friendly font
	_load_dyslexia_font()
	
	# Get node references
	_get_node_references()
	
	# Connect button signals
	_connect_signals()
	
	# Load user progress from save file (offline fallback)
	_load_user_progress()

	# Load Firestore-backed module progress
	await _load_firestore_modules()
	
	# Update UI with current progress
	_update_progress_displays()
	
	# Apply dyslexia-friendly styling
	_apply_dyslexia_friendly_styling()
	
	# Apply dyslexia font to all text elements
	_apply_dyslexia_font_to_node(self)
	
	# Load dyslexia font
	_load_dyslexia_font()

func _load_firestore_modules():
	# Create and fetch Firestore-backed module progress
	if Engine.has_singleton("Firebase"):
		module_progress = ModuleProgress.new()
		add_child(module_progress)
		firebase_modules = await module_progress.fetch_modules()
		if firebase_modules.size() > 0:
			print("ModuleScene: Loaded Firestore module progress: ", firebase_modules)
			_update_progress_displays()
	else:
		print("ModuleScene: Firebase not available or not initialized")

func _get_node_references():
	# Main navigation - now using the new navigation bar
	var menu_button = get_node_or_null("MainContainer/HeaderPanel/HeaderContainer/TitleContainer/MenuButton")
	
	title_label = get_node_or_null("MainContainer/HeaderPanel/HeaderContainer/TitleContainer/TitleLabel")
	
	# Module buttons (now using the new card structure)
	phonics_button = get_node_or_null("MainContainer/ScrollContainer/ContentContainer/ModulesGrid/PhonicsCard/CardContent/ActionButton")
	flip_quiz_button = get_node_or_null("MainContainer/ScrollContainer/ContentContainer/ModulesGrid/FlipQuizCard/CardContent/ActionButton")
	read_aloud_button = get_node_or_null("MainContainer/ScrollContainer/ContentContainer/ModulesGrid/ReadAloudCard/CardContent/ActionButton")
	chunked_reading_button = get_node_or_null("MainContainer/ScrollContainer/ContentContainer/ModulesGrid/ChunkedReadingCard/CardContent/ActionButton")
	syllable_building_button = get_node_or_null("MainContainer/ScrollContainer/ContentContainer/ModulesGrid/SyllableBuildingCard/CardContent/ActionButton")
	var adaptive_button = get_node_or_null("MainContainer/ScrollContainer/ContentContainer/ModulesGrid/AdaptiveLearningCard/CardContent/ActionButton")
	
	# Connect navigation buttons
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
		menu_button.mouse_entered.connect(_on_button_hover)

	if adaptive_button:
		adaptive_button.pressed.connect(_show_coming_soon_notification.bind("Adaptive Learning", "AI"))
	
	# Debug: Check if nodes were found
	if not menu_button:
		print("Warning: Menu button not found")
	if not phonics_button:
		print("Warning: Phonics button not found")
	if not flip_quiz_button:
		print("Warning: Flip quiz button not found")
	if not read_aloud_button:
		print("Warning: Read aloud button not found")
	if not chunked_reading_button:
		print("Warning: Chunked reading button not found")
	if not syllable_building_button:
		print("Warning: Syllable building button not found")

func _connect_signals():
	# Connect module buttons
	if phonics_button:
		phonics_button.pressed.connect(_on_phonics_button_pressed)
		phonics_button.mouse_entered.connect(_on_button_hover)
	if flip_quiz_button:
		flip_quiz_button.pressed.connect(_on_flip_quiz_button_pressed)
		flip_quiz_button.mouse_entered.connect(_on_button_hover)
	if read_aloud_button:
		read_aloud_button.pressed.connect(_on_read_aloud_button_pressed)
		read_aloud_button.mouse_entered.connect(_on_button_hover)
	if chunked_reading_button:
		chunked_reading_button.pressed.connect(_on_chunked_reading_button_pressed)
		chunked_reading_button.mouse_entered.connect(_on_button_hover)
	if syllable_building_button:
		syllable_building_button.pressed.connect(_on_syllable_building_button_pressed)
		syllable_building_button.mouse_entered.connect(_on_button_hover)

func _load_user_progress():
	# Load progress from user save file
	var save_file_path = "user://module_progress.save"
	
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				user_progress_data = json.data
				print("ModuleScene: Loaded user progress data")
			else:
				print("ModuleScene: Error parsing progress save file")
	else:
		# Initialize default progress
		user_progress_data = {
			"phonics": {"current_lesson": 1, "completed_lessons": []},
			"flip_quiz": {"current_lesson": 1, "completed_lessons": []},
			"read_aloud": {"current_lesson": 1, "completed_lessons": []},
			"chunked_reading": {"current_lesson": 1, "completed_lessons": []},
			"syllable_building": {"current_lesson": 1, "completed_lessons": []},
			"speech": {"current_lesson": 1, "completed_lessons": []}
		}
		_save_user_progress()

func _save_user_progress():
	var save_file_path = "user://module_progress.save"
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	
	if file:
		var json_string = JSON.stringify(user_progress_data)
		file.store_string(json_string)
		file.close()
		print("ModuleScene: Saved user progress data")

func _update_progress_displays():
	# Update each module's progress display using new card structure
	_update_card_progress("phonics", "PhonicsCard")
	_update_card_progress("flip_quiz", "FlipQuizCard")
	_update_card_progress("read_aloud", "ReadAloudCard")
	_update_card_progress("chunked_reading", "ChunkedReadingCard")
	_update_card_progress("syllable_building", "SyllableBuildingCard")
	_update_card_progress("speech", "SpeechCard")

func _update_card_progress(module_key: String, card_name: String):
	var modules_grid = get_node_or_null("MainContainer/ScrollContainer/ContentContainer/ModulesGrid")
	if not modules_grid:
		print("Warning: ModulesGrid not found")
		return
		
	var card_node = modules_grid.get_node_or_null(card_name)
	if not card_node:
		print("Warning: Card node not found: " + card_name)
		return

	# Prefer Firestore progress if available, else fallback to local file percent
	var progress_percent := 0.0
	var completed := false
	if firebase_modules.has(module_key):
		var fm = firebase_modules[module_key]
		if typeof(fm) == TYPE_DICTIONARY:
			progress_percent = float(fm.get("progress", 0))
			completed = bool(fm.get("completed", false))
	elif user_progress_data.has(module_key) and module_data.has(module_key):
		var progress = user_progress_data[module_key]
		var completed_count = progress.completed_lessons.size()
		var total_lessons = int(module_data[module_key]["total_lessons"]) if module_data.has(module_key) and module_data[module_key].has("total_lessons") else 20
		progress_percent = (float(completed_count) / float(total_lessons)) * 100.0
		completed = completed_count == total_lessons

	# Update progress bar
	var progress_bar = card_node.get_node_or_null("CardContent/ProgressContainer/ProgressBar")
	if progress_bar:
		progress_bar.value = progress_percent

	# Update progress label
	var progress_label = card_node.get_node_or_null("CardContent/ProgressContainer/ProgressLabel")
	if progress_label:
		progress_label.text = str(int(progress_percent)) + "% Complete"

	# Update action button text
	var action_button = card_node.get_node_or_null("CardContent/ActionButton")
	if action_button:
		if int(progress_percent) == 0:
			action_button.text = "Start Learning"
		elif completed or int(progress_percent) >= 100:
			action_button.text = "COMPLETED"
		else:
			action_button.text = "Continue Learning"

func _apply_dyslexia_friendly_styling():
	# Apply consistent styling for better readability
	var title_font_size = 32
	var _card_font_size = 16
	var _button_font_size = 18
	
	# Style title
	if title_label:
		title_label.add_theme_font_size_override("font_size", title_font_size)
	
	# Style cards with rounded corners and better spacing
	_style_module_cards()

func _style_module_cards():
	var modules_grid = get_node_or_null("MainContainer/MarginContainer/ScrollContainer/ModulesContainer/ModulesGrid")
	if not modules_grid:
		print("Warning: ModulesGrid not found for styling")
		return
	
	# Apply consistent styling to all module cards
	for child in modules_grid.get_children():
		if child is Panel:
			# Create a StyleBoxFlat for rounded corners
			var style_box = StyleBoxFlat.new()
			style_box.corner_radius_top_left = 15
			style_box.corner_radius_top_right = 15
			style_box.corner_radius_bottom_left = 15
			style_box.corner_radius_bottom_right = 15
			style_box.bg_color = Color(1.0, 1.0, 1.0, 0.9) # White with slight transparency
			style_box.border_width_left = 3
			style_box.border_width_right = 3
			style_box.border_width_top = 3
			style_box.border_width_bottom = 3
			style_box.border_color = Color(0.2, 0.4, 0.8, 0.6) # Light blue border
			
			child.add_theme_stylebox_override("panel", style_box)

# Load dyslexia-friendly font
func _load_dyslexia_font():
	dyslexia_font = load("res://Fonts/dyslexiafont/OpenDyslexic-Regular.otf")
	if not dyslexia_font:
		print("Warning: Could not load OpenDyslexic font, falling back to default")

func _apply_dyslexia_font_to_node(node: Node):
	if node is Label:
		if dyslexia_font:
			node.add_theme_font_override("font", dyslexia_font)
	elif node is Button:
		if dyslexia_font:
			node.add_theme_font_override("font", dyslexia_font)
	elif node is RichTextLabel:
		if dyslexia_font:
			node.add_theme_font_override("normal_font", dyslexia_font)
	
	# Recursively apply to all children
	for child in node.get_children():
		_apply_dyslexia_font_to_node(child)

# Button sound event handlers
func _on_button_hover():
	$ButtonHover.play()

# Module button event handlers
func _on_menu_button_pressed():
	$ButtonClick.play()
	print("ModuleScene: Going back to Main Menu")
	_fade_out_and_change_scene("res://Scenes/MainMenu.tscn")

# Helper function to fade out before changing scenes
func _fade_out_and_change_scene(scene_path: String):
	# Enhanced fade-out animation matching SettingScene style
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_phonics_button_pressed():
	$ButtonClick.play()
	print("ModuleScene: Starting Phonics Interactive module")
	_launch_module("phonics")

func _on_flip_quiz_button_pressed():
	$ButtonClick.play()
	print("ModuleScene: Starting Flip Quiz module")
	_launch_module("flip_quiz")

func _on_read_aloud_button_pressed():
	$ButtonClick.play()
	print("ModuleScene: Starting Interactive Read-Aloud module")
	_launch_module("read_aloud")

func _on_chunked_reading_button_pressed():
	$ButtonClick.play()
	print("ModuleScene: Starting Chunked Reading module")
	_launch_module("chunked_reading")

func _on_syllable_building_button_pressed():
	$ButtonClick.play()
	print("ModuleScene: Starting Syllable Building module")
	_launch_module("syllable_building")

func _launch_module(module_key: String):
	# Store current module for returning later
	# Navigate to appropriate module scene with fade animation
	match module_key:
		"phonics":
			_fade_out_and_change_scene("res://Scenes/PhonicsModule.tscn")
		"flip_quiz":
			_fade_out_and_change_scene("res://Scenes/FlipQuizModule.tscn")
		"read_aloud":
			_fade_out_and_change_scene("res://Scenes/ReadAloudModule.tscn")
		"chunked_reading":
			_fade_out_and_change_scene("res://Scenes/ChunkedReadingModule.tscn")
		"syllable_building":
			_fade_out_and_change_scene("res://Scenes/SyllableBuildingModule.tscn")

func _show_coming_soon_notification(module_name: String, icon: String):
	# Create a simple notification popup
	var dialog = AcceptDialog.new()
	dialog.title = icon + " " + module_name
	dialog.dialog_text = "This module is coming soon!\n\nWe're working hard to bring you an amazing " + module_name.to_lower() + " experience that will help improve your reading skills."
	dialog.ok_button_text = "Got it!"
	
	# Add to scene and show
	add_child(dialog)
	dialog.popup_centered()
	
	# Remove after closing
	dialog.confirmed.connect(func(): dialog.queue_free())

# Function to update progress when a lesson is completed (called from other scenes)
func update_module_progress(module_key: String, lesson_number: int):
	if user_progress_data.has(module_key):
		if not user_progress_data[module_key].completed_lessons.has(lesson_number):
			user_progress_data[module_key].completed_lessons.append(lesson_number)
			user_progress_data[module_key].current_lesson = lesson_number + 1
			_save_user_progress()
			print("ModuleScene: Updated progress for " + module_key + " - completed lesson " + str(lesson_number))

# Function to get overall progress for profile display
func get_overall_progress() -> Dictionary:
	var total_lessons = 0
	var completed_lessons = 0
	
	for module_key in user_progress_data.keys():
		total_lessons += int(module_data[module_key]["total_lessons"]) if module_data.has(module_key) and module_data[module_key].has("total_lessons") else 20
		completed_lessons += user_progress_data[module_key].completed_lessons.size()
	
	var overall_percent = (float(completed_lessons) / float(total_lessons)) * 100.0
	
	return {
		"completed_lessons": completed_lessons,
		"total_lessons": total_lessons,
		"progress_percent": overall_percent,
		"modules_data": user_progress_data
	}
