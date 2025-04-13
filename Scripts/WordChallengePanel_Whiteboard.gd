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
var bonus_damage = 20
var random_word_api = null
var tts = null
var voice_options = []

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
	whiteboard_interface.drawing_cancelled.connect(_on_drawing_cancelled)

# Function to provide the challenge word to the WhiteboardInterface
func get_challenge_word():
	return challenge_word

# Function to handle cancellation from whiteboard
func _on_drawing_cancelled():
	# Emit signal to indicate challenge was cancelled without affecting engagement
	emit_signal("challenge_cancelled")
	
	# Remove the challenge panel without affecting engagement
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
	# Compare the recognized text with the challenge word
	var recognized_text = text_result.to_lower().strip_edges()
	var target_word = challenge_word.to_lower().strip_edges()
	print("Recognized text: ", recognized_text)
	print("Target word: ", target_word)
	
	# Check for special error messages from our handwriting recognition
	if recognized_text == "no_text_detected" or recognized_text == "drawing_too_small":
		# Tell the user they need to write something
		api_status_label.text = "Please write more clearly"
		await get_tree().create_timer(1.5).timeout
		api_status_label.text = ""
		return
	
	if recognized_text == "looks_like_scribble":
		# Tell the user they need to write properly
		api_status_label.text = "Please don't scribble"
		await get_tree().create_timer(1.5).timeout
		api_status_label.text = ""
		return
	
	if recognized_text == "recognition_error" or recognized_text == "recognition_fallback":
		# Try again
		api_status_label.text = "Recognition error, please try again"
		await get_tree().create_timer(1.5).timeout
		api_status_label.text = ""
		return
	
	# Check for exact match
	if recognized_text == target_word:
		# Success - bonus damage!
		api_status_label.text = "Perfect match!"
		emit_signal("challenge_completed", bonus_damage)
		await get_tree().create_timer(0.5).timeout
		queue_free()
		return
	
	# Calculate similarity for non-exact matches
	var similarity = calculate_word_similarity(recognized_text, target_word)
	
	# Make the threshold more strict - require at least 85% similarity
	if similarity >= 0.85:
		# Close enough match for dyslexia support
		api_status_label.text = "Good enough! (Similarity: " + str(int(similarity * 100)) + "%)"
		emit_signal("challenge_completed", bonus_damage)
		await get_tree().create_timer(0.5).timeout
		queue_free()
	else:
		# Show what was recognized vs what was expected
		api_status_label.text = "Incorrect. You wrote '" + recognized_text + "'"
		await get_tree().create_timer(2.0).timeout
		api_status_label.text = ""
		
		# Check if this was very far off
		if similarity < 0.3:
			api_status_label.text = "Try writing '" + target_word + "' more clearly"
			await get_tree().create_timer(1.5).timeout
			api_status_label.text = ""
		else:
			# Let the player try again without penalty if they were close
			return
		
		# If they were very far off, count as a failure
		emit_signal("challenge_failed")
		await get_tree().create_timer(0.5).timeout
		queue_free()

# Calculate similarity between two words to help with dyslexia recognition
func calculate_word_similarity(word1, word2):
	# For completely different length words, reduce similarity
	var length_diff = abs(word1.length() - word2.length())
	if length_diff > 2:
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
				# Count dyslexic swaps as 0.5 distance instead of 1
				distance += 0.5
			else:
				distance += 1.0
	
	# Add penalty for length difference
	distance += length_diff
	
	# Calculate similarity (0 to 1)
	var similarity = 1.0 - (distance / max_length) if max_length > 0 else 0.0
	
	print("Word similarity: ", similarity)
	return similarity

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
