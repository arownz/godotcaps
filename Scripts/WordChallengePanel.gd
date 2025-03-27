extends Control

signal challenge_completed(bonus_damage)
signal challenge_failed

var current_word = ""
var random_word_api = RandomWordAPI.new()
var text_to_speech = null
var bonus_damage = 20
var tts_system = "native" # Can be "native" or "web"
var tts_voices = []
var selected_voice_index = 0
var speech_rate = 0.8  # Default slower rate for dyslexic users

func _ready():
	# Properly position the panel in the center of the screen
	var viewport_size = get_viewport_rect().size
	var panel_size = $ChallengePanel.size
	
	# Center the panel
	$ChallengePanel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		(viewport_size.y - panel_size.y) / 2
	)
	
	# Hide TTS settings panel initially
	$ChallengePanel/VBoxContainer/TTSSettingsPanel.visible = false
	
	# Determine which TTS system to use
	if OS.get_name() == "Web":
		tts_system = "web"
		text_to_speech = WebTTS.new()
		text_to_speech.connect("voices_loaded", _on_web_voices_loaded)
	else:
		tts_system = "native"
		text_to_speech = TextToSpeech.new()
		text_to_speech.connect("voices_loaded", _on_native_voices_loaded)
	
	# Set initial speech rate
	text_to_speech.set_rate(speech_rate)
	
	# Add APIs as children so they persist with the scene
	add_child(random_word_api)
	add_child(text_to_speech)
	
	# Initialize rate slider
	$ChallengePanel/VBoxContainer/TTSSettingsPanel/VBoxContainer/RateContainer/RateSlider.value = speech_rate
	_update_rate_label()
	
	# Connect to whiteboard interface
	var whiteboard = $ChallengePanel/VBoxContainer/TabContainer/Write/WhiteboardInterface
	whiteboard.connect("word_submitted", _on_word_submitted)
	
	# Fetch a random word to display
	_fetch_random_word()

func _fetch_random_word():
	$ChallengePanel/VBoxContainer/APIStatusLabel.text = "Connecting to random word API..."
	$ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel.text = "Loading..."
	
	# Start with a default word
	current_word = "dyslexia"  # Default word
	
	# Try using the API first (but not on Web)
	if OS.get_name() != "Web":  # APIs often have issues on web builds
		random_word_api.fetch_random_word()
		
		# Create a timeout timer to ensure we don't wait too long
		var timeout = Timer.new()
		timeout.one_shot = true
		add_child(timeout)
		timeout.start(5.0)  # 5-second timeout
		
		# Create connections
		var api_completed_callable = Callable(self, "_on_api_completed")
		var timeout_callable = Callable(self, "_on_api_timeout")
		
		random_word_api.connect("word_fetched", api_completed_callable)
		timeout.connect("timeout", timeout_callable)
		
		# Store references to clean up later
		var _api_timer_data = {
			"timer": timeout,
			"api_callable": api_completed_callable,
			"timeout_callable": timeout_callable,
			"completed": false
		}
		
		# Wait for either completion or timeout
		await get_tree().process_frame
	else:
		# For web, use a simple word list directly
		var simple_words = random_word_api.local_word_list
		
		# Choose a random word from the list
		randomize()
		current_word = simple_words[randi() % simple_words.size()]
		$ChallengePanel/VBoxContainer/APIStatusLabel.text = "Using offline word list"
	
	# Update the UI with the fetched word
	$ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel.text = current_word
	print("Set display word to: " + current_word)

func _on_api_completed():
	# API call completed successfully
	if get_node_or_null("APITimeoutTimer") != null:
		var timer = $APITimeoutTimer
		timer.stop()
		timer.queue_free()
	
	if random_word_api.last_error != "":
		print("API Error: " + random_word_api.last_error)
		$ChallengePanel/VBoxContainer/APIStatusLabel.text = "API Error: Using local word list"
		current_word = random_word_api.get_random_word()  # This will use the fallback
	else:
		current_word = random_word_api.current_word
		if current_word.strip_edges() != "":
			$ChallengePanel/VBoxContainer/APIStatusLabel.text = "Word fetched successfully!"
			print("Successfully fetched word: " + current_word)
		else:
			# API returned empty result, use local word
			current_word = random_word_api.get_random_word()
			$ChallengePanel/VBoxContainer/APIStatusLabel.text = "API returned empty word. Using local list."
	
	# Update the label
	$ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel.text = current_word

func _on_api_timeout():
	# Timeout occurred
	if random_word_api.is_connected("word_fetched", Callable(self, "_on_api_completed")):
		random_word_api.disconnect("word_fetched", Callable(self, "_on_api_completed"))
	
	$ChallengePanel/VBoxContainer/APIStatusLabel.text = "API timeout. Using local word list."
	current_word = random_word_api.get_random_word()
	$ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel.text = current_word

func _on_native_voices_loaded():
	# For native TTS
	var voice_option = $ChallengePanel/VBoxContainer/TTSSettingsPanel/VBoxContainer/VoiceContainer/VoiceOptionButton
	voice_option.clear()
	
	if text_to_speech is TextToSpeech:
		tts_voices = text_to_speech.voices
		for voice in tts_voices:
			voice_option.add_item(voice["name"])
	
	if voice_option.item_count > 0:
		voice_option.select(0)
		selected_voice_index = 0

func _on_web_voices_loaded():
	# For web TTS
	var voice_option = $ChallengePanel/VBoxContainer/TTSSettingsPanel/VBoxContainer/VoiceContainer/VoiceOptionButton
	voice_option.clear()
	
	if text_to_speech is WebTTS:
		tts_voices = text_to_speech.get_available_voices()
		for voice in tts_voices:
			voice_option.add_item(voice.name + " (" + voice.lang + ")")
	
	if voice_option.item_count > 0:
		voice_option.select(0)
		selected_voice_index = 0

func _on_tts_button_pressed():
	# Use TTS to read the current word
	if current_word.strip_edges() != "":
		print("TTS reading word: " + current_word)
		text_to_speech.speak(current_word)
	else:
		print("Cannot read empty word")

func _on_tts_settings_button_pressed():
	# Toggle visibility of TTS settings panel
	$ChallengePanel/VBoxContainer/TTSSettingsPanel.visible = true

func _on_close_button_pressed():
	# Hide TTS settings panel
	$ChallengePanel/VBoxContainer/TTSSettingsPanel.visible = false

func _on_voice_option_button_item_selected(index):
	selected_voice_index = index
	
	# Set the selected voice
	if text_to_speech is WebTTS:
		text_to_speech.set_voice(selected_voice_index)
	else:
		# For native TTS
		if selected_voice_index < tts_voices.size():
			text_to_speech.set_voice(tts_voices[selected_voice_index]["id"])

func _on_rate_slider_value_changed(value):
	speech_rate = value
	text_to_speech.set_rate(speech_rate)
	_update_rate_label()

func _update_rate_label():
	var label = $ChallengePanel/VBoxContainer/TTSSettingsPanel/VBoxContainer/RateContainer/RateValueLabel
	var description = ""
	
	if speech_rate <= 0.5:
		description = "Very Slow"
	elif speech_rate <= 0.8:
		description = "Slower"
	elif speech_rate <= 1.0:
		description = "Normal"
	elif speech_rate <= 1.5:
		description = "Faster"
	else:
		description = "Very Fast"
	
	label.text = "Rate: " + str(speech_rate) + " (" + description + ")"

func _on_test_button_pressed():
	# Test the current TTS settings
	text_to_speech.speak("Testing voice with current settings. This is how I'll read words for you.")

func _on_speak_button_pressed():
	# This would be implemented with a speech recognition API
	# For now, we'll just simulate it for demonstration
	var button = $ChallengePanel/VBoxContainer/TabContainer/Speak/SpeechToTextContainer/SpeakButton
	
	if button.text == "🎤 Start Speaking":
		button.text = "🔴 Recording..."
		
		# Simulate recording delay
		await get_tree().create_timer(2.0).timeout
		
		# For demonstration, show what was recognized (simulated)
		$ChallengePanel/VBoxContainer/TabContainer/Speak/SpeechToTextContainer/RecognizedText.text = current_word
		button.text = "🎤 Start Speaking"
		
		# Check if speech matches the word (always true in this simulation)
		await get_tree().create_timer(0.5).timeout
		_check_word_match(current_word)

func _on_word_submitted(submitted_text):
	# Check if the submitted text matches the current word
	_check_word_match(submitted_text)

func _check_word_match(submitted_text):
	# Compare the submitted text with the current word
	if submitted_text.to_lower().strip_edges() == current_word.to_lower():
		# Word matches - challenge completed!
		challenge_completed.emit(bonus_damage)
		queue_free()
	else:
		# Word doesn't match - challenge failed
		challenge_failed.emit()
		queue_free()
