extends Control

# Module config (presentation + totals). Progress is fetched from Firestore.
var module_data = {
	"phonics": {
		"name": "Phonics Interactive",
		"total_lessons": 46, # 26 letters + 20 sight words
		"scene_path": "res://Scenes/PhonicsModule.tscn"
	},
	"flip_quiz": {
		"name": "Flip Quiz",
		"total_lessons": 20,
		"scene_path": "res://Scenes/FlipQuizModule.tscn"
	},
	"read_aloud": {
		"name": "Interactive Read-Aloud",
		"total_lessons": 15, # More realistic for reading passages
		"scene_path": "res://Scenes/ReadAloudModule.tscn"
	},
	"chunked_reading": {
		"name": "Chunked Reading",
		"total_lessons": 12, # More realistic for reading comprehension
		"scene_path": "res://Scenes/ChunkedReadingModule.tscn"
	},
	"syllable_building": {
		"name": "Syllable Building",
		"total_lessons": 25, # Variety of syllable patterns
		"scene_path": "res://Scenes/SyllableBuildingModule.tscn"
	},
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

# Firebase modules progress (Firestore) - using direct access like Journey Mode
var firebase_modules: Dictionary = {}

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

	
	# Get node references
	_get_node_references()
	
	# Connect button signals
	_connect_signals()

	# Load Firestore-backed module progress
	await _load_firestore_modules()
	
	# Update UI with current progress
	_update_progress_displays()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window regains focus (user returns from practice)
		call_deferred("_refresh_progress")

func _refresh_progress():
	"""Refresh progress display when user returns to module selection"""
	print("ModuleScene: Refreshing progress display")
	await _load_firestore_modules()

func _load_firestore_modules():
	# Use direct Firebase access like authentication.gd pattern
	if Firebase.Auth.auth:
		print("ModuleScene: Loading modules from Firebase directly")
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		# Use working authentication.gd pattern: direct document fetch
		var document = await collection.get_doc(user_id)
		if document and !("error" in document.keys() and document.get_value("error")):
			print("ModuleScene: Document fetched successfully")
			var modules = document.get_value("modules")
			if modules != null and typeof(modules) == TYPE_DICTIONARY:
				firebase_modules = modules
				print("ModuleScene: Loaded Firebase module progress: ", firebase_modules.keys())
				if firebase_modules.has("phonics"):
					print("ModuleScene: Phonics progress: ", firebase_modules["phonics"].get("progress", 0), "%")
				if firebase_modules.has("flip_quiz"):
					print("ModuleScene: Flip Quiz progress: ", firebase_modules["flip_quiz"].get("progress", 0), "%")
				_update_progress_displays()
			else:
				print("ModuleScene: No modules data found in document")
		else:
			print("ModuleScene: Failed to fetch document or document has error")
	else:
		print("ModuleScene: Firebase not available or not authenticated")

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

	else:
		# Initialize default progress
		user_progress_data = {
			"phonics": {"current_lesson": 1, "completed_lessons": []},
			"flip_quiz": {"current_lesson": 1, "completed_lessons": []},
			"read_aloud": {"current_lesson": 1, "completed_lessons": []},
			"chunked_reading": {"current_lesson": 1, "completed_lessons": []},
			"syllable_building": {"current_lesson": 1, "completed_lessons": []},
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

func _update_card_progress(module_key: String, card_name: String):
	var modules_grid = get_node_or_null("MainContainer/ScrollContainer/ContentContainer/ModulesGrid")
	if not modules_grid:
		print("Warning: ModulesGrid not found")
		return
		
	var card_node = modules_grid.get_node_or_null(card_name)
	if not card_node:
		print("Warning: Card node not found: " + card_name)
		return

	# Calculate overall progress from detailed Firebase structures (for ModuleScene overall view)
	var progress_percent := 0.0
	var completed := false
	
	if firebase_modules.has(module_key):
		var fm = firebase_modules[module_key]
		if typeof(fm) == TYPE_DICTIONARY:
			# Calculate overall progress based on module type
			if module_key == "phonics":
				# Overall phonics progress: average of letters and sight words
				var letters_completed = fm.get("letters_completed", []).size()
				var sight_words_completed = fm.get("sight_words_completed", []).size()
				var letters_percent = (float(letters_completed) / 26.0) * 100.0
				var sight_words_percent = (float(sight_words_completed) / 20.0) * 100.0
				progress_percent = (letters_percent + sight_words_percent) / 2.0
				completed = (letters_completed >= 26 and sight_words_completed >= 20)
				print("ModuleScene: Phonics overall - Letters:", letters_completed, "/26, Sight Words:", sight_words_completed, "/20, Overall:", int(progress_percent), "%")
			elif module_key == "flip_quiz":
				# Overall flip quiz progress based on completed sets from both animals and vehicles
				var total_animals_sets = 0
				var total_vehicles_sets = 0
				
				# Check animals progress
				if fm.has("animals") and typeof(fm["animals"]) == TYPE_DICTIONARY:
					var animals_sets = fm["animals"].get("sets_completed", [])
					total_animals_sets = animals_sets.size()
				
				# Check vehicles progress
				if fm.has("vehicles") and typeof(fm["vehicles"]) == TYPE_DICTIONARY:
					var vehicles_sets = fm["vehicles"].get("sets_completed", [])
					total_vehicles_sets = vehicles_sets.size()
				
				var total_completed_sets = total_animals_sets + total_vehicles_sets
				var total_possible_sets = 6 # 3 sets per category (animals + vehicles) = 6 total
				progress_percent = (float(total_completed_sets) / float(total_possible_sets)) * 100.0
				completed = total_completed_sets >= total_possible_sets
				print("ModuleScene: FlipQuiz overall - Animals sets:", total_animals_sets, "/3, Vehicles sets:", total_vehicles_sets, "/3, Total:", total_completed_sets, "/", total_possible_sets, ", Overall:", int(progress_percent), "%")
			elif module_key == "read_aloud":
				# Overall read aloud progress based on completed stories and guided activities
				var stories_completed = 0
				var guided_completed = 0
				
				# Check stories progress
				if fm.has("stories") and typeof(fm["stories"]) == TYPE_DICTIONARY:
					var stories_data = fm["stories"].get("stories_completed", [])
					stories_completed = stories_data.size()
				
				# Check guided progress  
				if fm.has("guided") and typeof(fm["guided"]) == TYPE_DICTIONARY:
					var guided_data = fm["guided"].get("activities_completed", [])
					guided_completed = guided_data.size()
				
				var total_completed = stories_completed + guided_completed
				var total_possible = 15 # Total activities across both categories
				progress_percent = (float(total_completed) / float(total_possible)) * 100.0
				completed = total_completed >= total_possible
				print("ModuleScene: ReadAloud overall - Stories:", stories_completed, ", Guided:", guided_completed, ", Total:", total_completed, "/", total_possible, ", Overall:", int(progress_percent), "%")
			elif module_key == "chunked_reading":
				# Overall chunked reading progress based on vocabulary and comprehension activities
				var vocabulary_completed = 0
				var question_completed = 0
				
				# Check vocabulary building progress
				if fm.has("vocabulary_building") and typeof(fm["vocabulary_building"]) == TYPE_DICTIONARY:
					var vocab_data = fm["vocabulary_building"].get("vocabulary_words_completed", [])
					vocabulary_completed = vocab_data.size()
				
				# Check chunked question progress
				if fm.has("chunked_question") and typeof(fm["chunked_question"]) == TYPE_DICTIONARY:
					var question_data = fm["chunked_question"].get("activities_completed", [])
					question_completed = question_data.size()
				
				var total_completed = vocabulary_completed + question_completed
				var total_possible = 12 # Total activities across both categories
				progress_percent = (float(total_completed) / float(total_possible)) * 100.0
				completed = total_completed >= total_possible
				print("ModuleScene: ChunkedReading overall - Vocabulary:", vocabulary_completed, ", Questions:", question_completed, ", Total:", total_completed, "/", total_possible, ", Overall:", int(progress_percent), "%")
			elif module_key == "syllable_building":
				# Overall syllable building progress combining all syllable types
				var basic_completed = 0
				var advanced_completed = 0
				
				# Check basic syllables
				if fm.has("basic_syllables") and typeof(fm["basic_syllables"]) == TYPE_DICTIONARY:
					var basic_activities = fm["basic_syllables"].get("activities_completed", [])
					basic_completed = basic_activities.size()
				
				# Check advanced syllables
				if fm.has("advanced_syllables") and typeof(fm["advanced_syllables"]) == TYPE_DICTIONARY:
					var advanced_activities = fm["advanced_syllables"].get("activities_completed", [])
					advanced_completed = advanced_activities.size()
				
				var total_activities = 25 # Total syllable activities across both basic and advanced
				var total_completed = basic_completed + advanced_completed
				progress_percent = (float(total_completed) / float(total_activities)) * 100.0
				completed = total_completed >= total_activities
				print("ModuleScene: Syllable Building overall - Basic:", basic_completed, ", Advanced:", advanced_completed, ", Total:", total_completed, "/", total_activities, ", Overall:", int(progress_percent), "%")
			else:
				# For other modules, use direct progress value
				progress_percent = float(fm.get("progress", 0))
				completed = bool(fm.get("completed", false))
	elif user_progress_data.has(module_key) and module_data.has(module_key):
		# Fallback to local data
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
		if completed or int(progress_percent) >= 100:
			action_button.text = "COMPLETED"
		elif progress_percent > 0:
			action_button.text = "Continue"

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
