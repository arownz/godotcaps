extends Control

signal challenge_completed(bonus_damage)
signal challenge_failed

# References to child nodes
var random_word_label
var recognized_text_label
var speak_button
var status_label
var tts_settings_panel
var api_status_label

# Word challenge properties
var challenge_word = ""
var bonus_damage = 20
var random_word_api = null
var tts = null
var voice_options = []
var recognition_active = false

# Placeholder for speech recognition functionality
var speech_recognition_available = false

func _ready():
	# Add overlay to ensure it covers the whole screen
	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.6) # Semi-transparent black
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	move_child(overlay, 0) # Move to bottom
	
	# Get node references
	random_word_label = $ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel
	recognized_text_label = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/RecognizedText
	speak_button = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/SpeakButton
	status_label = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/StatusLabel
	tts_settings_panel = $ChallengePanel/VBoxContainer/TTSSettingsPanel
	api_status_label = $ChallengePanel/VBoxContainer/APIStatusLabel
	
	# Create TTS instance (same as whiteboard panel)
	tts = TextToSpeech.new()
	add_child(tts)
	
	# Initialize TTS settings
	_initialize_tts_settings()
	
	# Create and initialize the random word API
	random_word_api = RandomWordAPI.new()
	add_child(random_word_api)
	random_word_api.word_fetched.connect(_on_word_fetched)
	
	# Fetch a random word
	random_word_api.fetch_random_word()
	
	# Check if speech recognition is available
	_check_speech_recognition_availability()

func _initialize_tts_settings():
	# Get all available voices
	var voice_select = $ChallengePanel/VBoxContainer/TTSSettingsPanel/VBoxContainer/VoiceContainer/VoiceOptionButton
	voice_select.clear()
	
	# Use the correct function to get available voices
	voice_options = []
	var voice_dict = tts.get_voice_list()
	for voice_id in voice_dict:
		voice_options.append({
			"id": voice_id,
			"name": voice_dict[voice_id]
		})
	
	for voice in voice_options:
		voice_select.add_item(voice.name)
	
	# Set default voice
	if voice_options.size() > 0:
		voice_select.select(0)
		tts.set_voice(voice_options[0].id)

func _check_speech_recognition_availability():
	# Check for Web platform where SpeechRecognition is available
	if OS.get_name() == "Web":
		# Use JavaScript to check if SpeechRecognition API is available
		if JavaScriptBridge.eval("""
			typeof window !== 'undefined' && 
			(window.SpeechRecognition || window.webkitSpeechRecognition)
		"""):
			speech_recognition_available = true
			status_label.text = "Ready for speech input"
			speak_button.disabled = false
		else:
			status_label.text = "Speech recognition not available in this browser"
			speak_button.disabled = true
	else:
		# Desktop platforms - use simulation for testing
		speech_recognition_available = true
		status_label.text = "Using simulated speech recognition for testing"
		speak_button.disabled = false

func _on_word_fetched():
	# Update the random word label
	challenge_word = random_word_api.get_random_word()
	random_word_label.text = challenge_word
	
	# Clear API status if successful, or show error
	if random_word_api.last_error == "":
		api_status_label.text = ""
	else:
		api_status_label.text = "API Error: " + random_word_api.last_error
	
	# Log the word for debugging
	print("Challenge word: ", challenge_word)

func _on_speak_button_pressed():
	if OS.get_name() == "Web" && speech_recognition_available:
		if recognition_active:
			# Stop recognition
			JavaScriptBridge.eval("""
				if (window.recognition) {
					window.recognition.stop();
					delete window.recognition;
				}
			""")
			recognition_active = false
			speak_button.text = "🎤 Start Speaking"
			status_label.text = "Stopped listening"
		else:
			# Start Web Speech API recognition
			status_label.text = "Starting recognition..."
			speak_button.text = "Stop Listening"
			
			# Setup SpeechRecognition in JavaScript
			var js_code = """
				const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
				
				if (SpeechRecognition) {
					window.recognition = new SpeechRecognition();
					window.recognition.lang = 'en-US';
					window.recognition.interimResults = false;
					window.recognition.maxAlternatives = 1;
					
					window.recognition.onresult = function(event) {
						const transcript = event.results[0][0].transcript;
						window.godot.speechResult(transcript);
					};
					
					window.recognition.onerror = function(event) {
						window.godot.speechError(event.error);
					};
					
					window.recognition.onend = function() {
						window.godot.speechEnd();
					};
					
					window.recognition.start();
					return true;
				} else {
					return false;
				}
			"""
			
			# Execute JavaScript and check result
			var success = JavaScriptBridge.eval(js_code)
			if success:
				# Register Godot callbacks for JavaScript to call
				JavaScriptBridge.create_callback(Callable(self, "speech_result_callback"))
				JavaScriptBridge.create_callback(Callable(self, "speech_error_callback"))
				JavaScriptBridge.create_callback(Callable(self, "speech_end_callback"))
				
				recognition_active = true
				status_label.text = "Listening..."
			else:
				status_label.text = "Failed to start speech recognition"
	else:
		# For testing on desktop
		_simulate_speech_recognition()

# JavaScript callback functions
func speech_result_callback(args):
	var text = args[0]
	_on_speech_recognized(text)

func speech_error_callback(args):
	var error = args[0]
	status_label.text = "Error: " + error
	recognition_active = false
	speak_button.text = "🎤 Start Speaking"

func speech_end_callback(_args):
	if recognition_active:
		status_label.text = "Recognition finished"
		recognition_active = false
		speak_button.text = "🎤 Start Speaking"

func _simulate_speech_recognition():
	# For testing purposes only - simulate speech recognition
	status_label.text = "Listening..."
	speak_button.text = "Stop Listening"
	recognition_active = true
	
	# Create timer to simulate processing
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func():
		# 50% chance of success for testing
		if randf() > 0.5:
			_on_speech_recognized(challenge_word)
		else:
			_on_speech_recognized("incorrect word")
		timer.queue_free()
	)
	timer.start()

func _start_speech_recognition():
	# Placeholder - would start actual speech recognition
	recognition_active = true
	speak_button.text = "Stop Listening"
	status_label.text = "Listening..."

func _stop_speech_recognition():
	# Placeholder - would stop actual speech recognition
	recognition_active = false
	speak_button.text = "🎤 Start Speaking"
	status_label.text = "Not listening"

func _on_speech_recognized(text):
	# Update recognized text label
	recognized_text_label.text = text
	speak_button.text = "🎤 Start Speaking"
	recognition_active = false
	
	# Change status label
	status_label.text = "Processing result..."
	
	# Check if the recognized text matches the challenge word
	if text.to_lower().strip_edges() == challenge_word.to_lower().strip_edges():
		status_label.text = "Correct! Counter successful"
		await get_tree().create_timer(0.5).timeout
		emit_signal("challenge_completed", bonus_damage)
		queue_free()
	else:
		status_label.text = "Incorrect. You failed to counter the skill"
		
		# For testing, add auto-failure after a few seconds
		await get_tree().create_timer(3.0).timeout
		if is_inside_tree(): # Check if node still exists
			emit_signal("challenge_failed")
			queue_free()

# TTS-related functions (same as whiteboard panel)
func _on_tts_button_pressed():
	# Speak the challenge word
	tts.speak(challenge_word)

func _on_tts_settings_button_pressed():
	# Toggle the TTS settings panel
	tts_settings_panel.visible = !tts_settings_panel.visible

func _on_voice_option_button_item_selected(index):
	# Set the selected voice
	if index >= 0 and index < voice_options.size():
		tts.set_voice(voice_options[index].id)

func _on_rate_slider_value_changed(value):
	# Update rate label text
	var rate_label = $ChallengePanel/VBoxContainer/TTSSettingsPanel/VBoxContainer/RateContainer/RateValueLabel
	var rate_text = "Rate: " + str(value)
	
	if value < 0.8:
		rate_text += " (Slower)"
	elif value > 1.2:
		rate_text += " (Faster)"
	else:
		rate_text += " (Normal)"
	
	rate_label.text = rate_text
	
	# Set speech rate
	tts.set_rate(value)

func _on_test_button_pressed():
	# Test the current TTS settings with the challenge word
	tts.speak(challenge_word)

func _on_close_button_pressed():
	# Close the TTS settings panel
	tts_settings_panel.visible = false
