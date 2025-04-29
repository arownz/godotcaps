extends Control

signal challenge_completed(bonus_damage)
signal challenge_failed
signal challenge_cancelled

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
	
	# Get node references - FIXED PATHS
	random_word_label = $ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel
	recognized_text_label = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/RecognizedText
	speak_button = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/SpeakButton
	status_label = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/StatusLabel
	tts_settings_panel = $ChallengePanel/VBoxContainer/TTSSettingsPanel
	api_status_label = $ChallengePanel/VBoxContainer/APIStatusLabel
	
	# Create TTS instance and initialize
	tts = TextToSpeech.new()
	add_child(tts)
	tts.speech_ended.connect(_on_tts_speech_ended)
	tts.speech_error.connect(_on_tts_speech_error)
	
	# Hide TTS settings panel initially
	if tts_settings_panel:
		tts_settings_panel.visible = false
	
	# Setup speech recognition
	_check_speech_recognition_availability()
	
	# Get a random word for the challenge
	random_word_api = RandomWordAPI.new()
	add_child(random_word_api)
	random_word_api.word_fetched.connect(_on_word_fetched)
	random_word_api.fetch_random_word()
	
	# FIX: Connect buttons signals only if they exist and if not already connected
	var cancel_button = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/CancelButton
	if cancel_button and !cancel_button.is_connected("pressed", Callable(self, "_on_cancel_button_pressed")):
		cancel_button.pressed.connect(_on_cancel_button_pressed)
		
	var tts_button = $ChallengePanel/VBoxContainer/WordContainer/TTSButtonContainer/TTSButton
	if tts_button and !tts_button.is_connected("pressed", Callable(self, "_on_tts_button_pressed")):
		tts_button.pressed.connect(_on_tts_button_pressed)
	
	if speak_button and !speak_button.is_connected("pressed", Callable(self, "_on_speak_button_pressed")):
		speak_button.pressed.connect(_on_speak_button_pressed)
	
	# Connect TTS settings button
	var tts_settings_button = $ChallengePanel/VBoxContainer/WordContainer/TTSButtonContainer/TTSSettingsButton
	if tts_settings_button and !tts_settings_button.is_connected("pressed", Callable(self, "_on_tts_settings_button_pressed")):
		tts_settings_button.pressed.connect(_on_tts_settings_button_pressed)

func _check_speech_recognition_availability():
	# Check for Web platform where SpeechRecognition is available
	if OS.get_name() == "Web":
		# Use JavaScript to check if SpeechRecognition API is available
		if JavaScriptBridge.eval("""
			typeof window !== 'undefined' && 
			(window.SpeechRecognition || window.webkitSpeechRecognition)
		"""):
			speech_recognition_available = true
			if status_label:  # FIX: Add null check
				status_label.text = "Ready for speech input"
			if speak_button:  # FIX: Add null check
				speak_button.disabled = false
		else:
			if status_label:  # FIX: Add null check
				status_label.text = "Speech recognition not available in this browser"
			if speak_button:  # FIX: Add null check
				speak_button.disabled = true
	else:
		# Desktop platforms - use simulation for testing
		speech_recognition_available = true
		if status_label:  # FIX: Add null check
			status_label.text = "Using simulated speech recognition for testing"
		if speak_button:  # FIX: Add null check
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
			
			# Setup Godot callbacks
			JavaScriptBridge.eval("""
				if (typeof window.godot === 'undefined') {
					window.godot = {};
				}
				window.godot.speechResult = function(text) {
					const engine = window.godot.getEngine ? window.godot.getEngine() : null;
					if (engine) {
						engine.sendMessage('%s', 'speech_result_callback', text);
					}
				};
				window.godot.speechError = function(error) {
					const engine = window.godot.getEngine ? window.godot.getEngine() : null;
					if (engine) {
						engine.sendMessage('%s', 'speech_error_callback', error);
					}
				};
				window.godot.speechEnd = function() {
					const engine = window.godot.getEngine ? window.godot.getEngine() : null;
					if (engine) {
						engine.sendMessage('%s', 'speech_end_callback', '');
					}
				};
			""" % [get_path(), get_path(), get_path()])
			
			# Execute JavaScript and check result
			var success = JavaScriptBridge.eval(js_code)
			if success:
				recognition_active = true
				status_label.text = "Listening..."
			else:
				status_label.text = "Failed to start speech recognition"
	else:
		# For testing on desktop
		_simulate_speech_recognition()

# JavaScript callback functions
func speech_result_callback(text):
	_on_speech_recognized(text)

func speech_error_callback(error):
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

func _on_speech_recognized(text):
	# Update recognized text label
	recognized_text_label.text = text
	speak_button.text = "🎤 Start Speaking"
	recognition_active = false
	
	# Change status label
	status_label.text = "Processing result..."
	
	# Check if the recognized text matches the challenge word
	var is_success = text.to_lower().strip_edges() == challenge_word.to_lower().strip_edges()
	var text_result = "Correct! Counter successful" if is_success else "Incorrect"
	status_label.text = text_result
	
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

	# Add the result data
	result_panel.set_result(text, challenge_word, is_success, bonus_damage, "said")

	# Connect the continue signal
	result_panel.continue_pressed.connect(_on_result_panel_continue_pressed.bind(is_success))

	# Hide the current panel but don't free it yet
	self.visible = false

func _on_result_panel_continue_pressed(is_success):
	if is_success:
		emit_signal("challenge_completed", bonus_damage)
	else:
		emit_signal("challenge_failed")
	queue_free()

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

func _on_cancel_button_pressed():
	print("STT challenge cancelled, player will take damage")
	status_label.text = "Challenge cancelled!"
	await get_tree().create_timer(0.5).timeout
	emit_signal("challenge_cancelled")  # This will notify battle_manager to apply damage 
	queue_free()

func _on_test_button_pressed():
	# This is handled by the popup now
	pass

func _on_close_button_pressed():
	# This is handled by the popup now
	tts_settings_panel.visible = false
