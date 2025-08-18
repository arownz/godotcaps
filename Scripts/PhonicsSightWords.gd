extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null
var whiteboard_instance: Control = null
var notification_popup: CanvasLayer = null
var completion_celebration: CanvasLayer = null

var current_target: String = "the"
var sight_words := ["the", "and", "to", "a", "of", "in", "is", "you", "that", "it", "he", "was", "for", "on", "are", "as", "with", "his", "they", "I"]
var word_index := 0

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
	
	# Initialize notification popup
	_init_notification_popup()

func _init_notification_popup():
	notification_popup = $NotificationPopup
	if notification_popup:
		print("PhonicsSightWords: Notification popup initialized")
	else:
		print("PhonicsSightWords: Warning - NotificationPopup not found")

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	print("PhonicsSightWords: TTS initialized for manual guide button activation")

func _init_module_progress():
	if Engine.has_singleton("Firebase"):
		module_progress = ModuleProgress.new()
		add_child(module_progress)
	else:
		print("PhonicsSightWords: Firebase not available; progress won't sync")

func _connect_hover_events():
	var back_btn = $MainContainer/HeaderPanel/HeaderContainer/BackButton
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

func _update_target_display():
	var target_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
	if target_label:
		target_label.text = "Trace: " + current_target
	
	# Update trace overlay
	var trace_overlay = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay:
		trace_overlay.text = current_target

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
	if not module_progress:
		return
		
	var firebase_modules = await module_progress.fetch_modules()
	
	if firebase_modules.has("phonics_sight_words"):
		var fm = firebase_modules["phonics_sight_words"]
		if typeof(fm) == TYPE_DICTIONARY:
			var progress_percent = float(fm.get("progress", 0))
			_update_progress_ui(progress_percent)

func _update_progress_ui(percent: float):
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	
	if progress_label:
		progress_label.text = str(int(percent)) + "% Complete"
	if progress_bar:
		progress_bar.value = percent

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

func _on_NextTargetButton_pressed():
	$ButtonClick.play()
	_advance_target()

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Sight Words Practice! Sight words are common words you'll see often when reading. Look at the word shown above - these are words like 'the', 'and', 'to' that you should recognize quickly. Practice writing each word on the whiteboard below. Press 'Hear Word' to listen to the word and how to spell it, then trace or write it carefully. When ready, press 'Next Word' to continue!"
		_speak_text_simple(guide_text)

func _on_tts_setting_button_pressed():
	$ButtonClick.play()
	print("PhonicsSightWords: Looking for TTSSettingsPopup (robust lookup)...")
	var tts_popup = get_node_or_null("TTSSettingsPopup")
	if not tts_popup:
		tts_popup = find_child("TTSSettingsPopup", true, false)
	if not tts_popup:
		print("PhonicsSightWords: TTSSettingsPopup not found - instantiating dynamically")
		var popup_scene: PackedScene = load("res://Scenes/TTSSettingsPopup.tscn")
		if popup_scene:
			tts_popup = popup_scene.instantiate()
			tts_popup.name = "TTSSettingsPopup"
			add_child(tts_popup)
	print("PhonicsSightWords: TTSSettingsPopup final status:", tts_popup != null)
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
		print("PhonicsSightWords: TTS Settings popup opened with voice:", current_voice, "rate:", current_rate)
	else:
		print("PhonicsSightWords: Warning - TTSSettingsPopup still not found after dynamic attempt")

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

func _on_whiteboard_result(text_result: String):
	print("PhonicsSightWords: Whiteboard result -> ", text_result)
	
	# Enhanced recognition with dyslexia-friendly matching
	var recognized_text = text_result.strip_edges().to_lower()
	var target_word = current_target.to_lower()
	
	# Check if recognition matches current target word
	var is_correct = false
	if recognized_text == target_word:
		is_correct = true
	# Also accept close matches (dyslexia-friendly fuzzy matching)
	elif _calculate_word_similarity(recognized_text, target_word) >= 0.7:
		is_correct = true # Accept close matches for dyslexic users
	
	if is_correct and module_progress:
		print("PhonicsSightWords: Correct sight word recognized - ", target_word)
		
		# Update Firebase progress
		var success = await module_progress.set_phonics_sight_word_completed(target_word)
		
		if success:
			# Get updated progress data
			var phonics_progress = await module_progress.get_phonics_progress()
			
			# Show completion celebration
			_show_completion_celebration(target_word, phonics_progress)
		else:
			print("PhonicsSightWords: Failed to update progress in Firebase")
	elif not text_result.begins_with("recognition_error"):
		print("PhonicsSightWords: Sight word not recognized correctly. Expected: ", target_word, ", Got: ", recognized_text)
		_show_encouragement_message(recognized_text, target_word)
		module_progress.increment_progress("phonics_sight_words", 5)

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
	
	if notification_popup and notification_popup.has_method("show_notification"):
		var message = "Good effort! I see you wrote '" + recognized + "'.\n\nLet's practice the sight word '" + expected + "' again.\nRemember, sight words are special words we see often in reading."
		notification_popup.show_notification("Keep Trying!", message, "Practice Again")

func _on_celebration_try_again():
	"""Handle try again button from celebration popup"""
	print("PhonicsSightWords: User chose to try again")
	# Stay on current word for more practice

func _on_celebration_next():
	"""Handle next button from celebration popup"""
	print("PhonicsSightWords: User chose to move to next word")
	_advance_target()

func _on_celebration_closed():
	"""Handle celebration popup closed"""
	print("PhonicsSightWords: Celebration popup closed")
