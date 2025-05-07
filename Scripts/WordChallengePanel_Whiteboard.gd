extends Control

signal challenge_completed(bonus_damage)
signal challenge_failed
signal challenge_cancelled

# References to child nodes
var random_word_label
var whiteboard_interface
var tts_settings_panel
var api_status_label

# Word challenge properties
var challenge_word = ""
var bonus_damage = 5
var random_word_api = null
var tts = null

func _ready():
	# Get node references
	random_word_label = $ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel
	whiteboard_interface = $ChallengePanel/VBoxContainer/WhiteboardContainer/WhiteboardInterface
	tts_settings_panel = $ChallengePanel/VBoxContainer/TTSSettingsPanel
	api_status_label = $ChallengePanel/VBoxContainer/APIStatusLabel
	
	# Create TTS instance using our simplified TextToSpeech class
	tts = TextToSpeech.new()
	add_child(tts)
	print("Created TextToSpeech instance")
	
	# Hide the built-in TTS panel (will use popup instead)
	tts_settings_panel.visible = false
	
	# Create and initialize the random word API
	random_word_api = RandomWordAPI.new()
	add_child(random_word_api)
	random_word_api.word_fetched.connect(_on_word_fetched)
	
	# Fetch a random word
	random_word_api.fetch_random_word()
	
	# Connect whiteboard signals
	whiteboard_interface.drawing_submitted.connect(_on_drawing_submitted)
	whiteboard_interface.connect("drawing_cancelled", Callable(self, "_on_drawing_cancelled"))
	
	# Update status to show we're using Google Cloud Vision
	api_status_label.text = "Using Google Cloud Vision for recognition"

# Function to provide the challenge word to the WhiteboardInterface
func get_challenge_word():
	return challenge_word

# Function to handle cancellation from whiteboard
func _on_drawing_cancelled():
	print("Drawing cancelled, player will take damage")
	api_status_label.text = "Challenge cancelled!"
	await get_tree().create_timer(0.5).timeout
	emit_signal("challenge_cancelled")  # This will notify battle_manager to apply damage
	queue_free()

func _on_word_fetched():
	# Update the random word label
	challenge_word = random_word_api.get_random_word()
	random_word_label.text = challenge_word
	
	# Clear API status if successful, or show error
	if random_word_api.last_error == "":
		api_status_label.text = ""
	else:
		api_status_label.text = "API Error: " + random_word_api.last_error
		
		# If API fails, use a fallback word
		if challenge_word.is_empty():
			var fallback_words = ["cat", "dog", "tree", "book", "pen", "car", "sun", "moon", "fish", "house"]
			challenge_word = fallback_words[randi() % fallback_words.size()]
			random_word_label.text = challenge_word
			api_status_label.text = "Using fallback word"
	
	# Store the challenge word in JavaScript for debugging
	if OS.has_feature("JavaScript"):
		JavaScriptBridge.eval("window.setChallengeWord('%s');" % challenge_word)
	
	# Log the word for debugging
	print("Challenge word: ", challenge_word)

func _on_drawing_submitted(text_result):
	# Update status
	api_status_label.text = "Processing recognition result..."
	
	# Normalize and compare the recognized text with the challenge word
	var recognized_text = ""
	var target_word = ""
	
	if text_result != null and typeof(text_result) == TYPE_STRING:
		# Enhanced text normalization:
		recognized_text = text_result.to_lower().strip_edges()
		
		# Check for special error messages to handle them separately
		if recognized_text == "no_text_detected" or recognized_text == "recognition_error":
			print("Special error case detected: " + recognized_text)
		else:
			# More sophisticated normalization for normal text results
			recognized_text = recognized_text.replace(" ", "")
			recognized_text = recognized_text.replace("\n", "")
			recognized_text = recognized_text.replace(".", "")
			recognized_text = recognized_text.replace(",", "")
			
			# Filter special characters that might interfere with comparison
			var regex = RegEx.new()
			regex.compile("[^a-z0-9]")
			recognized_text = regex.sub(recognized_text, "", true)
	else:
		recognized_text = "no_text_detected"
		
	if challenge_word != null and typeof(challenge_word) == TYPE_STRING:
		target_word = challenge_word.to_lower().strip_edges()
	
	print("Recognized text (normalized): " + recognized_text)
	print("Target word (normalized): " + target_word)
	
	# Check for success conditions
	var is_success = false
	
	# Exact match check
	if recognized_text == target_word:
		is_success = true
	
	# Partial match checks for better UX
	elif target_word.begins_with(recognized_text) and recognized_text.length() >= target_word.length() / 2:
		is_success = true
	
	elif recognized_text.begins_with(target_word) and target_word.length() >= 2:
		is_success = true
	
	# Fuzzy matching for longer words
	elif target_word.length() > 3 and recognized_text.length() > 2:
		# Count matching characters
		var match_count = 0
		for c in target_word:
			if recognized_text.find(c) >= 0:
				match_count += 1
				
		# If 70% or more characters match, accept it
		var match_ratio = float(match_count) / target_word.length()
		if match_ratio > 0.7:
			is_success = true
	
	# Create and show the result panel
	var result_panel = load("res://Scenes/ChallengeResultPanels.tscn").instantiate()

	# Add directly to the scene root to ensure it appears on top of everything
	get_tree().root.add_child(result_panel)

	# Set as top-level to avoid parent layout issues
	result_panel.set_as_top_level(true)

	# FIXED: Use the proper approach for setting full screen size
	# First set the position
	result_panel.position = Vector2.ZERO

	# FIXED: Set anchors first, then defer the size setting to avoid warnings
	result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_panel.call_deferred("set_size", get_viewport_rect().size)

	# Set the result data - "wrote" for the whiteboard
	result_panel.set_result(text_result, challenge_word, is_success, bonus_damage, "wrote")

	# Connect the continue signal
	result_panel.continue_pressed.connect(_on_result_panel_continue_pressed.bind(is_success))

	# Hide the current panel but don't free it yet
	self.visible = false

# Handle the continue signal from result panel
func _on_result_panel_continue_pressed(was_successful: bool):
	if was_successful:
		emit_signal("challenge_completed", bonus_damage)
	else:
		emit_signal("challenge_failed")
	
	# Now we can free the challenge panel
	queue_free()

# Simple failure handling function
func _fail_challenge():
	api_status_label.text = "You failed to counter the skill"
	await get_tree().create_timer(1.0).timeout
	emit_signal("challenge_failed")
	await get_tree().create_timer(0.5).timeout
	queue_free()

# Calculate similarity between two words to help with dyslexia recognition
func calculate_word_similarity(word1, word2):
	# For completely different length words, reduce similarity
	var length_diff = abs(word1.length() - word2.length())
	if length_diff > 3:
		return 0.0
		
	# Convert to arrays for easier manipulation
	var chars1 = word1.to_ascii_buffer()
	var chars2 = word2.to_ascii_buffer()
	
	# Levenshtein distance calculation (simplified for dyslexia)
	var distance = 0.0
	var max_length = max(chars1.size(), chars2.size())
	
	# Common dyslexic letter swaps to be more lenient with
	var common_swaps = {
		"b": "d", "d": "b",  # b-d confusion
		"p": "q", "q": "p",  # p-q confusion
		"m": "w", "w": "m",  # m-w confusion
		"n": "u", "u": "n",  # n-u confusion
	}
	
	# Add phonetic similarity - letters that sound similar
	var phonetic_similar = {
		"f": "v", "v": "f",
		"s": "z", "z": "s",
		"g": "j", "j": "g",
		"c": "k", "k": "c",
	}
	
	# Compare characters allowing for common dyslexic swaps and transpositions
	for i in range(min(chars1.size(), chars2.size())):
		var ch1 = chars1[i]
		var ch2 = chars2[i]
		
		if ch1 != ch2:
			# Check for common dyslexic letter swaps
			var ch1_char = char(ch1)
			var ch2_char = char(ch2)
			if common_swaps.has(ch1_char) and common_swaps[ch1_char] == ch2_char:
				# Count dyslexic swaps as 0.25 distance instead of 1
				distance += 0.25
			elif phonetic_similar.has(ch1_char) and phonetic_similar[ch1_char] == ch2_char:
				# Count phonetic similarities as 0.5 distance
				distance += 0.5
			else:
				distance += 1.0
	
	# Add smaller penalty for length difference
	distance += (length_diff * 0.5)
	
	# Calculate similarity (0 to 1)
	var similarity = 1.0 - (distance / max_length) if max_length > 0 else 0.0
	
	print("Word similarity: ", similarity)
	return similarity

# Handle TTS button press
func _on_tts_button_pressed():
	# Speak the challenge word with improved feedback
	api_status_label.text = "Reading word..."
	
	print("TTS button pressed, trying to speak: ", challenge_word)
	
	var result = tts.speak(challenge_word)
	
	if !result:
		api_status_label.text = "Failed to read word"
		print("TTS speak returned false")
		return
	
	# Connect to signals for this specific request if not already connected
	if !tts.is_connected("speech_ended", Callable(self, "_on_tts_speech_ended")):
		tts.connect("speech_ended", Callable(self, "_on_tts_speech_ended"))
	
	if !tts.is_connected("speech_error", Callable(self, "_on_tts_speech_error")):
		tts.connect("speech_error", Callable(self, "_on_tts_speech_error"))

# Handle TTS feedback
func _on_tts_speech_ended():
	api_status_label.text = ""
	
	# Disconnect the temporary signals
	if tts.is_connected("speech_ended", Callable(self, "_on_tts_speech_ended")):
		tts.disconnect("speech_ended", Callable(self, "_on_tts_speech_ended"))
	
	if tts.is_connected("speech_error", Callable(self, "_on_tts_speech_error")):
		tts.disconnect("speech_error", Callable(self, "_on_tts_speech_error"))

func _on_tts_speech_error(error_msg):
	api_status_label.text = "TTS Error: " + error_msg
	
	# Disconnect the temporary signals
	if tts.is_connected("speech_ended", Callable(self, "_on_tts_speech_ended")):
		tts.disconnect("speech_ended", Callable(self, "_on_tts_speech_ended"))
	
	if tts.is_connected("speech_error", Callable(self, "_on_tts_speech_error")):
		tts.disconnect("speech_error", Callable(self, "_on_tts_speech_error"))

func _on_tts_settings_button_pressed():
	# Load and show the TTS settings popup
	var tts_popup = load("res://Scenes/TTSSettingsPopup.tscn").instantiate()
	add_child(tts_popup)
	
	# Set up the popup with current settings
	tts_popup.setup(tts, tts.current_voice, tts.speech_rate, challenge_word)
	
	# Connect signals
	tts_popup.settings_saved.connect(_on_tts_settings_saved)
	tts_popup.settings_closed.connect(_on_tts_settings_closed)

func _on_tts_settings_saved(voice_id, rate):
	# Apply the new settings
	tts.set_voice(voice_id)
	tts.set_rate(rate)

func _on_tts_settings_closed():
	# Do any cleanup needed when the popup is closed
	pass

func _on_test_button_pressed():
	# This is handled by the popup now
	pass

func _on_close_button_pressed():
	# This is handled by the popup now
	tts_settings_panel.visible = false
