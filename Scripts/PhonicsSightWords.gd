extends Control

var tts: TextToSpeech = null
var whiteboard_instance: Control = null
var notification_popup: CanvasLayer = null
var completion_celebration: CanvasLayer = null
var module_progress = null # ModuleProgress.gd instance for centralized Firebase operations

var current_target: String = "the"
var sight_words := ["the", "and", "to", "a", "of", "in", "is", "you", "that", "it", "he", "was", "for", "on", "are", "as", "with", "his", "they", "I"]
var word_index := 0
var session_completed_words: Array = [] # Fallback local tracking when Firebase/module_progress unavailable
var fade_trace_on_success := true
var sight_focus_mode := false
var recent_word_errors: Array = []

func _speak_text_simple(text: String):
	"""Simple TTS without captions"""
	if tts:
		tts.speak(text)

func _ready():
	print("PhonicsSightWords: Sight words practice loaded")
	
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
		print("PhonicsSightWords: ModuleProgress initialized")
	else:
		print("PhonicsSightWords: Firebase not available, using local tracking")

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when returning to the scene
		if module_progress:
			call_deferred("_load_progress")

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
	
	# Reset overlay opacity but check if current word is completed
	var trace_overlay_node = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay_node:
		# Check if current word is completed and adjust opacity
		if current_target.to_lower() in session_completed_words:
			trace_overlay_node.modulate.a = 0.3 # Semi-transparent for completed
		else:
			trace_overlay_node.modulate.a = 1.0 # Full opacity for uncompleted

func _update_button_visibility():
	var previous_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton
	var next_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	
	if previous_btn:
		previous_btn.visible = (word_index > 0)
	if next_btn:
		next_btn.visible = (word_index < sight_words.size() - 1)

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
		print("PhonicsSightWords: WhiteboardInterface not found")

func _load_progress():
	if module_progress and module_progress.is_authenticated():
		print("PhonicsSightWords: Loading phonics progress via ModuleProgress")
		var phonics_progress = await module_progress.get_phonics_progress()
		if phonics_progress:
			var words_completed = phonics_progress.get("sight_words_completed", [])
			var progress_percent = phonics_progress.get("progress", 0)
			var saved_index = phonics_progress.get("current_sight_word_index", 0)
			
			# Update session tracking
			session_completed_words = words_completed.duplicate()
			
			# Resume at saved position OR find first uncompleted word
			var resume_index = saved_index
			
			# Validate saved index is within bounds
			if saved_index >= sight_words.size():
				resume_index = sight_words.size() - 1
			
			# If saved position word is already completed, find next uncompleted
			var saved_word = sight_words[resume_index].to_lower()
			if words_completed.has(saved_word):
				print("PhonicsSightWords: Saved word '", saved_word, "' already completed, finding next uncompleted")
				for i in range(sight_words.size()):
					var word = sight_words[i].to_lower()
					if not words_completed.has(word):
						resume_index = i
						break
					elif i == sight_words.size() - 1: # All words completed
						resume_index = sight_words.size() - 1
			
			# Update current position
			word_index = resume_index
			current_target = sight_words[word_index]
			print("PhonicsSightWords: Resuming at sight word: ", current_target, " (index: ", word_index, ", saved index was: ", saved_index, ")")
			
			# Update UI with loaded progress and current position
			_update_progress_ui(progress_percent)
			_update_target_display()
			
			# Update trace overlay for current word if completed
			_update_completed_words_display(words_completed)
			
			print("PhonicsSightWords: Loaded progress - ", words_completed.size(), "/20 words completed (", progress_percent, "%)")
		else:
			print("PhonicsSightWords: No phonics progress found")
	else:
		print("PhonicsSightWords: ModuleProgress not available, using local session progress")

func _update_progress_ui(_percent: float):
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	
	# Calculate sight words-specific progress
	var completed_count = session_completed_words.size()
	var total_words = sight_words.size()
	var words_percent = (completed_count / float(total_words)) * 100.0
	
	if progress_label:
		progress_label.text = str(completed_count) + "/" + str(total_words) + " Words"
	if progress_bar:
		progress_bar.value = words_percent

func _update_completed_words_display(completed_words: Array):
	"""Update trace overlay opacity to show completed words as transparent"""
	var trace_overlay = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay and completed_words.has(current_target.to_lower()):
		# Make completed words semi-transparent but still visible
		trace_overlay.modulate.a = 0.3
		print("PhonicsSightWords: Word ", current_target, " already completed - showing as transparent")

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("PhonicsSightWords: Returning to phonics categories")
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
		print("PhonicsSightWords: TTS stopped before scene change")

# Ensure TTS cleanup on scene exit
func _exit_tree():
	_stop_tts()

func _on_HearButton_pressed():
	$ButtonClick.play()
	if tts:
		# Enhanced TTS guide with instructions for sight words
		var guide_text = "Listen and repeat: " + current_target + ". This is a sight word. " + current_target + ". Now write it on the whiteboard: " + _spell_out_word(current_target) + "."
		_speak_text_simple(guide_text)

# Helper function to spell out words letter by letter for guidance
func _spell_out_word(word: String) -> String:
	var spelled = ""
	for i in range(word.length()):
		spelled += word[i].to_upper()
		if i < word.length() - 1:
			spelled += " - "
	return spelled

func _on_NextButton_pressed():
	$ButtonClick.play()
	_advance_target()

func _on_previous_button_pressed():
	$ButtonClick.play()
	_previous_target()

func _on_sight_word_done_button_pressed():
	"""Mark current sight word as completed and advance"""
	$ButtonClick.play()
	
	# Mark current sight word as completed using ModuleProgress
	if module_progress and module_progress.is_authenticated():
		var success = await module_progress.set_sight_word_completed(current_target)
		if success:
			print("PhonicsSightWords: Sight word ", current_target, " marked as completed in Firebase")
			if not session_completed_words.has(current_target):
				session_completed_words.append(current_target)
			
			# Show completion celebration like the whiteboard result does
			var progress_data: Dictionary = {"sight_words_completed": session_completed_words, "percentage": float(session_completed_words.size()) / 20.0 * 100.0}
			_show_completion_celebration(current_target, progress_data)
		else:
			print("PhonicsSightWords: Failed to save sight word completion to Firebase")
	else:
		print("PhonicsSightWords: ModuleProgress not available, using local session tracking")
		if not session_completed_words.has(current_target):
			session_completed_words.append(current_target)
		var progress_data: Dictionary = {"sight_words_completed": session_completed_words, "percentage": float(session_completed_words.size()) / 20.0 * 100.0}
		_show_completion_celebration(current_target, progress_data)

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Sight Words Practice! Sight words are common words you'll see often when reading. Look at the word shown above - these are words like 'the', 'and', 'to' that you should recognize quickly. Practice writing each word on the whiteboard below. Press 'Hear' to listen to the word and how to spell it, then trace or write it carefully. When ready, press 'Next' to continue!"
		_speak_text_simple(guide_text)

func _on_tts_setting_button_pressed():
	"""TTS Settings button - Open settings as popup overlay"""
	$ButtonClick.play()
	print("PhonicsSightWords: Settings button pressed")
	
	# Open settings as popup instead of changing scene
	var settings_popup_scene = load("res://Scenes/SettingScene.tscn")
	if settings_popup_scene:
		var popup = settings_popup_scene.instantiate()
		add_child(popup)
		if popup.has_method("set_context"):
			popup.set_context(false) # normal settings; hide battle buttons

func _on_tts_settings_saved(voice_id: String, rate: float):
	"""Handle TTS settings save to update local TTS instance"""
	print("PhonicsSightWords: Saving TTS preferences - Voice: ", voice_id, " Rate: ", rate)
	
	# Update current TTS instance
	if tts:
		if voice_id != null and voice_id != "":
			tts.set_voice(voice_id)
		if rate != null:
			tts.set_rate(rate)
	
	# Store in SettingsManager for persistence
	SettingsManager.set_setting("accessibility", "tts_voice_id", voice_id)
	SettingsManager.set_setting("accessibility", "tts_rate", rate)

func _advance_target():
	word_index = (word_index + 1) % sight_words.size()
	current_target = sight_words[word_index]
	_update_target_display()
	
	# Clear whiteboard for next target
	if whiteboard_instance and whiteboard_instance.has_method("_on_clear_button_pressed"):
		whiteboard_instance._on_clear_button_pressed()
	
	# Re-enable whiteboard buttons after clearing
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

func _previous_target():
	word_index = (word_index - 1 + sight_words.size()) % sight_words.size()
	current_target = sight_words[word_index]
	_update_target_display()
	
	# Clear whiteboard for previous target
	if whiteboard_instance and whiteboard_instance.has_method("_on_clear_button_pressed"):
		whiteboard_instance._on_clear_button_pressed()
	
	# Re-enable whiteboard buttons after clearing
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

func _on_whiteboard_result(text_result: String):
	print("PhonicsSightWords: Whiteboard result -> ", text_result)
	
	# Enhanced recognition with OCR correction and dyslexia-friendly matching
	var recognized_text = text_result.strip_edges().to_lower()
	var target_word = current_target.to_lower()
	
	# Apply OCR correction for common letter/digit confusions in sight words
	recognized_text = _apply_sight_word_ocr_correction(recognized_text, target_word)
	print("PhonicsSightWords: After OCR correction -> ", recognized_text)
	
	# Check if recognition matches current target word
	var is_correct = false
	var confidence_score = 0.0
	
	# Direct match gets highest confidence
	if recognized_text == target_word:
		is_correct = true
		confidence_score = 1.0
	# Also accept close matches (dyslexia-friendly fuzzy matching)
	else:
		confidence_score = _calculate_word_similarity(recognized_text, target_word)
		is_correct = confidence_score >= 0.7 # Accept close matches for dyslexic users
	
	print("PhonicsSightWords: Confidence score: ", confidence_score, " | Is correct: ", is_correct)
	
	if is_correct:
		print("PhonicsSightWords: Correct sight word recognized - ", target_word)
		if fade_trace_on_success:
			var trace_overlay_node2 = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
			if trace_overlay_node2:
				var tween = create_tween()
				tween.tween_property(trace_overlay_node2, "modulate:a", 0.15, 0.6)
		# Track locally in session
		if not session_completed_words.has(target_word):
			session_completed_words.append(target_word)
		
		var progress_data: Dictionary = {"sight_words_completed": session_completed_words, "percentage": float(session_completed_words.size()) / 20.0 * 100.0}
		
		# Save progress using ModuleProgress system
		if module_progress and module_progress.is_authenticated():
			var save_success = await module_progress.set_sight_word_completed(target_word)
			if save_success:
				print("PhonicsSightWords: Progress saved successfully via ModuleProgress")
				# Reload progress to get updated percentage
				await _load_progress()
			else:
				print("PhonicsSightWords: Failed to save progress, using session progress fallback")
		else:
			print("PhonicsSightWords: ModuleProgress not available, using session progress fallback")
		
		_show_completion_celebration(target_word, progress_data)
	elif not text_result.begins_with("recognition_error"):
		print("PhonicsSightWords: Sight word not recognized correctly. Expected: ", target_word, ", Got: ", recognized_text)
		_show_encouragement_message(recognized_text, target_word)
		if not recent_word_errors.has(target_word):
			recent_word_errors.append(target_word)
			if recent_word_errors.size() > 5:
				recent_word_errors.pop_front()

func _on_whiteboard_cancelled():
	print("PhonicsSightWords: Whiteboard cancelled")

func _calculate_word_similarity(word1: String, word2: String) -> float:
	"""Calculate similarity between two words using edit distance for dyslexia-friendly matching"""
	if word1 == word2:
		return 1.0
	
	var len1 = word1.length()
	var len2 = word2.length()
	
	if len1 == 0 or len2 == 0:
		return 0.0
	
	# Simple similarity based on common characters and length difference
	var common_chars = 0
	var word1_chars = {}
	var word2_chars = {}
	
	# Count character frequencies
	for i in range(len1):
		var character = word1[i]
		word1_chars[character] = word1_chars.get(character, 0) + 1
	
	for i in range(len2):
		var character = word2[i]
		word2_chars[character] = word2_chars.get(character, 0) + 1
	
	# Calculate common characters
	for character in word1_chars.keys():
		if word2_chars.has(character):
			common_chars += min(word1_chars[character], word2_chars[character])
	
	# Similarity score based on common characters and length penalty
	var max_len = max(len1, len2)
	var length_penalty = 1.0 - (abs(len1 - len2) / float(max_len))
	var char_similarity = float(common_chars) / float(max_len)
	
	return char_similarity * length_penalty

func _show_completion_celebration(word: String, progress_data: Dictionary):
	"""Show completion celebration popup for dyslexic users"""
	print("PhonicsSightWords: Showing completion celebration for sight word: ", word)
	
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
			print("PhonicsSightWords: Failed to load CompletionCelebration scene")
			return
	
	# Show celebration with sight word completion type
	if completion_celebration and completion_celebration.has_method("show_completion"):
		completion_celebration.show_completion(1, word, progress_data, "phonics") # 1 = CompletionType.SIGHT_WORD, "phonics" = module_key

func _show_encouragement_message(recognized: String, expected: String):
	"""Show encouraging message when sight word isn't quite right"""
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
		var message = "Good effort! I see you wrote '" + recognized + "'.\n\nLet's practice the sight word '" + expected + "' again.\nRemember, sight words are special words we see often in reading."
		notification_popup.show_notification("Keep Trying!", message, "Again")

func _on_encouragement_continue():
	print("PhonicsSightWords: Encouragement popup button pressed - remain on current word for more practice")

func _on_celebration_try_again():
	"""Handle try again button from celebration popup"""
	print("PhonicsSightWords: User chose to try again")
	# Stay on current word for more practice
	if whiteboard_instance and whiteboard_instance.has_method("reset_for_retry"):
		whiteboard_instance.reset_for_retry()
		print("PhonicsSightWords: Whiteboard reset after Try Again")
	
	# Ensure buttons are enabled after celebration popup closes
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

func _on_celebration_next():
	"""Handle next button from celebration popup"""
	print("PhonicsSightWords: User chose to move to next word")
	if recent_word_errors.size() > 0 and randi() % 4 == 0:
		var revisit = recent_word_errors[randi() % recent_word_errors.size()]
		word_index = sight_words.find(revisit)
		current_target = revisit
		_update_target_display()
		print("PhonicsSightWords: Adaptive revisit of word ", revisit)
	else:
		_advance_target()

func _on_celebration_closed():
	"""Handle celebration popup closed"""
	print("PhonicsSightWords: Celebration popup closed")
	# No automatic actions when popup is simply closed - wait for user input
	# Only "Try Again" and "Next" buttons should trigger specific actions

func _toggle_focus_mode():
	sight_focus_mode = !sight_focus_mode
	var dim_targets = [
		$MainContainer/ContentContainer/InstructionPanel,
		$MainContainer/HeaderPanel
	]
	for node in dim_targets:
		if node:
			var tween = create_tween()
			var target_alpha = 0.35 if sight_focus_mode else 1.0
			tween.tween_property(node, "modulate:a", target_alpha, 0.4)
	print("PhonicsSightWords: Focus mode = ", sight_focus_mode)

# OCR correction specifically for sight word recognition
func _apply_sight_word_ocr_correction(recognized: String, target: String) -> String:
	var corrected = recognized
	
	# Common OCR letter/digit confusions that affect sight words
	var digit_to_letter_map = {
		"0": "o",
		"1": "i",
		"5": "s",
		"6": "g",
		"2": "z",
		"8": "b"
	}
	
	# Apply character-by-character corrections
	var new_text = ""
	for i in range(corrected.length()):
		var character = corrected[i]
		if digit_to_letter_map.has(character):
			new_text += digit_to_letter_map[character]
		else:
			new_text += character
	corrected = new_text
	
	# Specific sight word OCR corrections based on common recognition errors
	var sight_word_corrections = {
		# Common "the" misrecognitions
		"1he": "the", "tne": "the", "tnr": "the", "th3": "the",
		# Common "and" misrecognitions  
		"anc": "and", "an6": "and", "ana": "and",
		# Common "to" misrecognitions
		"t0": "to", "1o": "to", "70": "to",
		# Common "a" misrecognitions
		"4": "a", "@": "a",
		# Common "of" misrecognitions
		"0f": "of", "ol": "of",
		# Common "in" misrecognitions
		"1n": "in", "ln": "in",
		# Common "is" misrecognitions
		"1s": "is", "ls": "is",
		# Common "it" misrecognitions
		"1t": "it", "lt": "it",
		# Common "I" misrecognitions  
		"1": "i", "l": "i"
	}
	
	# Apply sight word specific corrections
	if sight_word_corrections.has(corrected) and sight_word_corrections[corrected] == target:
		var original = corrected
		corrected = sight_word_corrections[corrected]
		print("PhonicsSightWords: Sight word OCR corrected ", original, " → ", corrected)
	
	return corrected
