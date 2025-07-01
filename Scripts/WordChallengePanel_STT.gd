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
var bonus_damage = 5
var random_word_api = null
var tts = null
var voice_options = []
var recognition_active = false

# Google Cloud Speech API variables
var max_recording_time = 10.0 # Maximum recording time in seconds
var unique_callback_id = ""
var recognition_in_progress = false

# Constants for API
const SPEECH_API_ENDPOINT = "https://speech.googleapis.com/v1/speech:recognize"
const DEFAULT_API_KEY = "AIzaSyCz9BNjDlDYDvioKMwzR2_f8D1vHseQtZ0" # Default key if none provided

# Flag to track if result panel is already showing
var result_panel_active = false

# Flag to track if result is being processed
var result_being_processed = false

func _ready():
	# Get node references
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
	
	# Setup speech recognition capabilities
	_setup_speech_recognition()
	
	# Check existing permissions status WITHOUT requesting them
	_check_existing_permissions()
	
	# Get a random word for the challenge
	random_word_api = RandomWordAPI.new()
	add_child(random_word_api)
	random_word_api.word_fetched.connect(_on_word_fetched)

	random_word_api.fetch_random_word()
	
	# Reset result processing flag at start
	result_being_processed = false

func _setup_speech_recognition():
	print("Setting up web speech recognition...")
	_initialize_web_audio_environment()
	_setup_web_audio_callbacks()

# Function to check if the browser already has microphone permissions
# Modified to only check, not request permissions
func _check_existing_permissions():
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				// Check if permissions API is available
				if (navigator.permissions && navigator.permissions.query) {
					navigator.permissions.query({ name: 'microphone' })
					.then(function(permissionStatus) {
						// Update UI based on current permission state
						if (window.godot_speech) {
							window.godot_speech.permissionState = permissionStatus.state;
						}
						console.log('Microphone permission state:', permissionStatus.state);
						
						// Set up permission change listener
						permissionStatus.onchange = function() {
							if (window.godot_speech) {
								window.godot_speech.permissionState = this.state;
							}
							console.log('Microphone permission state changed to:', this.state);
							
							// Use engine.call instead of sendToGodot
							var engine = null;
							if (window.godot && typeof window.godot.getEngine === 'function') {
								engine = window.godot.getEngine();
							} else if (window.engine) {
								engine = window.engine;
							} else if (window.Module && window.Module.engine) {
								engine = window.Module.engine;
							}
							
							if (engine && typeof engine.call === 'function') {
								engine.call('""" + str(get_path()) + """', 'update_mic_permission_state', this.state);
							}
						};
						
						// Initial update to Godot using available engine
						var engine = null;
						if (window.godot && typeof window.godot.getEngine === 'function') {
							engine = window.godot.getEngine();
						} else if (window.engine) {
							engine = window.engine;
						} else if (window.Module && window.Module.engine) {
							engine = window.Module.engine;
						}
						
						if (engine && typeof engine.call === 'function') {
							engine.call('""" + str(get_path()) + """', 'update_mic_permission_state', permissionStatus.state);
						}
						
						return permissionStatus.state;
					})
					.catch(function(error) {
						console.error('Error checking microphone permission:', error);
						return 'unknown';
					});
				} else {
					console.log('Permissions API not supported');
					return 'unknown';
				}
				return 'checking';
			})();
		"""
		JavaScriptBridge.eval(js_code)

# Callback function for permission state updates from JavaScript
func update_mic_permission_state(state):
	print("Microphone permission state updated: " + state)
	
	if state == "granted":
		# Permission already granted, update UI to show this
		status_label.text = "Click mic button to start"
		speak_button.disabled = false
	elif state == "denied":
		# Permission denied, update UI to show this
		status_label.text = "Microphone access denied. Check browser settings."
		speak_button.disabled = false # Still allow clicking to trigger permission prompt
	else:
		# Permission not determined yet, will be requested when button is clicked
		status_label.text = "Click mic button to start"
		speak_button.disabled = false

# Initialize JavaScript environment for web audio - FIXED ENGINE DETECTION
func _initialize_web_audio_environment():
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				// Reset godot_speech object if it exists to avoid conflicts
				if (window.godot_speech) {
					console.log("Resetting godot_speech object");
					delete window.godot_speech;
				}
				
				// Create fresh godot_speech object
				window.godot_speech = {
					mediaRecorder: null,
					audioChunks: [],
					audioStream: null,
					recording: false,
					permissionState: 'prompt',
					engineReady: false,
					
					// Debug logging function
					debugLog: function(message) {
						console.log("Speech Debug:", message);
					},
					
					// Fixed result handler with more robust engine detection
					onResult: function(text) {
						this.debugLog("Recognition result: " + text);
						if (text) {
							try {
								var engine = this.getEngine();
								if (engine) {
									this.debugLog("Calling Godot with recognition result");
									engine.call('""" + str(get_path()) + """', 'speech_result_callback', text);
									this.debugLog("Call to Godot completed");
								} else {
									this.debugLog("ERROR: Could not find Godot engine");
									// Fallback approach using a global function
									if (typeof window.godotSpeechResultCallback === 'function') {
										this.debugLog("Using fallback global callback");
										window.godotSpeechResultCallback(text);
									}
								}
							} catch (e) {
								console.error("Error calling Godot:", e);
								// Try alternate method with setTimeout
								setTimeout(() => {
									var engine = this.getEngine();
									if (engine) {
										this.debugLog("Retrying Godot call after delay");
										engine.call('""" + str(get_path()) + """', 'speech_result_callback', text);
									}
								}, 100);
							}
						} else {
							this.onError("Empty result from speech recognition");
						}
					},
					
					// Fixed error handler - IMPORTANT: Define as function expression
					onError: function(error) {
						this.debugLog("Speech recognition error: " + error);
						var engine = this.getEngine();
						if (engine) {
							engine.call('""" + str(get_path()) + """', 'speech_error_callback', error.toString());
						}
					},
					
					 // Enhanced engine detection
					getEngine: function() {
						if (window.godot && typeof window.godot.getEngine === 'function') {
							return window.godot.getEngine();
						} else if (window.engine) {
							return window.engine;
						} else if (window.Module && window.Module.engine) {
							return window.Module.engine;
						} else if (typeof _engine !== 'undefined') {
							return _engine;
						}
						return null;
					}
				};
				
				// Define a global callback function that Godot can call to check if results are ready
				window.godotSpeechResultCallback = function(text) {
					console.log("Global speech result callback with:", text);
					// We'll poll for this value from Godot
					window.latestSpeechResult = text;
				};
				
				// Define a function to check if we have a result
				window.getSpeechResult = function() {
					if (window.latestSpeechResult) {
						var result = window.latestSpeechResult;
						window.latestSpeechResult = null; // Clear after reading
						return result;
					}
					return null;
				};
				
				return window.godot_speech != null;
			})();
		"""
		
		# Execute the JavaScript
		var result = JavaScriptBridge.eval(js_code)
		print("Web audio environment initialized: ", result)

# Set up JavaScript callbacks for web platform
func _setup_web_audio_callbacks():
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				// Make sure we have our speech object
				if (!window.godot_speech) return false;
				
				// Store the godot object path for sending messages back
				window.godot_speech._godotObjectPath = '""" + str(get_path()) + """';
				
				// Process audio data after recording
				window.godot_speech.processAudio = function(audioBlob) {
					this.debugLog("Processing recorded audio");
					
					// Convert audio blob to base64
					var reader = new FileReader();
					reader.readAsDataURL(audioBlob); 
					reader.onloadend = () => {
						try {
							var base64data = reader.result.split(',')[1];
							this.debugLog("Audio converted to base64");
							
							// Send the audio data to the Google Speech API
							this.debugLog("Sending request to Google Speech API");
							
							// Request parameters
							var request = {
								config: {
									encoding: "WEBM_OPUS",
									sampleRateHertz: 48000,
									languageCode: "en-US",
									model: "command_and_search",
									speechContexts: [{
										phrases: ["spelling", "letters", "dictation"]
									}]
								},
								audio: {
									content: base64data
								}
							};
							
							fetch('https://speech.googleapis.com/v1/speech:recognize?key=' + window.GOOGLE_CLOUD_API_KEY, {
								method: 'POST',
								headers: {
									'Content-Type': 'application/json'
								},
								body: JSON.stringify(request)
							})
							.then(response => response.json())
							.then(data => {
								this.debugLog("Speech API response received");
								console.log("Speech API response:", data);
								
								if (data.results && data.results.length > 0 && 
									data.results[0].alternatives && 
									data.results[0].alternatives.length > 0) {
									var text = data.results[0].alternatives[0].transcript;
									// Make sure to use function properly
									this.onResult(text);
								} else {
									// Make sure to use function properly
									this.onError("No recognition result");
								}
							})
							.catch(error => {
								console.error("Error with Speech API:", error);
								// Make sure to use function properly
								this.onError(error);
							});
						} catch (e) {
							// Make sure to use function properly
							this.onError("Audio processing error: " + e.message);
						}
					};
				};
				
				return true;
			})();
		"""
		
		var result = JavaScriptBridge.eval(js_code)
		print("Web audio callbacks set up: ", result)

# Process function - removed since we don't need desktop functionality

func _on_word_fetched():
	# Get word from the API - FIX: Use the proper method to get the word
	challenge_word = random_word_api.get_random_word()
	
	# Update UI
	if random_word_label:
		random_word_label.text = challenge_word
		
	# Send word to JavaScript for debug - FIX: Properly escape the string
	if JavaScriptBridge.has_method("eval"):
		var escaped_word = challenge_word.replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r")
		var js_code = "window.setChallengeWord(\"" + escaped_word + "\");"
		JavaScriptBridge.eval(js_code)
	
# Handle button press to start/stop speech recognition
func _on_speak_button_pressed():
	if recognition_active:
		# Stop recording
		recognition_active = false
		speak_button.text = "Speak"
		status_label.text = "Processing speech..."
		
		_stop_web_recording()
	else:
		# Update UI first
		status_label.text = "Starting microphone..."
		
		# Start recording - this will request permission if needed
		recognition_active = true
		speak_button.text = "Stop"
		recognized_text_label.text = ""
		
		_start_web_recording()

# Web platform recording functions using Google Cloud Speech-to-Text API
func _start_web_recording():
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				window.godot_speech.debugLog('Starting web recording');
				
				// Clean up any existing MediaRecorder
				if (window.godot_speech.mediaRecorder && window.godot_speech.mediaRecorder.state !== 'inactive') {
					window.godot_speech.mediaRecorder.stop();
				}
				
				if (window.godot_speech.audioStream) {
					window.godot_speech.audioStream.getTracks().forEach(track => track.stop());
					window.godot_speech.audioStream = null;
				}
				
				window.godot_speech.audioChunks = [];
				window.godot_speech.recording = true;
				
				// Request microphone permission now (or use existing permission)
				navigator.mediaDevices.getUserMedia({ 
					audio: { 
						echoCancellation: true,
						noiseSuppression: true,
						autoGainControl: true
					}, 
					video: false 
				})
				.then(function(stream) {
					// Update our tracked permission state
					window.godot_speech.permissionState = 'granted';
					
					window.godot_speech.audioStream = stream;
					window.godot_speech.audioChunks = [];
					
					try {
						// Create MediaRecorder with optimal settings for speech
						window.godot_speech.mediaRecorder = new MediaRecorder(stream, {
							mimeType: 'audio/webm;codecs=opus',
							audioBitsPerSecond: 24000
						});
						
						// Listen for data available event
						window.godot_speech.mediaRecorder.ondataavailable = function(e) {
							if (e.data.size > 0) {
								window.godot_speech.audioChunks.push(e.data);
							}
						};
						
						// Setup completion handler
						window.godot_speech.mediaRecorder.onstop = function() {
							window.godot_speech.debugLog('MediaRecorder stopped');
							window.godot_speech.recording = false;
							
							// Process the audio chunks
							if (window.godot_speech.audioChunks.length > 0) {
								var audioBlob = new Blob(window.godot_speech.audioChunks, { type: 'audio/webm;codecs=opus' });
								window.godot_speech.debugLog('Audio recorded: ' + (audioBlob.size / 1024).toFixed(2) + ' KB');
								
								// Process the audio
								window.godot_speech.processAudio(audioBlob);
							} else {
								// Use with proper function call
								if (typeof window.godot_speech.onError === 'function') {
									window.godot_speech.onError('No audio data recorded');
								}
							}
						};
						
						// Setup error handler
						window.godot_speech.mediaRecorder.onerror = function(event) {
							// Use with proper function call
							if (typeof window.godot_speech.onError === 'function') {
								window.godot_speech.onError('MediaRecorder error: ' + event.name);
							}
						};
						
						// Start recording
						window.godot_speech.mediaRecorder.start();
						window.godot_speech.debugLog('MediaRecorder started');
						
						return true;
					} catch (err) {
						// Use with proper function call
						if (typeof window.godot_speech.onError === 'function') {
							window.godot_speech.onError('Error initializing MediaRecorder: ' + err.message);
						}
						return false;
					}
				})
				.catch(function(err) {
					console.error('Error accessing media devices:', err);
					
					// Update our tracked permission state if denied
					if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
						window.godot_speech.permissionState = 'denied';
					}
					
					// Use with proper function call
					if (typeof window.godot_speech.onError === 'function') {
						window.godot_speech.onError('Microphone access error: ' + err.message);
					}
					return false;
				});
				
				return true;
			})();
		"""
		
		var result = JavaScriptBridge.eval(js_code)
		print("Starting web recording: ", result)

func _stop_web_recording():
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				window.godot_speech.debugLog('MediaRecorder stopped by user');
				
				if (window.godot_speech.mediaRecorder && window.godot_speech.mediaRecorder.state !== 'inactive') {
					window.godot_speech.mediaRecorder.stop();
					return true;
				} else {
					if (typeof window.godot_speech.onError === 'function') {
						window.godot_speech.onError('No active recording to stop');
					}
					return false;
				}
			})();
		"""
		
		var result = JavaScriptBridge.eval(js_code)
		print("Stopping web recording: ", result)

# Callback function for speech recognition result from JavaScript
func speech_result_callback(text):
	print("SPEECH RECOGNITION CALLBACK: Received text from JavaScript: " + text)
	
	# Reset the flag for safety
	result_being_processed = false
	
	if text and text.length() > 0:
		# Call our rewritten function with the recognized text
		print("CALLING RECOGNITION HANDLER with text: " + text)
		call_deferred("_on_speech_recognized", text)
	else:
		print("EMPTY RECOGNITION RESULT")
		status_label.text = "Could not understand speech"
		speak_button.text = "Speak"
		speak_button.disabled = false
		recognition_active = false

# Callback function for speech recognition error from JavaScript
func speech_error_callback(error):
	print("Speech recognition error: ", error)
	status_label.text = "Error: " + error
	recognition_active = false
	speak_button.text = "Speak"
	speak_button.disabled = false

# Function to process recognized speech - COMPLETELY REWRITTEN FOR RELIABILITY
func _on_speech_recognized(text):
	print("PROCESSING RECOGNITION: Recognized text = '" + text + "', challenge word = '" + challenge_word + "'")
	
	# Prevent duplicate processing with more verbose logging
	if result_being_processed:
		print("DUPLICATE RECOGNITION: Already processing a result, ignoring this one")
		return
		
	# Mark that we're processing to prevent duplicates
	result_being_processed = true
	
	# Update UI elements
	recognized_text_label.text = text
	speak_button.disabled = true
	status_label.text = "Processing result..."
	
	# Normalize texts for comparison
	var recognized_normalized = text.to_lower().strip_edges()
	var target_normalized = challenge_word.to_lower().strip_edges()
	
	# Apply more text normalization
	recognized_normalized = recognized_normalized.replace(" ", "")
	recognized_normalized = recognized_normalized.replace("\n", "")
	recognized_normalized = recognized_normalized.replace(".", "")
	recognized_normalized = recognized_normalized.replace(",", "")
	
	# Filter special characters
	var regex = RegEx.new()
	regex.compile("[^a-z0-9]")
	recognized_normalized = regex.sub(recognized_normalized, "", true)
	
	print("Normalized recognized text: " + recognized_normalized)
	print("Normalized target word: " + target_normalized)
	
	# Check for success conditions
	var is_success = false
	
	# Exact match check
	if recognized_normalized == target_normalized:
		is_success = true
	
	# Partial match checks for better UX
	elif target_normalized.begins_with(recognized_normalized) and recognized_normalized.length() >= target_normalized.length() / 2:
		is_success = true
	
	elif recognized_normalized.begins_with(target_normalized) and target_normalized.length() >= 2:
		is_success = true
	
	# Fuzzy matching for longer words
	elif target_normalized.length() > 3 and recognized_normalized.length() > 2:
		# Count matching characters
		var match_count = 0
		for c in target_normalized:
			if recognized_normalized.find(c) >= 0:
				match_count += 1
				
		# If 70% or more characters match, accept it
		var match_ratio = float(match_count) / target_normalized.length()
		if match_ratio > 0.7:
			is_success = true
	
	print("WORD COMPARISON: Success = " + str(is_success))
	
	# Create and show the result panel
	print("OPENING RESULT PANEL")
	var result_panel = load("res://Scenes/ChallengeResultPanels.tscn").instantiate()
	
	# Add directly to the scene root to ensure it appears on top of everything
	get_tree().root.add_child(result_panel)
	
	# Set as top-level to avoid parent layout issues
	result_panel.set_as_top_level(true)
	
	# Set position first
	result_panel.position = Vector2.ZERO
	
	# Set anchors and defer size setting
	result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_panel.call_deferred("set_size", get_viewport_rect().size)
	
	# Set the result data - use "said" for the STT
	result_panel.set_result(text, challenge_word, is_success, bonus_damage, "said")
	
	# Connect the continue signal with an anonymous function
	result_panel.continue_pressed.connect(
		func():
			print("RESULT PANEL CONTINUE SIGNAL RECEIVED")
			if is_success:
				# Track module progress if we came from read-aloud module
				if GlobalData and GlobalData.current_module == "read_aloud":
					var lesson_number = _get_current_lesson_number()
					GlobalData.complete_lesson("read_aloud", lesson_number)
					print("WordChallengePanel_STT: Completed read-aloud lesson " + str(lesson_number))
				
				emit_signal("challenge_completed", bonus_damage)
			else:
				emit_signal("challenge_failed")
			queue_free()  # Free our panel
	)
	
	# Hide our entire panel, not just the VBoxContainer
	visible = false
	
	# Print confirmation message
	print("RESULT PANEL SETUP COMPLETE - panel should now be visible")

# Simple failure handling function
func _fail_challenge():
	api_status_label.text = "You failed to counter the skill"
	await get_tree().create_timer(1.0).timeout
	emit_signal("challenge_failed")
	await get_tree().create_timer(0.5).timeout
	queue_free()

# Improved word comparison function to be more forgiving with dyslexic errors
func _compare_words(spoken_word, target_word):
	# Direct match
	if spoken_word == target_word:
		return true
	
	# Check if any words in the phrase match the target
	var words = spoken_word.split(" ")
	for word in words:
		if word == target_word:
			return true
		
		# Check for common speech recognition errors with short words
		if target_word.length() <= 4:  # Updated to handle 4-letter words better
			# For short words like "gate" or "blue", check for near-matches
			var distance = levenshtein_distance(word, target_word)
			if distance <= 1:  # Allow 1 character difference for short words
				return true
	
	# Calculate Levenshtein distance for words that are similar lengths
	if abs(spoken_word.length() - target_word.length()) <= 2:
		var distance = levenshtein_distance(spoken_word, target_word)
		# Allow for more errors in longer words, but be more strict with 4-letter words
		var max_distance = 1 if target_word.length() <= 4 else max(1, target_word.length() / 3)
		if distance <= max_distance:
			return true
	
	return false

# Calculate Levenshtein distance between two strings
func levenshtein_distance(s1, s2):
	var m = s1.length()
	var n = s2.length()
	
	# Create a matrix of size (m+1) x (n+1)
	var d = []
	for i in range(m + 1):
		d.append([])
		for j in range(n + 1):
			d[i].append(0)
	
	# Initialize the first row and column
	for i in range(m + 1):
		d[i][0] = i
	for j in range(n + 1):
		d[0][j] = j
	
	# Fill the matrix
	for j in range(1, n + 1):
		for i in range(1, m + 1):
			var substitutionCost = 0 if s1[i - 1] == s2[j - 1] else 1
			d[i][j] = min(min(d[i - 1][j] + 1, # Deletion
							  d[i][j - 1] + 1), # Insertion
							  d[i - 1][j - 1] + substitutionCost) # Substitution
	
	return d[m][n]

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
	
	if tts.is_connected("speech_error", Callable(self, "_on_tts_speech_ended")):
		tts.disconnect("speech_error", Callable(self, "_on_tts_speech_ended"))

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
	pass

func _on_close_button_pressed():
	pass

func _on_cancel_button_pressed():
	print("Cancel button pressed - cancelling speak challenge")
	emit_signal("challenge_cancelled")
	
	# Return to the correct scene based on where we came from
	if GlobalData and GlobalData.previous_scene != "":
		print("WordChallengePanel_STT: Returning to " + GlobalData.previous_scene)
		GlobalData.return_to_previous_scene()
	else:
		# Default fallback
		get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

# Make sure to clean up resources when this node is about to be removed
func _exit_tree():
	_cleanup_web_audio()

# Clean up any web audio resources when no longer needed
func _cleanup_web_audio():
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				if (window.godot_speech && window.godot_speech.audioStream) {
					window.godot_speech.audioStream.getTracks().forEach(track => track.stop());
					window.godot_speech.audioStream = null;
				}
				
				if (window.godot_speech && window.godot_speech.mediaRecorder) {
					if (window.godot_speech.mediaRecorder.state !== 'inactive') {
						window.godot_speech.mediaRecorder.stop();
					}
					window.godot_speech.mediaRecorder = null;
				}
				
				if (window.godot_speech) {
					window.godot_speech.audioChunks = [];
					window.godot_speech.recording = false;
					window.godot_speech.engineReady = false;
				}

				return true;
			})();
		"""
		
		JavaScriptBridge.eval(js_code)
		print("Web audio resources cleaned up")

# Add a polling mechanism to check for results
func _process(_delta):
	# Only check for results if we're in active recognition mode
	if recognition_active or (not result_being_processed and JavaScriptBridge.has_method("eval")):
		var result = JavaScriptBridge.eval("window.getSpeechResult ? window.getSpeechResult() : null;")
		if result and typeof(result) == TYPE_STRING:
			print("Found result from polling: " + result)
			speech_result_callback(result)
			
# Helper function to determine current lesson number
func _get_current_lesson_number() -> int:
	if GlobalData and GlobalData.current_module != "":
		var module_progress = GlobalData.get_module_progress(GlobalData.current_module)
		if not module_progress.is_empty():
			return module_progress.current_lesson
	return 1 # Default to lesson 1