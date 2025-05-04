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
	
	# Setup speech recognition capabilities
	_setup_speech_recognition()
	
	# Check existing permissions status WITHOUT requesting them
	_check_existing_permissions()
	
	# Get a random word for the challenge
	random_word_api = RandomWordAPI.new()
	add_child(random_word_api)
	random_word_api.word_fetched.connect(_on_word_fetched)
	random_word_api.fetch_random_word()
	
	# Connect TTS settings button signal
	var tts_settings_button = $ChallengePanel/VBoxContainer/WordContainer/TTSButtonContainer/TTSSettingsButton
	if tts_settings_button and !tts_settings_button.is_connected("pressed", Callable(self, "_on_tts_settings_button_pressed")):
		tts_settings_button.pressed.connect(_on_tts_settings_button_pressed)

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
					
					// Fixed result handler - IMPORTANT: Define as function expression
					onResult: function(text) {
						this.debugLog("Recognition result: " + text);
						if (text) {
							var engine = this.getEngine();
							if (engine) {
								engine.call('""" + str(get_path()) + """', 'speech_result_callback', text);
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
					
					// Helper to get engine through various methods
					getEngine: function() {
						if (window.godot && typeof window.godot.getEngine === 'function') {
							return window.godot.getEngine();
						} else if (window.engine) {
							return window.engine;
						} else if (window.Module && window.Module.engine) {
							return window.Module.engine;
						}
						return null;
					}
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
	print("Speech recognition result: ", text)
	if text and text.length() > 0:
		# Explicitly call _on_speech_recognized directly instead of deferring
		_on_speech_recognized(text)
	else:
		status_label.text = "Could not understand speech"
		# Reset the UI for another attempt
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

# Function to process recognized speech
func _on_speech_recognized(text):
	print("Processing recognized text: ", text)
	
	# Prevent duplicate processing
	if result_being_processed:
		print("Result already being processed, ignoring duplicate recognition")
		return
		
	result_being_processed = true
	
	# Update UI
	recognized_text_label.text = text
	speak_button.disabled = true
	status_label.text = "Processing result..."
	
	# Compare with challenge word
	var is_success = _compare_words(text.to_lower().strip_edges(), challenge_word.to_lower())
	print("Word comparison result - Success: " + str(is_success))
	
	# Create the result panel
	var result_panel = load("res://Scenes/ChallengeResultPanels.tscn").instantiate()
	
	# Add directly to the scene root to ensure it appears on top of everything
	get_tree().root.add_child(result_panel)
	
	# Set as top-level to avoid parent layout issues
	result_panel.set_as_top_level(true)
	
	# Set the position to cover the full screen
	result_panel.position = Vector2.ZERO
	
	# Set anchors to fill the screen
	result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_panel.call_deferred("set_size", get_viewport_rect().size)
	
	# Make sure the panel is visible
	result_panel.visible = true
	result_panel.modulate = Color(1, 1, 1, 1) # Full opacity
	
	print("Challenge result panel created: " + str(result_panel) + " visible: " + str(result_panel.visible))
	
	# Set the result data - "said" for the STT
	result_panel.set_result(text, challenge_word, is_success, bonus_damage, "said")
	
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
		if target_word.length() <= 4:
			# For short words like "bus", check for homophones or near-matches
			var distance = levenshtein_distance(word, target_word)
			if distance <= 1: # Allow 1 character difference for short words
				return true
	
	# Calculate Levenshtein distance for words that are similar lengths
	if abs(spoken_word.length() - target_word.length()) <= 2:
		var distance = levenshtein_distance(spoken_word, target_word)
		# Allow for more errors in longer words
		var max_distance = max(1, target_word.length() / 3)
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
	# Text-to-speech for the challenge word
	if challenge_word:
		print("TTS button pressed, trying to speak: " + challenge_word)
		
		# Use the native TTS class instead of JavaScript bridge
		api_status_label.text = "Reading word..."
		var result = tts.speak(challenge_word)
		
		if !result:
			api_status_label.text = "Failed to read word"
			print("TTS speak returned false")

# Fix the TTS settings button functionality to match whiteboard version
func _on_tts_settings_button_pressed():
	# Load and show the TTS settings popup instead of using the built-in panel
	var tts_popup = load("res://Scenes/TTSSettingsPopup.tscn").instantiate()
	add_child(tts_popup)
	
	# Set up the popup with current settings
	tts_popup.setup(tts, tts.current_voice, tts.speech_rate, challenge_word)
	
	# Connect signals
	tts_popup.settings_saved.connect(_on_tts_settings_saved)
	tts_popup.settings_closed.connect(_on_tts_settings_closed)

func _on_tts_settings_saved(voice_id, rate):
	# Apply the new settings directly to the TTS instance
	tts.set_voice(voice_id)
	tts.set_rate(rate)

func _on_tts_settings_closed():
	# Do any cleanup needed when the popup is closed
	pass

func _on_cancel_button_pressed():
	# Emit signal to cancel the challenge
	emit_signal("challenge_cancelled")
	queue_free()

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

# Handle TTS feedback
func _on_tts_speech_ended():
	print("TTS speech ended")

func _on_tts_speech_error(error_msg):
	print("TTS speech error: ", error_msg)
