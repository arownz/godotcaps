extends Control

var tts: TextToSpeech = null
var whiteboard_instance: Control = null
var notification_popup: CanvasLayer = null
var completion_celebration: CanvasLayer = null

var current_target: String = "A"
var letter_set := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
var letter_index := 0
var session_completed_letters: Array = [] # Fallback local tracking when Firebase/module_progress unavailable
var fade_trace_on_success := true
var letter_focus_mode := false # Dims non-essential UI for reduced visual load
var recent_errors: Array = [] # Track recently missed letters for adaptive revisit

func _speak_text_simple(text: String):
	"""Simple TTS without captions"""
	if tts:
		tts.speak(text)

func _ready():
	print("PhonicsLetters: Letters practice loaded")
	
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
	
	# Update initial display
	_update_target_display()
	
	# Load whiteboard
	_load_whiteboard()
	
	# Load progress
	call_deferred("_load_progress")

# Call this function from the Godot editor Remote Inspector
# Or add a button temporarily to call it during gameplay
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12: # Press F12 to run test
			print("PhonicsLetters: F12 pressed - testing Firebase with ProfilePopUp pattern")
			_init_module_progress()

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	print("PhonicsLetters: TTS initialized")

func _init_module_progress():
	# Use same Firebase pattern as authentication.gd (which works)
	print("PhonicsLetters: Initializing Firebase access")
	
	# Wait for Firebase to be ready (like authentication.gd does)
	await get_tree().process_frame
	
	# Check Firebase availability using authentication.gd pattern (no Engine.has_singleton check)
	if not Firebase or not Firebase.Auth:
		print("PhonicsLetters: Firebase or Firebase.Auth not available")
		return
	
	# Check authentication status (exact authentication.gd pattern)
	if Firebase.Auth.auth == null:
		print("PhonicsLetters: No authenticated user")
		return
	
	if not Firebase.Auth.auth.localid:
		print("PhonicsLetters: No localid available")
		return
	
	print("PhonicsLetters: Firebase authenticated successfully for user: ", Firebase.Auth.auth.localid)
	
	# Test Firestore access (exact authentication.gd pattern)
	if Firebase.Firestore == null:
		print("PhonicsLetters: ERROR - Firestore is null")
		return
	
	print("PhonicsLetters: Firestore available - ready for progress updates")

func _connect_hover_events():
	var back_btn = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton
	if back_btn and not back_btn.mouse_entered.is_connected(_on_button_hover):
		back_btn.mouse_entered.connect(_on_button_hover)
	
	# Connect guide button
	var guide_btn = $MainContainer/ContentContainer/InstructionPanel/GuideButton
	if guide_btn:
		if not guide_btn.mouse_entered.is_connected(_on_button_hover):
			guide_btn.mouse_entered.connect(_on_button_hover)
		if not guide_btn.pressed.is_connected(_on_guide_button_pressed):
			guide_btn.pressed.connect(_on_guide_button_pressed)
	
	# Connect TTS settings button
	var tts_btn = $MainContainer/ContentContainer/InstructionPanel/TTSSettingButton
	if tts_btn:
		if not tts_btn.mouse_entered.is_connected(_on_button_hover):
			tts_btn.mouse_entered.connect(_on_button_hover)
		if not tts_btn.pressed.is_connected(_on_tts_setting_button_pressed):
			tts_btn.pressed.connect(_on_tts_setting_button_pressed)
	
	# Connect Previous button
	var previous_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton
	if previous_btn:
		if not previous_btn.mouse_entered.is_connected(_on_button_hover):
			previous_btn.mouse_entered.connect(_on_button_hover)
		if not previous_btn.pressed.is_connected(_on_previous_button_pressed):
			previous_btn.pressed.connect(_on_previous_button_pressed)
	
	# Connect Next button
	var next_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	if next_btn:
		if not next_btn.mouse_entered.is_connected(_on_button_hover):
			next_btn.mouse_entered.connect(_on_button_hover)
		if not next_btn.pressed.is_connected(_on_NextButton_pressed):
			next_btn.pressed.connect(_on_NextButton_pressed)

func _update_target_display():
	var target_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
	if target_label:
		target_label.text = "Trace: " + current_target
	
	# Update trace overlay
	var trace_overlay = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay:
		trace_overlay.text = current_target
	
	# Update button visibility
	_update_button_visibility()

	# Reset trace overlay opacity when showing new target (unless already completed)
	var trace_overlay_node = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay_node:
		# Check if current letter is completed and adjust opacity
		if current_target in session_completed_letters:
			trace_overlay_node.modulate.a = 0.3 # Semi-transparent for completed
		else:
			trace_overlay_node.modulate.a = 1.0 # Full opacity for uncompleted

func _update_button_visibility():
	var previous_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton
	var next_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	
	if previous_btn:
		previous_btn.visible = (letter_index > 0)
	if next_btn:
		next_btn.visible = (letter_index < letter_set.size() - 1)

func _load_whiteboard():
	var whiteboard_interface = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/WhiteboardInterface
	if whiteboard_interface:
		# Connect signals
		if whiteboard_interface.has_signal("drawing_submitted"):
			whiteboard_interface.connect("drawing_submitted", Callable(self, "_on_whiteboard_result"))
		if whiteboard_interface.has_signal("drawing_cancelled"):
			whiteboard_interface.connect("drawing_cancelled", Callable(self, "_on_whiteboard_cancelled"))
		whiteboard_instance = whiteboard_interface
	else:
		print("PhonicsLetters: WhiteboardInterface not found")

func _load_progress():
	if not Firebase.Auth.auth:
		print("PhonicsLetters: Firebase not available or not authenticated")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Use working authentication.gd pattern: direct document fetch
	print("PhonicsLetters: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("PhonicsLetters: Document fetched successfully")
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY and modules.has("phonics"):
			var phonics = modules["phonics"]
			if typeof(phonics) == TYPE_DICTIONARY:
				var letters_completed = phonics.get("letters_completed", [])
				# Update session tracking
				session_completed_letters = letters_completed.duplicate()
				# Update UI with loaded progress
				var completed_count = letters_completed.size()
				var total_letters = letter_set.size()
				var letters_percent = (float(completed_count) / float(total_letters)) * 100.0
				_update_progress_ui(letters_percent)
				# Update trace overlay for current letter if completed
				_update_completed_letters_display(letters_completed)
				print("PhonicsLetters: Loaded progress - ", completed_count, "/", total_letters, " letters completed")
				
				# Find first uncompleted letter
				for i in range(letter_set.size()):
					var letter = letter_set[i]
					if not letters_completed.has(letter):
						letter_index = i
						current_target = letter
						print("PhonicsLetters: Starting from uncompleted letter: ", letter)
						break
				
				# Update display with loaded position
				_update_target_display()
			else:
				print("PhonicsLetters: Phonics module data is not a dictionary")
		else:
			print("PhonicsLetters: No modules or phonics data found")
	else:
		print("PhonicsLetters: Failed to fetch document or document has error")

func _update_progress_ui(_percent: float):
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	
	# Calculate letters-specific progress
	var completed_count = session_completed_letters.size()
	var total_letters = letter_set.size()
	var letters_percent = (completed_count / float(total_letters)) * 100.0
	
	if progress_label:
		progress_label.text = str(completed_count) + "/" + str(total_letters) + " Letters"
	if progress_bar:
		progress_bar.value = letters_percent
		print("PhonicsLetters: Progress updated to ", letters_percent, "% (", completed_count, "/", total_letters, ")")
		progress_bar.value = letters_percent

func _update_completed_letters_display(completed_letters: Array):
	"""Update trace overlay opacity to show completed letters as transparent"""
	var trace_overlay = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay and completed_letters.has(current_target):
		# Make completed letters semi-transparent but still visible
		trace_overlay.modulate.a = 0.3
		print("PhonicsLetters: Letter ", current_target, " already completed - showing as transparent")

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("PhonicsLetters: Returning to phonics categories")
	_fade_out_and_change_scene("res://Scenes/PhonicsModule.tscn")

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
		print("PhonicsLetters: TTS stopped before scene change")

# Ensure TTS cleanup on scene exit
func _exit_tree():
	_stop_tts()

func _on_HearButton_pressed():
	$ButtonClick.play()
	if tts:
		# Enhanced TTS guide with instructions
		var guide_text = "Listen carefully: Letter " + current_target + ". Now trace this letter on the whiteboard. " + current_target + " sounds like " + _get_letter_sound(current_target) + "."
		_speak_text_simple(guide_text)

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Letters Practice! Here you will learn to trace letters from A to Z. Look at the letter shown above, then use your finger or mouse to trace it carefully on the whiteboard below. Listen to the letter sound by pressing 'Hear Letter', and when you're ready to move on, press 'Next'."
		_speak_text_simple(guide_text)

func _on_tts_setting_button_pressed():
	$ButtonClick.play()
	print("PhonicsLetters: Looking for TTSSettingsPopup (robust lookup)...")
	var tts_popup = get_node_or_null("TTSSettingsPopup")
	if not tts_popup:
		tts_popup = find_child("TTSSettingsPopup", true, false)
	if not tts_popup:
		print("PhonicsLetters: TTSSettingsPopup not found - instantiating dynamically")
		var popup_scene: PackedScene = load("res://Scenes/TTSSettingsPopup.tscn")
		if popup_scene:
			tts_popup = popup_scene.instantiate()
			tts_popup.name = "TTSSettingsPopup"
			add_child(tts_popup)
	print("PhonicsLetters: TTSSettingsPopup final status:", tts_popup != null)
	if tts_popup:
		# Setup popup with current settings
		var current_voice = SettingsManager.get_setting("accessibility", "tts_voice_id")
		var current_rate = SettingsManager.get_setting("accessibility", "tts_rate")
		
		# Provide safe defaults
		if current_voice == null or current_voice == "":
			current_voice = "default"
		if current_rate == null:
			current_rate = 1.0
		
		# Pass current TTS instance to popup for voice testing
		if tts_popup.has_method("set_tts_instance"):
			tts_popup.set_tts_instance(tts)
		
		if tts_popup.has_method("setup"):
			tts_popup.setup(tts, current_voice, current_rate, "Testing Text to Speech")
		
		# Connect to save signal if not already connected
		if not tts_popup.settings_saved.is_connected(_on_tts_settings_saved):
			tts_popup.settings_saved.connect(_on_tts_settings_saved)
		
		tts_popup.visible = true
		print("PhonicsLetters: TTS Settings popup opened")
	else:
		print("PhonicsLetters: Warning - TTSSettingsPopup still not found after dynamic attempt")

# Helper function to provide letter sound guidance
func _get_letter_sound(letter: String) -> String:
	var sounds = {
		"A": "ah", "B": "buh", "C": "kuh", "D": "duh", "E": "eh",
		"F": "fuh", "G": "guh", "H": "huh", "I": "ih", "J": "juh",
		"K": "kuh", "L": "luh", "M": "muh", "N": "nuh", "O": "oh",
		"P": "puh", "Q": "kwuh", "R": "ruh", "S": "sss", "T": "tuh",
		"U": "uh", "V": "vuh", "W": "wuh", "X": "ks", "Y": "yuh", "Z": "zzz"
	}
	return sounds.get(letter, letter.to_lower())

func _on_NextButton_pressed():
	$ButtonClick.play()
	_advance_target()

func _on_previous_button_pressed():
	$ButtonClick.play()
	_previous_target()

func _advance_target():
	letter_index = (letter_index + 1) % letter_set.size()
	current_target = letter_set[letter_index]
	_update_target_display()
	
	# Clear whiteboard for next target
	if whiteboard_instance and whiteboard_instance.has_method("_on_clear_button_pressed"):
		whiteboard_instance._on_clear_button_pressed()
	
	# Re-enable whiteboard buttons after clearing
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

func _previous_target():
	letter_index = (letter_index - 1 + letter_set.size()) % letter_set.size()
	current_target = letter_set[letter_index]
	_update_target_display()
	
	# Clear whiteboard for previous target
	if whiteboard_instance and whiteboard_instance.has_method("_on_clear_button_pressed"):
		whiteboard_instance._on_clear_button_pressed()
	
	# Re-enable whiteboard buttons after clearing
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

func _on_whiteboard_result(text_result: String):
	print("PhonicsLetters: Whiteboard result -> ", text_result)
	
	# Enhanced recognition with dyslexia-friendly matching
	var recognized_text = text_result.strip_edges().to_upper()
	var target_letter = current_target.to_upper()
	
	# Check if recognition matches current target letter
	var is_correct = false
	if recognized_text == target_letter:
		is_correct = true
	# Also accept close matches (dyslexia-friendly fuzzy matching)
	elif recognized_text.length() == 1 and target_letter.length() == 1:
		# Allow common letter confusions for dyslexic users
		var letter_confusions = {
			"B": ["D", "P"],
			"D": ["B", "P"],
			"P": ["B", "D"],
			"Q": ["G", "O"],
			"G": ["Q", "O"],
			"O": ["Q", "G"],
			"M": ["W", "N"],
			"W": ["M", "N"],
			"N": ["M", "W"]
		}
		
		if letter_confusions.has(target_letter) and letter_confusions[target_letter].has(recognized_text):
			is_correct = true # Accept common reversals/confusions
	
	if is_correct:
		print("PhonicsLetters: Correct letter recognized - ", target_letter)
		# Fade out trace overlay gradually to promote independence
		if fade_trace_on_success:
			var trace_overlay_node2 = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
			if trace_overlay_node2:
				var tween = create_tween()
				tween.tween_property(trace_overlay_node2, "modulate:a", 0.15, 0.6)
		# Track locally for this session
		if not session_completed_letters.has(target_letter):
			session_completed_letters.append(target_letter)
		
		var progress_data: Dictionary = {"letters_completed": session_completed_letters, "percentage": float(session_completed_letters.size()) / 26.0 * 100.0}
		
		# Try to persist progress using direct Firebase update (authentication.gd pattern)
		if Firebase.Auth.auth:
			var save_success = await _save_letter_completion_to_firebase(target_letter)
			if save_success:
				print("PhonicsLetters: Firebase update successful")
				# Reload progress to get updated percentage
				await _load_progress()
			else:
				print("PhonicsLetters: Firebase update failed, using session progress fallback")
		else:
			print("PhonicsLetters: Firebase not available, using local session progress")
		
		_show_completion_celebration(target_letter, progress_data)
	elif not text_result.begins_with("recognition_error"):
		print("PhonicsLetters: Letter not recognized correctly. Expected: ", target_letter, ", Got: ", recognized_text)
		_show_encouragement_message(recognized_text, target_letter)
		if not recent_errors.has(target_letter):
			recent_errors.append(target_letter)
			if recent_errors.size() > 5:
				recent_errors.pop_front()

func _on_whiteboard_cancelled():
	print("PhonicsLetters: Whiteboard cancelled")

func _show_completion_celebration(letter: String, progress_data: Dictionary):
	"""Show completion celebration popup for dyslexic users"""
	print("PhonicsLetters: Showing completion celebration for letter: ", letter)
	
	# Load and instantiate completion celebration if not already done
	if not completion_celebration:
		var celebration_scene = load("res://Scenes/CompletionCelebration.tscn")
		if celebration_scene:
			completion_celebration = celebration_scene.instantiate()
			add_child(completion_celebration)
			
			# Connect signals
			if completion_celebration.has_signal("try_again_pressed"):
				completion_celebration.connect("try_again_pressed", Callable(self, "_on_celebration_try_again"))
			if completion_celebration.has_signal("next_item_pressed"):
				completion_celebration.connect("next_item_pressed", Callable(self, "_on_celebration_next"))
			if completion_celebration.has_signal("closed"):
				completion_celebration.connect("closed", Callable(self, "_on_celebration_closed"))
		else:
			print("PhonicsLetters: Failed to load CompletionCelebration scene")
			return
	
	# Show celebration with letter completion type
	if completion_celebration and completion_celebration.has_method("show_completion"):
		completion_celebration.show_completion(0, letter, progress_data, "phonics") # 0 = CompletionType.LETTER, "phonics" = module_key

func _show_encouragement_message(recognized: String, expected: String):
	"""Show encouraging message when letter isn't quite right"""
	if not notification_popup:
		var popup_scene = load("res://Scenes/NotificationPopUp.tscn")
		if popup_scene:
			notification_popup = popup_scene.instantiate()
			add_child(notification_popup)
	
	# Disconnect any existing connections and connect for encouragement
	if notification_popup.has_signal("button_pressed"):
		# Disconnect all existing connections
		var connections = notification_popup.get_signal_connection_list("button_pressed")
		for connection in connections:
			notification_popup.disconnect("button_pressed", connection["callable"])
		# Connect encouragement handler
		notification_popup.connect("button_pressed", Callable(self, "_on_encouragement_continue"))
	
	if notification_popup and notification_popup.has_method("show_notification"):
		var message = "Great try! I see you wrote '" + recognized + "'.\n\nLet's practice the letter '" + expected + "' again.\nTrace it carefully."
		notification_popup.show_notification("Keep Practicing!", message, "Again")

func _on_encouragement_continue():
	print("PhonicsLetters: Encouragement popup button pressed - stay on current letter for more practice")
	# Ensure whiteboard is ready for another attempt
	if whiteboard_instance:
		if whiteboard_instance.has_method("_on_clear_button_pressed"):
			whiteboard_instance._on_clear_button_pressed()
		if whiteboard_instance.has_method("_re_enable_buttons"):
			whiteboard_instance._re_enable_buttons()

func _on_celebration_try_again():
	"""Handle try again button from celebration popup"""
	print("PhonicsLetters: User chose to try again")
	# Stay on current letter for more practice
	if whiteboard_instance and whiteboard_instance.has_method("reset_for_retry"):
		whiteboard_instance.reset_for_retry()
		print("PhonicsLetters: Whiteboard reset after Try Again")
	
	# Ensure buttons are enabled after celebration popup closes
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

func _on_celebration_next():
	"""Handle next button from celebration popup"""
	print("PhonicsLetters: User chose to move to next letter")
	# Adaptive: if user struggled with a recent letter, occasionally revisit it before moving on
	if recent_errors.size() > 0 and randi() % 4 == 0:
		var revisit = recent_errors[randi() % recent_errors.size()]
		letter_index = letter_set.find(revisit)
		current_target = revisit
		_update_target_display()
		print("PhonicsLetters: Adaptive revisit of letter ", revisit)
	else:
		_advance_target()

func _on_celebration_closed():
	"""Handle celebration popup closed"""
	print("PhonicsLetters: Celebration popup closed")
	# Also ensure whiteboard is ready if user dismissed popup
	if whiteboard_instance and whiteboard_instance.has_method("reset_for_retry"):
		whiteboard_instance.reset_for_retry()
	
	# Ensure buttons are enabled after celebration popup closes
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

# Direct Firebase letter completion update using working Journey Mode pattern
func _save_letter_completion_to_firebase(letter: String) -> bool:
	"""Save letter completion to Firebase using EXACT ProfilePopUp.gd pattern"""
	print("PhonicsLetters: _save_letter_completion_to_firebase called with letter: ", letter)
	
	# Check authentication using EXACT ProfilePopUp pattern
	if Firebase.Auth.auth == null:
		print("PhonicsLetters: No authenticated user, using local session progress")
		_save_letter_locally(letter)
		return false
	
	var user_id = Firebase.Auth.auth.localid
	print("PhonicsLetters: Loading data for user ID: ", user_id)
	
	# Check Firestore using EXACT ProfilePopUp pattern
	if Firebase.Firestore == null:
		print("PhonicsLetters: ERROR - Firestore is null, using local session progress")
		_save_letter_locally(letter)
		return false
	
	# Use EXACT ProfilePopUp collection pattern
	var collection = Firebase.Firestore.collection("dyslexia_users")
	print("PhonicsLetters: Attempting to fetch document with ID: ", user_id)
	
	# Use EXACT ProfilePopUp await pattern
	var document = await collection.get_doc(user_id)
	
	# Use EXACT ProfilePopUp error checking pattern
	if document != null:
		print("PhonicsLetters: Document received")
		
		# Check for errors using EXACT ProfilePopUp pattern
		var has_error = false
		var error_data = null
		
		if document.has_method("keys"):
			var doc_keys = document.keys()
			
			if "error" in doc_keys:
				error_data = document.get_value("error")
				if error_data:
					has_error = true
					print("PhonicsLetters: Error in document: ", error_data)
					_save_letter_locally(letter)
					return false
			
			if !has_error:
				# Process document using nested structure pattern from ProfilePopUp
				print("PhonicsLetters: Document retrieved successfully")
				
				# Get modules data (create if missing)
				var modules = document.get_value("modules")
				if modules == null or typeof(modules) != TYPE_DICTIONARY:
					print("PhonicsLetters: Creating modules structure")
					modules = {
						"phonics": {
							"completed": false,
							"progress": 0,
							"letters_completed": [],
							"sight_words_completed": []
						}
					}
				
				# Ensure phonics module exists
				if !modules.has("phonics"):
					print("PhonicsLetters: Creating phonics module")
					modules["phonics"] = {
						"completed": false,
						"progress": 0,
						"letters_completed": [],
						"sight_words_completed": []
					}
				
				var phonics_data = modules["phonics"]
				var letters_completed = phonics_data.get("letters_completed", [])
				var sight_words_completed = phonics_data.get("sight_words_completed", [])
				
				var letter_upper = letter.to_upper()
				print("PhonicsLetters: Current letters completed: ", letters_completed)
				
				if not letters_completed.has(letter_upper):
					print("PhonicsLetters: Adding new letter: ", letter_upper)
					letters_completed.append(letter_upper)
					phonics_data["letters_completed"] = letters_completed
					
					# Calculate progress (26 letters + 20 sight words = 46 total)
					var total_letters = letters_completed.size()
					var total_sight_words = sight_words_completed.size()
					var total_completed = total_letters + total_sight_words
					var progress_percent = int((float(total_completed) / 46.0) * 100.0)
					
					print("PhonicsLetters: Total letters: ", total_letters, ", Total sight words: ", total_sight_words)
					print("PhonicsLetters: Calculated progress: ", progress_percent, "%")
					
					phonics_data["progress"] = progress_percent
					phonics_data["completed"] = progress_percent >= 100
					modules["phonics"] = phonics_data
					
					# Update document using EXACT ProfilePopUp pattern
					document.add_or_update_field("modules", modules)
					
					# Save using EXACT ProfilePopUp pattern
					print("PhonicsLetters: About to update document with modules: ", modules)
					var updated_document = await collection.update(document)
					
					if updated_document:
						print("PhonicsLetters: ✓ Letter ", letter_upper, " saved to Firebase. Progress: ", progress_percent, "%")
						return true
					else:
						print("PhonicsLetters: ✗ Failed to update Firebase document")
						_save_letter_locally(letter)
						return false
				else:
					print("PhonicsLetters: Letter ", letter_upper, " already completed")
					return true
			else:
				print("PhonicsLetters: Document has no keys method")
				_save_letter_locally(letter)
				return false
	else:
		print("PhonicsLetters: Failed to get document for letter completion update")
		_save_letter_locally(letter)
		return false
	
	# Fallback return (should never be reached)
	_save_letter_locally(letter)
	return false

func _save_letter_locally(letter: String):
	"""Fallback to save letter completion locally when Firebase is unavailable"""
	var letter_upper = letter.to_upper()
	if letter_upper not in session_completed_letters:
		session_completed_letters.append(letter_upper)
		print("PhonicsLetters: Letter ", letter_upper, " saved locally (session only)")
		
		# Calculate local progress for display
		var progress_percent = (session_completed_letters.size() / 26.0) * 100.0
		_update_progress_ui(progress_percent)

func _toggle_focus_mode():
	letter_focus_mode = !letter_focus_mode
	var dim_targets = [
		$MainContainer/ContentContainer/InstructionPanel,
		$MainContainer/HeaderPanel
	]
	for node in dim_targets:
		if node:
			var tween = create_tween()
			var target_alpha = 0.35 if letter_focus_mode else 1.0
			tween.tween_property(node, "modulate:a", target_alpha, 0.4)
	print("PhonicsLetters: Focus mode = ", letter_focus_mode)

func _on_tts_settings_saved(voice_id: String, rate: float):
	"""Handle TTS settings save to update local TTS instance"""
	print("PhonicsLetters: Saving TTS preferences - Voice: ", voice_id, " Rate: ", rate)
	
	# Update current TTS instance
	if tts:
		if voice_id != null and voice_id != "":
			tts.set_voice(voice_id)
		if rate != null:
			tts.set_rate(rate)
	
	# Store in SettingsManager for persistence
	SettingsManager.set_setting("accessibility", "tts_voice_id", voice_id)
	SettingsManager.set_setting("accessibility", "tts_rate", rate)
