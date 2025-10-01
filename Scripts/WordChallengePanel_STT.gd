extends Control

signal challenge_completed(bonus_damage)
signal challenge_failed
signal challenge_cancelled

# References to child nodes
var random_word_label
var live_transcription_label
var live_transcription_text
var permission_status_label
var speak_button
var status_label
var tts_settings_panel
var api_status_label

# Word challenge properties
var challenge_word = ""
var bonus_damage = 5 # This will be calculated dynamically
var random_word_api = null
var tts = null
var voice_options = []
var recognition_active = false

# Permission and transcription state
var mic_permission_granted = false
var permission_check_complete = false
var live_transcription_enabled = false
var current_interim_result = ""
var debounce_timer = null

# Enhanced debouncing for similar-sounding words
var last_interim_result = ""
var interim_change_count = 0
var last_change_time = 0

# Flag to track if result panel is already showing
var result_panel_active = false

# Flag to track if result is being processed
var result_being_processed = false

# Flag to prevent double signal emissions
var challenge_result_sent = false

func _ready():
	# Get node references with validation
	random_word_label = get_node_or_null("ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel")
	live_transcription_label = get_node_or_null("ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/LiveTranscriptionContainer/LiveTranscriptionLabel")
	live_transcription_text = get_node_or_null("ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/LiveTranscriptionContainer/LiveTranscriptionText")
	permission_status_label = get_node_or_null("ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/PermissionStatusLabel")
	speak_button = get_node_or_null("ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/SpeakButton")
	status_label = get_node_or_null("ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/StatusLabel")
	tts_settings_panel = get_node_or_null("ChallengePanel/VBoxContainer/TTSSettingsPanel")
	api_status_label = get_node_or_null("ChallengePanel/VBoxContainer/APIStatusLabel")
	
	# Validate critical nodes
	if not random_word_label:
		print("ERROR: Could not find RandomWordLabel node")
		return
	if not speak_button:
		print("ERROR: Could not find SpeakButton node")
		return
	if not api_status_label:
		print("ERROR: Could not find APIStatusLabel node")
		return
	
	# Note: BonusDamageCalculator is now a static class, no instance needed
	
	# Enhanced fade-in animation matching SettingScene style
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Create TTS instance and initialize
	tts = TextToSpeech.new()
	if tts == null:
		print("ERROR: Failed to create TextToSpeech instance")
		api_status_label.text = "TTS initialization failed"
		return
	
	add_child(tts)
	
	# Apply saved TTS settings from SettingsManager
	var saved_voice = SettingsManager.get_setting("accessibility", "tts_voice_id")
	var saved_rate = SettingsManager.get_setting("accessibility", "tts_rate")
	var saved_volume = SettingsManager.get_setting("accessibility", "tts_volume")
	
	if saved_voice != null and saved_voice != "" and saved_voice != "default":
		if tts.has_method("set_voice"):
			tts.set_voice(saved_voice)
			print("WordChallengePanel_STT: Applied saved voice: ", saved_voice)
	
	if saved_rate != null:
		if tts.has_method("set_rate"):
			tts.set_rate(saved_rate)
			print("WordChallengePanel_STT: Applied saved rate: ", saved_rate)
	
	if saved_volume != null:
		if tts.has_method("set_volume"):
			tts.set_volume(saved_volume / 100.0)
			print("WordChallengePanel_STT: Applied saved volume: ", saved_volume, "%")
	
	# Wait a frame for TTS to initialize before connecting signals
	await get_tree().process_frame
	
	# Check if TTS is valid before connecting signals
	if tts and is_instance_valid(tts):
		if not tts.is_connected("speech_ended", Callable(self, "_on_tts_speech_ended")):
			tts.speech_ended.connect(_on_tts_speech_ended)
		if not tts.is_connected("speech_error", Callable(self, "_on_tts_speech_error")):
			tts.speech_error.connect(_on_tts_speech_error)
	else:
		print("ERROR: TTS instance is invalid after creation")
		api_status_label.text = "TTS instance invalid"
	
	# Create debounce timer for live transcription
	debounce_timer = Timer.new()
	debounce_timer.wait_time = 0.3 # 300ms debounce
	debounce_timer.one_shot = true
	add_child(debounce_timer)
	
	# Hide TTS settings panel initially
	if tts_settings_panel:
		tts_settings_panel.visible = false
	
	# Initialize UI state - Always enable button for permission requests
	speak_button.disabled = false
	speak_button.text = "Speak"
	permission_status_label.text = "Click Speak to begin"
	permission_status_label.modulate = Color.WHITE
	status_label.text = "Say the word shown above when ready"
	
	# Setup speech recognition capabilities
	_setup_speech_recognition()
	
	# We'll check permissions when user clicks the button instead of blocking here
	
	# Create and initialize the random word API
	random_word_api = RandomWordAPI.new()
	add_child(random_word_api)
	random_word_api.word_fetched.connect(_on_word_fetched)

	# Set loading text while API loads
	if random_word_label:
		random_word_label.text = "Loading word..."
	
	# Fetch a random word based on current dungeon (defer to ensure everything is ready)
	var word_length = _get_word_length_for_dungeon()
	print("Fetching " + str(word_length) + "-letter word for STT challenge...")
	call_deferred("_fetch_word_deferred", word_length)
	
	# Reset result processing flag at start
	result_being_processed = false
	
	# Connect button hover events
	if speak_button:
		speak_button.mouse_entered.connect(_on_button_hover)

func _on_button_hover():
	$ButtonHover.play()

func _process(_delta):
	# Poll for speech recognition results from JavaScript more frequently
	if live_transcription_enabled and JavaScriptBridge.has_method("eval"):
		# Check for interim results with improved polling
		var interim_js = """
			(function() {
				if (window.latestInterimResult) {
					var result = window.latestInterimResult;
					window.latestInterimResult = null;
					return result;
				}
				return null;
			})();
		"""
		var interim_result = JavaScriptBridge.eval(interim_js)
		if interim_result != null and str(interim_result) != "null" and str(interim_result) != "":
			print("POLLING: Found interim result: " + str(interim_result))
			live_transcription_callback(str(interim_result), false)
		
		# Check for final results with enhanced handling
		var final_js = """
			(function() {
				if (window.latestFinalResult) {
					var result = window.latestFinalResult;
					window.latestFinalResult = null;
					console.log('Polling found final result:', result);
					return result;
				}
				return null;
			})();
		"""
		var final_result = JavaScriptBridge.eval(final_js)
		if final_result != null and str(final_result) != "null" and str(final_result) != "":
			print("POLLING: Found final result: " + str(final_result))
			live_transcription_callback(str(final_result), true)

func _setup_speech_recognition():
	print("Setting up web speech recognition...")
	# Simple setup - we handle everything in the button press now

# Function to check and wait for microphone permissions
func _check_and_wait_for_permissions():
	print("Checking microphone permissions...")
	permission_status_label.text = "Checking microphone permission..."
	
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
						
						// Send current state to Godot
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
						
						// Set up permission change listener
						permissionStatus.onchange = function() {
							if (window.godot_speech) {
								window.godot_speech.permissionState = this.state;
							}
							console.log('Microphone permission state changed to:', this.state);
							
							if (engine && typeof engine.call === 'function') {
								engine.call('""" + str(get_path()) + """', 'update_mic_permission_state', this.state);
							}
						};
					})
					.catch(function(error) {
						console.error('Error checking microphone permission:', error);
						// Default to prompt state if query fails
						var engine = null;
						if (window.godot && typeof window.godot.getEngine === 'function') {
							engine = window.godot.getEngine();
						} else if (window.engine) {
							engine = window.engine;
						}
						
						if (engine && typeof engine.call === 'function') {
							engine.call('""" + str(get_path()) + """', 'update_mic_permission_state', 'prompt');
						}
					});
				} else {
					// Permissions API not available, default to prompt
					console.log('Permissions API not available, defaulting to prompt');
					var engine = null;
					if (window.godot && typeof window.godot.getEngine === 'function') {
						engine = window.godot.getEngine();
					} else if (window.engine) {
						engine = window.engine;
					}
					
					if (engine && typeof engine.call === 'function') {
						engine.call('""" + str(get_path()) + """', 'update_mic_permission_state', 'prompt');
					}
				}
				return 'checking';
			})();
		"""
		JavaScriptBridge.eval(js_code)
		
		# Wait for permission check to complete
		while not permission_check_complete:
			await get_tree().process_frame
		
		print("Permission check completed. Granted: ", mic_permission_granted)

# Function to request microphone permission
func _request_microphone_permission():
	print("Requesting Mic...")
	permission_check_complete = false
	
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				// Request microphone permission by attempting to access media
				navigator.mediaDevices.getUserMedia({ 
					audio: { 
						echoCancellation: true,
						noiseSuppression: true,
						autoGainControl: true
					}, 
					video: false 
				})
				.then(function(stream) {
					// Permission granted
					console.log('Microphone permission granted');
					
					// Stop the stream immediately as we only needed it for permission
					stream.getTracks().forEach(track => track.stop());
					
					// Update permission state
					if (window.godot_speech) {
						window.godot_speech.permissionState = 'granted';
					}
					
					// Notify Godot
					var engine = null;
					if (window.godot && typeof window.godot.getEngine === 'function') {
						engine = window.godot.getEngine();
					} else if (window.engine) {
						engine = window.engine;
					}
					
					if (engine && typeof engine.call === 'function') {
						engine.call('""" + str(get_path()) + """', 'update_mic_permission_state', 'granted');
					}
				})
				.catch(function(err) {
					// Permission denied or error
					console.error('Error requesting microphone permission:', err);
					
					var state = 'denied';
					if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
						state = 'denied';
					} else {
						state = 'prompt'; // Other errors, maybe try again
					}
					
					// Update permission state
					if (window.godot_speech) {
						window.godot_speech.permissionState = state;
					}
					
					// Notify Godot
					var engine = null;
					if (window.godot && typeof window.godot.getEngine === 'function') {
						engine = window.godot.getEngine();
					} else if (window.engine) {
						engine = window.engine;
					}
					
					if (engine && typeof engine.call === 'function') {
						engine.call('""" + str(get_path()) + """', 'update_mic_permission_state', state);
					}
				});
				
				return true;
			})();
		"""
		JavaScriptBridge.eval(js_code)
		
		# Wait for permission request to complete
		while not permission_check_complete:
			await get_tree().process_frame
		
		print("Permission request completed. Granted: ", mic_permission_granted)

# Function to check if the browser already has microphone permissions
# Modified to only check, not request permissions
func _check_existing_permissions():
	print("Checking existing permissions...")
	_check_and_wait_for_permissions()

# Callback function for permission state updates from JavaScript
func update_mic_permission_state(state):
	print("Microphone permission state updated: " + state)
	permission_check_complete = true
	
	if state == "granted":
		# Permission already granted, update UI to show this
		mic_permission_granted = true
		permission_status_label.text = "✓ Microphone permission granted"
		permission_status_label.modulate = Color.GREEN
		status_label.text = "Ready to record - Click Speak"
		speak_button.disabled = false
		speak_button.text = "Speak"
	elif state == "denied":
		# Permission denied, but keep button enabled for retry
		mic_permission_granted = false
		permission_status_label.text = "X Microphone access denied"
		permission_status_label.modulate = Color.RED
		status_label.text = "Permission denied. Click Speak to try again."
		speak_button.disabled = false # Keep enabled for retry
		speak_button.text = "Try Again"
	else:
		# Permission not determined yet, will be requested when button is clicked
		mic_permission_granted = false
		permission_status_label.text = "! Need permission - click Start to grant"
		permission_status_label.modulate = Color.YELLOW
		status_label.text = "Click Speak to grant microphone permission"
		speak_button.disabled = false
		speak_button.text = "Speak"

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
				
				// Create fresh godot_speech object with live transcription support
				window.godot_speech = {
					permissionState: 'prompt',
					engineReady: false,
					recognition: null,
					isListening: false,
					
					// Debug logging function
					debugLog: function(message) {
						console.log("Speech Debug:", message);
					},
					
					// Enhanced result handler for final results
					onResult: function(text) {
						this.debugLog("Final recognition result: " + text);
						if (text) {
							// Store result in window variable as primary method
							window.latestFinalResult = text;
							this.debugLog("Stored final result in window.latestFinalResult");
							
							// Try engine call as secondary method
							try {
								var engine = this.getEngine();
								if (engine) {
									this.debugLog("Found engine, calling Godot with final recognition result");
									engine.call('""" + str(get_path()) + """', 'speech_result_callback', text);
									this.debugLog("Engine call to Godot completed successfully");
								} else {
									this.debugLog("No engine found, relying on window variable polling");
								}
							} catch (e) {
								this.debugLog("Error calling Godot: " + e.message);
								// Don't retry with setTimeout since we have window variables
							}
						} else {
							this.onError("Empty result from speech recognition");
						}
					},
					
					// New handler for live transcription (interim results)
					onLiveResult: function(text, isFinal) {
						this.debugLog("Live transcription: " + text + " (final: " + isFinal + ")");
						
						// Store in window variables as primary fallback since engine detection often fails
						if (isFinal) {
							window.latestFinalResult = text;
							this.debugLog("Stored final result in window.latestFinalResult");
						} else {
							window.latestInterimResult = text;
							this.debugLog("Stored interim result in window.latestInterimResult");
						}
						
						// Try engine call as secondary method
						try {
							var engine = this.getEngine();
							if (engine) {
								this.debugLog("Found engine, calling Godot with live transcription");
								engine.call('""" + str(get_path()) + """', 'live_transcription_callback', text, isFinal);
								this.debugLog("Live transcription callback completed successfully");
							} else {
								this.debugLog("No engine found, relying on window variable polling");
							}
						} catch (e) {
							this.debugLog("Error calling Godot with live transcription: " + e.message);
							// Don't retry here, just rely on the window variables
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
					
					 // Enhanced engine detection with more fallbacks
					getEngine: function() {
						// Try multiple ways to find the Godot engine
						if (window.godot && typeof window.godot.getEngine === 'function') {
							return window.godot.getEngine();
						} else if (window.engine) {
							return window.engine;
						} else if (window.Module && window.Module.engine) {
							return window.Module.engine;
						} else if (typeof _engine !== 'undefined') {
							return _engine;
						} else if (window.Godot && window.Godot.engine) {
							return window.Godot.engine;
						} else if (window.unityInstance && window.unityInstance.SendMessage) {
							// This is actually for Unity, but some people confuse the two
							return null;
						}
						
						// More aggressive search - look for any object with a 'call' method
						var candidates = [window.godot, window.engine, window.Module?.engine, window.Godot?.engine];
						for (var i = 0; i < candidates.length; i++) {
							if (candidates[i] && typeof candidates[i].call === 'function') {
								this.debugLog("Found engine candidate: " + i);
								return candidates[i];
							}
						}
						
						// Final fallback - check if we can find it in global scope
						try {
							if (typeof engine !== 'undefined' && engine && typeof engine.call === 'function') {
								return engine;
							}
						} catch (e) {
							// engine is not defined, continue
						}
						
						this.debugLog("Could not find Godot engine for callback");
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

func _on_word_fetched():
	# Get word from the API
	challenge_word = random_word_api.get_random_word()
	print("STT Challenge: Word fetched: " + challenge_word)
	print("STT Challenge: Signal received, updating UI...")
	
	# Update UI with detailed debugging
	if random_word_label:
		random_word_label.text = challenge_word
		print("STT Challenge: Updated word label to: " + challenge_word)
		print("STT Challenge: Label node path: " + str(random_word_label.get_path()))
		print("STT Challenge: Label visible: " + str(random_word_label.visible))
		print("STT Challenge: Label modulate: " + str(random_word_label.modulate))
	else:
		print("Word display is not responding. Please try again.")
		# Try to find it again
		random_word_label = get_node_or_null("ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel")
		if random_word_label:
			random_word_label.text = challenge_word
			print("STT Challenge: Found and updated label on retry")
		else:
			print("Cannot find the word display. Please refresh and try again.")
			# Print the scene tree to debug
			print("STT Challenge: Current scene children:")
			for child in get_children():
				print("  - " + child.name + " (" + str(child.get_class()) + ")")
		
	# Send word to JavaScript for debug
	if JavaScriptBridge.has_method("eval"):
		var escaped_word = challenge_word.replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r")
		var js_code = "if (window.setChallengeWord) { window.setChallengeWord(\"" + escaped_word + "\"); } else { console.log('Challenge word: " + escaped_word + "'); }"
		JavaScriptBridge.eval(js_code)

# Deferred function to fetch word after scene is fully ready
func _fetch_word_deferred(word_length: int):
	print("STT Challenge: Fetching word deferred with length: " + str(word_length))
	random_word_api.fetch_random_word(word_length)
	
# Handle button press to start/stop speech recognition
func _on_speak_button_pressed():
	$ButtonClick.play()
	print("Speak button pressed. Current state - recognition_active: " + str(recognition_active))
	
	if recognition_active:
		print("Stopping current recognition...")
		# Stop current recognition and process the final result
		speak_button.text = "Processing..."
		speak_button.disabled = true
		status_label.text = "Processing what you said..."
		live_transcription_enabled = false
		_stop_live_recognition()
		
		# Give a moment for any final results to come through
		await get_tree().create_timer(0.5).timeout
		
		# Check if we got any final result from the last session
		var final_result = ""
		if JavaScriptBridge.has_method("eval"):
			var final_check_js = """
				(function() {
					if (window.latestFinalResult) {
						var result = window.latestFinalResult;
						window.latestFinalResult = null;
						return result;
					} else if (window.latestInterimResult) {
						var result = window.latestInterimResult;
						window.latestInterimResult = null;
						return result;
					}
					return null;
				})();
			"""
			var js_result = JavaScriptBridge.eval(final_check_js)
			if js_result != null and str(js_result) != "null" and str(js_result) != "":
				final_result = str(js_result)
		
		# If no result from JavaScript, use the current live transcription
		if final_result.is_empty() and live_transcription_text and not live_transcription_text.text.is_empty():
			# Extract text from live transcription (remove emoji and formatting)
			var live_text = live_transcription_text.text
			if "| " in live_text:
				final_result = live_text.replace("| ", "").strip_edges().to_lower()
			elif "✓ " in live_text:
				final_result = live_text.replace("✓ ", "").replace(" (Perfect!)", "").strip_edges().to_lower()
			elif "~ " in live_text:
				final_result = live_text.replace("~ ", "").replace(" (Close!)", "").strip_edges().to_lower()
			
			print("DEBUG: Extracted final result from live transcription: '" + final_result + "'")
		
		# Process the result if we have one
		if not final_result.is_empty():
			print("Processing final result: " + final_result)
			# Extract the best word and process it
			var best_word = _extract_best_word_match(final_result, challenge_word)
			_on_speech_recognized(best_word)
		else:
			# No result found, reset UI
			recognition_active = false
			speak_button.text = "Speak"
			speak_button.disabled = false
			speak_button.modulate = Color.ORANGE
			status_label.text = "No speech detected. Try again."
			
			# Clear the live transcription display
			if live_transcription_text:
				live_transcription_text.text = ""
				live_transcription_text.visible = false
			
			print("Recognition stopped by user with no result")
	else:
		print("Starting new recognition session...")
		# Clear previous results and reset debouncing
		if live_transcription_text:
			live_transcription_text.text = "Preparing to listen..."
			live_transcription_text.visible = true
			live_transcription_text.modulate = Color.WHITE
		
		# Reset debouncing variables
		last_interim_result = ""
		interim_change_count = 0
		last_change_time = 0
		
		# Start new recognition session
		speak_button.text = "Requesting..."
		speak_button.disabled = false
		status_label.text = "Please allow microphone access..."
		
		# Try to start recognition (this will handle permissions automatically)
		var success = await _start_live_recognition()
		
		if success:
			print("Recognition started successfully")
			# Successfully started
			recognition_active = true
			live_transcription_enabled = true
			speak_button.text = "Stop"
			speak_button.disabled = false
			status_label.text = "Listening... Say the word clearly, then click Stop Recording"
			
			if live_transcription_text:
				live_transcription_text.text = "Listening..."
			
			permission_status_label.text = "✓ Recording active"
			permission_status_label.modulate = Color.GREEN
		else:
			print("Failed to start recognition")
			# Failed to start (permission denied or error)
			speak_button.text = "Try Again"
			speak_button.disabled = false
			status_label.text = "Microphone access needed. Click 'Try Again' to retry."
			permission_status_label.text = "X Microphone access required"
			permission_status_label.modulate = Color.RED

# Start live speech recognition using Web Speech API
func _start_live_recognition() -> bool:
	print("Starting live speech recognition...")
	
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(async function() {
				console.log('Starting Web Speech Recognition...');
				
				// Helper function to clean transcript and keep only letters and spaces
				function cleanTranscriptForWords(text) {
					// Remove punctuation but keep letters and spaces
					return text.replace(/[^a-zA-Z ]/g, '').replace(/[ ]+/g, ' ').trim();
				}
				
				// Check if speech recognition is supported
				if (!window.SpeechRecognition && !window.webkitSpeechRecognition) {
					console.error('Speech recognition not supported');
					return false;
				}
				
				try {
					// Request microphone permission with ENHANCED SENSITIVITY audio constraints
					const audioConstraints = {
						audio: {
							echoCancellation: false,     // Disable echo cancellation to preserve all audio
							noiseSuppression: false,     // Disable noise suppression for better sensitivity
							autoGainControl: true,       // Enable auto gain for volume boost
							sampleRate: 48000,           // High sample rate for better quality
							sampleSize: 16,
							channelCount: 1,
							// Enhanced sensitivity settings for dyslexic learners
							googEchoCancellation: false,
							googAutoGainControl: true,
							googNoiseSuppression: false,
							googHighpassFilter: false,
							googAudioMirroring: false,
							// Volume and gain settings for quiet speakers
							volume: 1.0,
							gain: 2.0,  // Boost gain for better pickup
							// Advanced microphone settings
							advanced: [{
								'name': 'googExperimentalEchoCancellation',
								'value': 'false'
							}, {
								'name': 'googDAEchoCancellation',
								'value': 'false'
							}, {
								'name': 'googExperimentalNoiseSuppression', 
								'value': 'false'
							}]
						}
					};
					
					const stream = await navigator.mediaDevices.getUserMedia(audioConstraints);
					console.log('Enhanced microphone permission granted with constraints:', audioConstraints);
					
					// Stop the permission stream immediately
					stream.getTracks().forEach(track => track.stop());
					
					// Create speech recognition instance
					const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
					window.currentRecognition = new SpeechRecognition();
					
					// Configure for live transcription with ENHANCED SENSITIVITY settings
					window.currentRecognition.continuous = true;
					window.currentRecognition.interimResults = true;
					window.currentRecognition.lang = 'en-US';
					window.currentRecognition.maxAlternatives = 10;  // More alternatives for better accuracy
					
					// Enhanced sensitivity settings for better word recognition
					if (window.currentRecognition.hasOwnProperty('sensitivity')) {
						window.currentRecognition.sensitivity = 1.0; // Maximum sensitivity
					}
					if (window.currentRecognition.hasOwnProperty('speechTime	out')) {
						window.currentRecognition.speechTimeout = 10000; // 10 seconds timeout
					}
					if (window.currentRecognition.hasOwnProperty('speechStartTimeout')) {
						window.currentRecognition.speechStartTimeout = 8000; // 8 seconds to start speaking
					}
					
					// ENHANCED SENSITIVITY SETTINGS for better recognition
					if (window.currentRecognition.serviceURI) {
						// For Chrome/Chromium - enhance recognition with alternative endpoints
						window.currentRecognition.serviceURI = 'wss://www.google.com/speech-api/v2/recognize';
					}
					
					// Enhanced audio constraints for maximum sensitivity
					if (window.currentRecognition.audioConstraints) {
						window.currentRecognition.audioConstraints = {
							echoCancellation: false,  // Disable to preserve all audio
							noiseSuppression: false,  // Disable to catch quieter speech
							autoGainControl: true,    // Enable for volume boost
							sampleRate: 48000,        // High sample rate
							channelCount: 1
						};
					}
					
					// Add grammar hints to prefer words over numbers
					if (window.currentRecognition.grammars) {
						const grammar = '#JSGF V1.0; grammar words; public <word> = alphabet | letters | words | spelling;';
						const speechRecognitionList = new (window.SpeechGrammarList || window.webkitSpeechGrammarList)();
						speechRecognitionList.addFromString(grammar, 1);
						window.currentRecognition.grammars = speechRecognitionList;
					}
					
					// Set up event handlers with improved processing
					window.currentRecognition.onresult = function(event) {
						console.log('Speech recognition onresult triggered, event:', event);
						for (let i = event.resultIndex; i < event.results.length; i++) {
							const result = event.results[i];
							let transcript = result[0].transcript.trim();
							const isFinal = result.isFinal;
							const confidence = result[0].confidence || 0.5;
							
							console.log('Raw transcript:', transcript, 'Confidence:', confidence, 'Final:', isFinal);
							
							// ENHANCED SENSITIVITY: Accept lower confidence for quieter speech and dyslexic speakers
							let minConfidence = 0.2; // Lowered from 0.5 to 0.2 for maximum sensitivity
							
							// Process multiple alternatives for better accuracy (especially for quiet speech)
							if (result.length > 1) {
								let bestTranscript = transcript;
								let bestScore = confidence;
								
								console.log('Processing', result.length, 'alternatives for enhanced sensitivity');
								
								for (let j = 1; j < result.length; j++) {
									const altTranscript = result[j].transcript.trim();
									const altConfidence = result[j].confidence || 0.3;
									
									console.log('Alternative', j, ':', altTranscript, 'Confidence:', altConfidence);
									
									// Prefer word-like alternatives with reasonable confidence
									const isWordLike = !altTranscript.match(/^[0-9]+$/) && altTranscript.match(/^[a-zA-Z ]+$/);
									const confidenceThreshold = bestScore * 0.6; // More lenient threshold for quiet speech
									
									if (altConfidence > confidenceThreshold && isWordLike) {
										console.log('Selecting better alternative for quiet speech:', altTranscript);
										bestTranscript = altTranscript;
										bestScore = altConfidence;
									}
								}
								transcript = bestTranscript;
								console.log('Final selected transcript:', transcript, 'Score:', bestScore);
							}
							
							// Accept even lower confidence transcripts if they look like valid words
							if (confidence < minConfidence && transcript.match(/^[a-zA-Z]+$/)) {
								console.log('Accepting low-confidence word for enhanced sensitivity:', transcript, 'Confidence:', confidence);
								// Continue processing even with low confidence for single-word responses
							}
							
							// Clean transcript of non-letter characters (except spaces)
							transcript = cleanTranscriptForWords(transcript);
							
							console.log('Speech result (enhanced):', transcript, 'Final:', isFinal, 'Confidence:', confidence);
							
							// Store the result globally for Godot to poll
							if (isFinal) {
								window.latestFinalResult = transcript;
								console.log('Stored final result:', transcript);
							} else {
								window.latestInterimResult = transcript;
								console.log('Stored interim result:', transcript);
							}
						}
					};
					
					window.currentRecognition.onerror = function(event) {
						console.error('Speech recognition error:', event.error, 'Event:', event);
						
						// Handle specific errors for enhanced sensitivity
						if (event.error === 'no-speech') {
							console.log('No speech detected - continuing to listen with enhanced sensitivity...');
							// Don't stop for no-speech, just continue with enhanced sensitivity
							return;
						} else if (event.error === 'audio-capture') {
							console.error('Audio capture error - trying enhanced microphone access');
						} else if (event.error === 'not-allowed') {
							console.error('Microphone permission denied');
						} else if (event.error === 'network') {
							console.log('Network error - will attempt restart with enhanced settings');
						} else if (event.error === 'aborted') {
							console.log('Recognition aborted - attempting enhanced restart');
						}
						
						try {
							const engine = window.godot?.getEngine?.() || window.engine || window.Module?.engine;
							if (engine && engine.call) {
								console.log('Calling Godot speech_error_callback...');
								engine.call('""" + str(get_path()) + """', 'speech_error_callback', event.error);
							}
						} catch (e) {
							console.error('Error calling Godot with error:', e);
						}
					};
					
					window.currentRecognition.onend = function() {
						console.log('Speech recognition ended - attempting auto-restart for continuous listening');
						
						// Add a small delay then auto-restart if still active
						setTimeout(() => {
							try {
								const engine = window.godot?.getEngine?.() || window.engine || window.Module?.engine;
								if (engine && engine.call) {
									console.log('Calling Godot recognition_ended_callback...');
									engine.call('""" + str(get_path()) + """', 'recognition_ended_callback');
								}
							} catch (e) {
								console.error('Error calling Godot on end:', e);
							}
						}, 100);
					};
					
					window.currentRecognition.onstart = function() {
						console.log('Speech recognition started successfully');
					};
					
					// Start recognition
					window.currentRecognition.start();
					console.log('Speech recognition started successfully');
					return true;
					
				} catch (error) {
					console.error('Error starting speech recognition:', error);
					return false;
				}
			})();
		"""
		
		var _result = JavaScriptBridge.eval(js_code)
		
		# Wait a moment for the async operation to complete
		await get_tree().create_timer(0.5).timeout
		
		# Check if recognition started successfully
		var success_check = JavaScriptBridge.eval("window.currentRecognition ? true : false")
		print("Live recognition started successfully: ", success_check)
		return success_check
	
	return false

# Stop live speech recognition
func _stop_live_recognition():
	print("Stopping live speech recognition...")
	
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				if (window.currentRecognition) {
					console.log('Stopping speech recognition...');
					window.currentRecognition.stop();
					window.currentRecognition = null;
					return true;
				}
				return false;
			})();
		"""
		
		var _result = JavaScriptBridge.eval(js_code)
		print("Live recognition stopped: ", _result)

# Callback when recognition ends (called from JavaScript)
func recognition_ended_callback():
	print("Recognition ended callback received, recognition_active: " + str(recognition_active))
	if recognition_active:
		# If the user is still actively trying to speak, automatically restart recognition
		print("Auto-restarting speech recognition for continuous listening...")
		await get_tree().create_timer(0.2).timeout # Brief pause to avoid rapid loops
		
		# Check if we're still supposed to be active before restarting
		if recognition_active and not result_being_processed:
			print("Attempting to restart speech recognition...")
			var restart_success = await _start_live_recognition()
			
			if restart_success:
				print("Speech recognition restarted successfully")
				status_label.text = "Listening... (reconnected)"
			else:
				print("Failed to restart speech recognition - will try again")
				# Try one more time after a longer delay for microphone conflicts
				await get_tree().create_timer(1.0).timeout
				if recognition_active and not result_being_processed:
					var second_restart = await _start_live_recognition()
					if second_restart:
						print("Speech recognition restarted on second attempt")
						status_label.text = "Listening... (microphone recovered)"
					else:
						print("Failed to restart speech recognition - stopping")
						_stop_recognition_completely()
		else:
			print("Not restarting - recognition no longer active or result being processed")
	else:
		print("Recognition ended but not active - not restarting")

# Helper function to completely stop recognition
func _stop_recognition_completely():
	recognition_active = false
	live_transcription_enabled = false
	speak_button.text = "Speak"
	speak_button.disabled = false
	status_label.text = "Recognition stopped. Click Speak to try again."
	permission_status_label.text = "Click Speak to begin"
	permission_status_label.modulate = Color.WHITE

# Callback function for speech recognition result from JavaScript
func speech_result_callback(text):
	print("SPEECH RECOGNITION CALLBACK: Received text from JavaScript: " + text)
	
	if text and text.length() > 0:
		print("CALLING RECOGNITION HANDLER with text: " + text)
		call_deferred("_on_speech_recognized", text)
	else:
		print("EMPTY RECOGNITION RESULT")
		status_label.text = "Could not understand speech"
		speak_button.text = "Speak"
		speak_button.disabled = false
		recognition_active = false

# New callback function for live/interim transcription results
func live_transcription_callback(text, is_final):
	print("LIVE TRANSCRIPTION CALLBACK: text='" + str(text) + "', is_final=" + str(is_final) + ", enabled=" + str(live_transcription_enabled))
	
	if not live_transcription_enabled:
		print("Live transcription disabled, ignoring callback")
		return
		
	# Ensure we have valid text
	if text == null or (typeof(text) == TYPE_STRING and text.is_empty()):
		print("Empty or null text received")
		return
		
	var text_str = str(text).strip_edges()
	print("LIVE TRANSCRIPTION: '" + text_str + "' (final: " + str(is_final) + ")")
	
	# Always process as interim - let user decide when to stop manually
	_process_interim_transcription(text_str)

# Process interim (live) transcription results with improved phonetic handling
func _process_interim_transcription(text):
	if not live_transcription_enabled:
		print("Live transcription disabled in interim processing")
		return
	
	print("Processing interim text: '" + text + "'")
	
	# Always update the last interim result to allow infinite tweaking
	last_interim_result = text
	
	# Convert numbers to words first
	var processed_text = _convert_numbers_to_words(text)
	
	# Clean the text to remove non-letter characters except spaces
	processed_text = _clean_text_for_words(processed_text)
	
	# EXTRACT ONLY THE LAST WORD - This fixes the "ore ore" issue
	var words = processed_text.strip_edges().split(" ")
	var last_word = ""
	if words.size() > 0:
		# Get the last non-empty word
		for i in range(words.size() - 1, -1, -1):
			if words[i].strip_edges() != "":
				last_word = words[i].strip_edges()
				break
	
	# Use only the last word for display and comparison
	var display_word = last_word.to_lower().strip_edges()
	print("Extracted last word: '" + display_word + "' from full text: '" + processed_text + "'")
		
	# Update live transcription display with only the last word
	current_interim_result = display_word
	
	# Ensure we have the live transcription text node
	if not live_transcription_text:
		live_transcription_text = get_node_or_null("ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/LiveTranscriptionContainer/LiveTranscriptionText")
		if not live_transcription_text:
			print("ERROR: Could not find live_transcription_text node!")
			return
	
	# Apply phonetic improvement for similar-sounding words
	var improved_text = _apply_phonetic_improvements(display_word, challenge_word)
	
	# Display the improved single word with capitalization
	var display_text = improved_text.capitalize()
	live_transcription_text.text = "| " + display_text
	live_transcription_text.visible = true
	print("Updated live transcription text to: '" + live_transcription_text.text + "'")
	
	# Check if interim result matches target word (both normalized to lowercase)
	if not challenge_word.is_empty():
		var normalized_target = challenge_word.to_lower().strip_edges()
		var normalized_interim = improved_text.replace(" ", "")
		
		print("DEBUG: Comparing '" + normalized_interim + "' with target '" + normalized_target + "'")
		
		# Visual feedback for close matches with improved phonetic matching
		if normalized_interim == normalized_target:
			live_transcription_text.modulate = Color.GREEN
			live_transcription_text.text = "✓ " + display_text.capitalize() + " (Perfect!)"
			print("Perfect match detected!")
		elif _is_phonetic_match(normalized_interim, normalized_target):
			live_transcription_text.modulate = Color.LIME
			live_transcription_text.text = "✓ " + display_text.capitalize() + " (Sounds right!)"
			print("Phonetic match detected!")
		elif _is_close_match(normalized_interim, normalized_target):
			live_transcription_text.modulate = Color.YELLOW
			live_transcription_text.text = "~ " + display_text.capitalize() + " (Close!)"
			print("Close match detected!")
		else:
			live_transcription_text.modulate = Color.WHITE
			live_transcription_text.text = "| " + display_text.capitalize()

# Helper function to convert numbers to words in Godot
func _convert_numbers_to_words(text: String) -> String:
	var number_map = {
		"0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
		"5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine",
		"10": "ten", "11": "eleven", "12": "twelve", "13": "thirteen",
		"14": "fourteen", "15": "fifteen", "16": "sixteen", "17": "seventeen",
		"18": "eighteen", "19": "nineteen", "20": "twenty"
	}
	
	var result = text
	for num in number_map.keys():
		# Use word boundaries to replace standalone numbers
		var regex = RegEx.new()
		regex.compile("\\b" + num + "\\b")
		result = regex.sub(result, number_map[num], true)
	
	return result

# Helper function to clean text and keep only letters and spaces
func _clean_text_for_words(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z ]")
	var cleaned = regex.sub(text, "", true)
	
	# Normalize multiple spaces to single space
	var space_regex = RegEx.new()
	space_regex.compile("[ ]+")
	cleaned = space_regex.sub(cleaned, " ", true)
	
	return cleaned.strip_edges()

# Improved phonetic matching for similar-sounding words
func _apply_phonetic_improvements(recognized_text: String, target_word: String) -> String:
	if recognized_text.is_empty() or target_word.is_empty():
		return recognized_text
	
	var target_lower = target_word.to_lower().strip_edges()
	var recognized_lower = recognized_text.to_lower().strip_edges()
	
	# Enhanced phonetic substitutions for better STT accuracy - EXPANDED LIST
	var phonetic_substitutions = {
		# Common vowel sound confusions
		"ae": "ay", "ay": "ae", "ai": "ay", "ei": "ay",
		"ee": "ea", "ea": "ee", "ie": "ee", "ey": "ee",
		"oo": "ou", "ou": "oo", "ew": "oo", "ue": "oo",
		
		# Common consonant confusions for clear speech
		"ph": "f", "gh": "g", "ck": "k", "ch": "k",
		"th": "t", "sh": "s", "wh": "w",
		
		# Single letter common mix-ups (careful selection)
		"c": "k", "k": "c", "s": "z", "z": "s",
		"f": "v", "v": "f", "b": "p", "p": "b",
		
		# Word-level phonetic corrections (VERY selective)
		"bae": "bay", "bay": "bae", "mai": "may", "wei": "way",
		"sae": "say", "kae": "kay", "jae": "jay", "hae": "hay",
		
		# Remove problematic same-pronunciation pairs that teach wrong words
		# NO MORE: "or"/"ore", "to"/"two", "there"/"their", etc.
	}
	
	# Direct substitution check
	if recognized_lower in phonetic_substitutions:
		var corrected = phonetic_substitutions[recognized_lower]
		if corrected == target_lower:
			print("Applied direct phonetic correction: " + recognized_lower + " -> " + corrected)
			return corrected
	
	# Partial word phonetic matching for longer words
	for wrong_pattern in phonetic_substitutions.keys():
		var correct_pattern = phonetic_substitutions[wrong_pattern]
		if wrong_pattern in recognized_lower and correct_pattern in target_lower:
			var corrected = recognized_lower.replace(wrong_pattern, correct_pattern)
			if _calculate_word_similarity(corrected, target_lower) > 0.8:
				print("Applied pattern phonetic correction: " + recognized_lower + " -> " + corrected)
				return corrected
	
	return recognized_text

# Enhanced phonetic matching function
func _is_phonetic_match(word1: String, word2: String) -> bool:
	if word1 == word2:
		return true
	
	# Common phonetic patterns for dyslexic learners
	var phonetic_equivalents = [
		["ay", "ae", "ai"], # bay, bae, bai
		["ey", "ee", "ei"], # hey, hee, hei
		["ow", "ou", "oo"], # how, hou, hoo
		["er", "ur", "ir"], # her, hur, hir
		["or", "our", "oar"], # for, four, foar
		["ch", "sh", "tch"], # church sounds
		["th", "f", "v"], # think/fink/vink
		["b", "d"], ["p", "q"], ["m", "n"] # common letter confusions
	]
	
	# Check if words are phonetically equivalent
	for pattern_group in phonetic_equivalents:
		for pattern1 in pattern_group:
			for pattern2 in pattern_group:
				if pattern1 != pattern2:
					var word1_alt = word1.replace(pattern1, pattern2)
					var word2_alt = word2.replace(pattern1, pattern2)
					if word1_alt == word2 or word2_alt == word1:
						return true
	
	# Check sound similarity with Levenshtein distance
	var distance = levenshtein_distance(word1, word2)
	var max_length = max(word1.length(), word2.length())
	var similarity = 1.0 - (float(distance) / max_length) if max_length > 0 else 0.0
	
	# More lenient phonetic threshold (80% similarity)
	return similarity >= 0.8

# Extract the best matching word from a phrase compared to target
func _extract_best_word_match(phrase, target_word):
	var words = phrase.to_lower().strip_edges().split(" ")
	var target_normalized = target_word.to_lower().strip_edges()
	
	var best_word = ""
	var best_score = 0.0
	
	# Check each word in the phrase
	for word in words:
		# Clean the word
		var word_cleaned = _clean_text_for_words(word)
		
		# Apply phonetic improvements
		var word_improved = _apply_phonetic_improvements(word_cleaned, target_normalized)
		
		# Calculate similarity scores
		var similarity_score = _calculate_word_similarity(word_improved, target_normalized)
		var phonetic_score = 1.0 if _is_phonetic_match(word_improved, target_normalized) else 0.0
		
		# Combine scores (phonetic match gets highest priority)
		var total_score = max(similarity_score, phonetic_score)
		
		print("Word analysis: '" + word + "' -> cleaned: '" + word_cleaned + "' -> improved: '" + word_improved + "' -> score: " + str(total_score))
		
		if total_score > best_score:
			best_score = total_score
			best_word = word_improved
	
	# If no good match found, use the first word (cleaned and improved)
	if best_word.is_empty() and words.size() > 0:
		var first_word = _clean_text_for_words(words[0])
		best_word = _apply_phonetic_improvements(first_word, target_normalized)
	
	print("Best word match: '" + best_word + "' with score: " + str(best_score))
	return best_word if not best_word.is_empty() else phrase

# Calculate similarity between two words (0.0 to 1.0)
func _calculate_word_similarity(word1, word2):
	if word1 == word2:
		return 1.0
	
	# Calculate Levenshtein distance
	var distance = levenshtein_distance(word1, word2)
	var max_length = max(word1.length(), word2.length())
	
	if max_length == 0:
		return 0.0
	
	return 1.0 - (float(distance) / max_length)

# Enhanced close match function for dyslexic-friendly recognition and quiet speech
func _is_close_match(word1, word2):
	# First check phonetic matching
	if _is_phonetic_match(word1, word2):
		return true
	
	var similarity = _calculate_word_similarity(word1, word2)
	
	# More lenient thresholds for dyslexic learners and quiet speech recognition
	var threshold = 0.55 # Base threshold reduced from 0.6 to 0.55 for better sensitivity
	
	if word2.length() <= 3:
		threshold = 0.65 # Reduced from 0.7 to 0.65 for short words
	elif word2.length() <= 5:
		threshold = 0.60 # Reduced from 0.65 to 0.60 for medium words
	else:
		threshold = 0.55 # Reduced from 0.6 to 0.55 for longer words
	
	# Special case for very similar lengths (likely just pronunciation/recognition differences)
	if abs(word1.length() - word2.length()) <= 1:
		threshold -= 0.15 # More lenient by 15% for similar length words
	
	# Additional leniency for single-character differences in short words
	if word2.length() <= 4 and abs(word1.length() - word2.length()) <= 1:
		var char_diff = levenshtein_distance(word1, word2)
		if char_diff <= 1:
			print("Enhanced sensitivity: Accepting single-character difference for short word")
			return true
	
	return similarity > threshold

# Callback function for speech recognition error from JavaScript
func speech_error_callback(error):
	print("Speech recognition error: ", error)
	
	# Handle different error types with appropriate responses
	if error == "not-allowed" or error == "permission-denied":
		# Stop current recognition for permission issues
		recognition_active = false
		live_transcription_enabled = false
		status_label.text = "Microphone permission denied. Click 'Try Again' to retry."
		speak_button.text = "Try Again"
		permission_status_label.text = "X Permission denied"
		permission_status_label.modulate = Color.RED
		speak_button.disabled = false
	elif error == "no-speech":
		# Don't stop for no-speech - just notify user and continue
		status_label.text = "Continue speaking - I'm listening... (enhanced sensitivity)"
		permission_status_label.text = "♪ Listening (waiting for speech)..."
		permission_status_label.modulate = Color.CYAN
		# Don't stop recognition - let it continue listening
		print("Continuing to listen after no-speech error with enhanced sensitivity...")
	elif error == "network":
		# For network errors, attempt multiple restarts
		print("Network error detected - attempting enhanced restart...")
		call_deferred("_restart_recognition_after_error")
	elif error == "audio-capture":
		# Audio capture errors - try to restart first before giving up
		print("Audio capture error - attempting to recover microphone...")
		status_label.text = "Microphone conflict detected - attempting recovery..."
		permission_status_label.text = "⚠ Recovering microphone..."
		permission_status_label.modulate = Color.YELLOW
		call_deferred("_restart_recognition_after_error")
	elif error == "aborted":
		# Aborted errors often happen with microphone conflicts - try to restart
		print("Recognition aborted - likely microphone conflict - attempting restart...")
		status_label.text = "Recognition interrupted - restarting..."
		call_deferred("_restart_recognition_after_error")
	else:
		# For other errors, try to restart automatically with enhanced recovery
		print("Unknown error '" + error + "' - attempting enhanced restart...")
		call_deferred("_restart_recognition_after_error")

# Enhanced helper function to restart recognition after recoverable errors
func _restart_recognition_after_error():
	if recognition_active:
		print("Attempting enhanced restart of speech recognition after error...")
		status_label.text = "Recovering microphone... please wait"
		
		# Multiple restart attempts with increasing delays for microphone conflicts
		for attempt in range(3):
			var delay = 1.0 + (attempt * 0.5) # 1.0s, 1.5s, 2.0s delays
			await get_tree().create_timer(delay).timeout
			
			print("Restart attempt " + str(attempt + 1) + " of 3")
			status_label.text = "Recovery attempt " + str(attempt + 1) + "/3..."
			
			var restart_success = await _start_live_recognition()
			if restart_success:
				print("Speech recognition successfully restarted on attempt " + str(attempt + 1))
				status_label.text = "Listening... (recovered from error)"
				permission_status_label.text = "✓ Microphone recovered"
				permission_status_label.modulate = Color.GREEN
				return # Success, exit early
			else:
				print("Restart attempt " + str(attempt + 1) + " failed")
		
		# If all attempts failed, fall back to manual restart
		print("All restart attempts failed - requiring manual restart")
		_stop_recognition_completely()
		status_label.text = "Microphone recovery failed. Click 'Speak' to try again."
		speak_button.text = "Try Again"
		permission_status_label.text = "X Recognition error"
		permission_status_label.modulate = Color.RED
		speak_button.disabled = false

# Function to calculate bonus damage based on player stats
# Function to process recognized speech - ENHANCED FOR ACCURACY
func _on_speech_recognized(text):
	print("PROCESSING RECOGNITION: Recognized text = '" + text + "', challenge word = '" + challenge_word + "'")
	
	# Prevent duplicate processing with more verbose logging
	if result_being_processed:
		print("DUPLICATE RECOGNITION: Already processing a result, ignoring this one")
		return
		
	# Mark that we're processing to prevent duplicates
	result_being_processed = true
	
	# Update UI elements
	speak_button.disabled = true
	status_label.text = "Processing result..."
	
	# Enhanced text processing pipeline
	var processed_text = text
	
	# Step 1: Convert numbers to words
	processed_text = _convert_numbers_to_words(processed_text)
	
	# Step 2: Clean text (remove non-letters except spaces)
	processed_text = _clean_text_for_words(processed_text)
	
	# Step 3: Apply phonetic improvements
	processed_text = _apply_phonetic_improvements(processed_text, challenge_word)
	
	# Step 3.5: Extract only the last word (same logic as live transcription)
	var words = processed_text.strip_edges().split(" ")
	var last_word = ""
	if words.size() > 0:
		# Get the last non-empty word
		for i in range(words.size() - 1, -1, -1):
			if words[i].strip_edges() != "":
				last_word = words[i].strip_edges()
				break
	
	# Use only the last word for final processing
	if not last_word.is_empty():
		processed_text = last_word
		print("Extracted last word for final processing: '" + last_word + "' from full text")
	
	# Step 4: Normalize for comparison
	var recognized_normalized = processed_text.to_lower().strip_edges()
	var target_normalized = challenge_word.to_lower().strip_edges()
	
	# Step 5: Remove spaces for final comparison
	recognized_normalized = recognized_normalized.replace(" ", "")
	
	print("Enhanced processing pipeline:")
	print("  Original: '" + text + "'")
	print("  After numbers->words: '" + _convert_numbers_to_words(text) + "'")
	print("  After cleaning: '" + _clean_text_for_words(_convert_numbers_to_words(text)) + "'")
	print("  After phonetic: '" + processed_text + "'")
	print("  Final normalized: '" + recognized_normalized + "'")
	print("  Target: '" + target_normalized + "'")
	
	# Enhanced success condition checks
	var is_success = false
	var match_type = ""
	var match_quality = "close" # Default to close for non-exact matches
	
	# 1. Exact match check
	if recognized_normalized == target_normalized:
		is_success = true
		match_type = "exact"
		match_quality = "perfect"
	
	# 2. Phonetic match check
	elif _is_phonetic_match(recognized_normalized, target_normalized):
		is_success = true
		match_type = "phonetic"
		match_quality = "close"
	
	# 3. Extract best word match from phrase
	elif " " in processed_text:
		var best_word = _extract_best_word_match(processed_text, challenge_word)
		if _is_phonetic_match(best_word.to_lower(), target_normalized) or best_word.to_lower() == target_normalized:
			is_success = true
			match_type = "word_extraction"
			match_quality = "perfect" if best_word.to_lower() == target_normalized else "close"
			recognized_normalized = best_word.to_lower()
	
	# 4. Fuzzy matching for longer words (more lenient for dyslexic learners)
	elif target_normalized.length() > 3 and recognized_normalized.length() > 2:
		var similarity = _calculate_word_similarity(recognized_normalized, target_normalized)
		# Increased threshold to 75% for better dyslexic support
		if similarity >= 0.75:
			is_success = true
			match_type = "fuzzy"
			match_quality = "close"
	
	# 5. Partial match for very close attempts
	elif _is_close_match(recognized_normalized, target_normalized):
		is_success = true
		match_type = "close"
		match_quality = "close"
	
	# Calculate bonus damage using centralized calculator
	if is_success:
		bonus_damage = BonusDamageCalculator.calculate_bonus_damage("stt", match_quality)
	else:
		bonus_damage = 0
	
	print("STT Challenge Result: Success = " + str(is_success) + " (" + match_type + "), Bonus Damage = " + str(bonus_damage))
	
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
	
	# Set the result data - use "said" for the STT and pass match_quality for display
	var display_match_type = match_quality if is_success else ""
	result_panel.set_result(text, challenge_word, is_success, bonus_damage, "said", display_match_type)
	
	# Connect the continue signal with an anonymous function
	result_panel.continue_pressed.connect(
		func():
			print("RESULT PANEL CONTINUE SIGNAL RECEIVED")
			if is_success:
				_fade_out_and_signal("challenge_completed", bonus_damage)
			else:
				_fade_out_and_signal("challenge_failed")
	)
	
	# Hide our entire panel, not just the VBoxContainer
	visible = false
	
	# Print confirmation message
	print("RESULT PANEL SETUP COMPLETE - panel should now be visible")
	
# Helper function to fade out panel before signaling
func _fade_out_and_signal(signal_name: String, param = null):
	# Prevent double signaling
	if challenge_result_sent:
		print("Challenge result already sent, ignoring duplicate signal: " + signal_name)
		return
	
	challenge_result_sent = true
	print("Sending challenge result signal: " + signal_name)
	
	# Enhanced fade-out animation matching SettingScene style
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	
	match signal_name:
		"challenge_completed":
			emit_signal("challenge_completed", param)
		"challenge_failed":
			emit_signal("challenge_failed")
		"challenge_cancelled":
			emit_signal("challenge_cancelled")
	
	queue_free()

# Simple failure handling function
func _fail_challenge():
	api_status_label.text = "You failed to counter the skill"
	await get_tree().create_timer(1.0).timeout
	_fade_out_and_signal("challenge_failed")

# Improved word comparison function to be more forgiving with dyslexic errors
func _compare_words(spoken_word, target_word):
	# Normalize both words (lowercase and clean)
	var normalized_spoken = spoken_word.to_lower().strip_edges()
	var normalized_target = target_word.to_lower().strip_edges()
	
	# Direct match
	if normalized_spoken == normalized_target:
		return true
	
	# Check if any words in the phrase match the target
	var words = normalized_spoken.split(" ")
	for word in words:
		word = word.strip_edges()
		if word == normalized_target:
			return true
		
		# Enhanced phonetic matching for similar sounding words
		if _is_phonetic_match(word, normalized_target):
			print("STT: Phonetic match found: '" + word + "' matches '" + normalized_target + "'")
			return true
		
		# Check for common speech recognition errors with short words
		if normalized_target.length() <= 4:
			# For short words, be more forgiving
			var distance = levenshtein_distance(word, normalized_target)
			if distance <= 1: # Allow 1 character difference for short words
				print("STT: Close match found for short word: '" + word + "' -> '" + normalized_target + "' (distance: " + str(distance) + ")")
				return true
	
	# Enhanced similarity check with phonetic considerations
	if abs(normalized_spoken.length() - normalized_target.length()) <= 3:
		var distance = levenshtein_distance(normalized_spoken, normalized_target)
		var max_distance = 1 if normalized_target.length() <= 4 else max(1, normalized_target.length() / 3)
		
		# More forgiving for longer words to account for speech recognition errors
		if normalized_target.length() > 6:
			max_distance += 1
		
		if distance <= max_distance:
			print("STT: Similarity match found: '" + normalized_spoken + "' -> '" + normalized_target + "' (distance: " + str(distance) + "/" + str(max_distance) + ")")
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
	$ButtonClick.play()
	
	# Validate TTS instance first
	if not tts or not is_instance_valid(tts):
		print("ERROR: TTS instance is null or invalid")
		if api_status_label:
			api_status_label.text = "TTS not available"
		return
	
	# Speak the challenge word with improved feedback
	if api_status_label:
		api_status_label.text = "Reading word..."
	
	print("TTS button pressed, trying to speak: ", challenge_word)
	
	var result = tts.speak(challenge_word)
	
	if !result:
		if api_status_label:
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
	
	if tts.is_connected("speech_error", Callable(self, "_on_tts_speech_ended")):
		tts.disconnect("speech_error", Callable(self, "_on_tts_speech_ended"))

func _on_tts_speech_error(error_msg):
	api_status_label.text = "TTS Error: " + error_msg
	
	# Disconnect the temporary signals
	if tts.is_connected("speech_ended", Callable(self, "_on_tts_speech_ended")):
		tts.disconnect("speech_ended", Callable(self, "_on_tts_speech_ended"))
	
	if tts.is_connected("speech_error", Callable(self, "_on_tts_speech_ended")):
		tts.disconnect("speech_error", Callable(self, "_on_tts_speech_ended"))

func _on_tts_settings_button_pressed():
	$ButtonClick.play()
	# Open the main settings scene instead of TTS-specific popup
	var settings_scene = load("res://Scenes/SettingScene.tscn").instantiate()
	get_tree().root.add_child(settings_scene)
	
	# Connect to handle quit requests from settings popup
	if settings_scene.has_signal("quit_requested"):
		settings_scene.quit_requested.connect(_on_settings_quit_requested)
	
	# CanvasLayer is already rendered on top, no need to set_as_top_level

func _on_tts_settings_saved(voice_id, rate, volume):
	# Apply the new settings including volume
	tts.set_voice(voice_id)
	tts.set_rate(rate)
	if tts.has_method("set_volume"):
		tts.set_volume(volume)

func _on_tts_settings_closed():
	# Do any cleanup needed when the popup is closed
	pass

func _on_test_button_pressed():
	$ButtonClick.play()
	pass

func _on_close_button_pressed():
	$ButtonClick.play()
	pass

func _on_cancel_button_pressed():
	$ButtonClick.play()
	print("Cancel button pressed - cancelling speak challenge")
	_fade_out_and_signal("challenge_cancelled")

# Make sure to clean up resources when this node is about to be removed
func _exit_tree():
	_cleanup_web_audio()

# Clean up any web audio resources when no longer needed
func _cleanup_web_audio():
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				// Clean up current recognition if active
				if (window.currentRecognition) {
					window.currentRecognition.stop();
					window.currentRecognition = null;
				}
				
				// Reset speech object
				if (window.godot_speech) {
					window.godot_speech.engineReady = false;
					window.godot_speech.isListening = false;
				}
				
				// Clear result variables
				window.latestFinalResult = null;
				window.latestInterimResult = null;

				return true;
			})();
		"""
		
		JavaScriptBridge.eval(js_code)
		print("Web audio resources cleaned up")

# Function to get word length based on current dungeon
func _get_word_length_for_dungeon() -> int:
	# Get current dungeon from battle scene
	var battle_scene = get_node("/root/BattleScene")
	if battle_scene and battle_scene.has_method("get_current_dungeon"):
		var current_dungeon = battle_scene.get_current_dungeon()
		match current_dungeon:
			1: return 3 # Dungeon 1: 3-letter words
			2: return 4 # Dungeon 2: 4-letter words
			3: return 5 # Dungeon 3: 5-letter words
			_: return 3 # Default fallback
	else:
		print("Warning: Could not get current dungeon, using default 3-letter words")
		return 3

func _on_cancel_button_mouse_entered() -> void:
	$ButtonHover.play()

# Handle quit request from settings popup - leave the battle entirely
func _on_settings_quit_requested():
	print("WordChallengePanel_STT: Settings quit requested - leaving battle")
	
	# Stop any ongoing speech recognition
	if recognition_active:
		_stop_live_recognition()
	
	# Signal the BattleScene to quit instead of trying to change scenes ourselves
	var battle_scene = get_node_or_null("/root/BattleScene")
	if battle_scene and battle_scene.has_method("_on_battle_quit_requested"):
		print("WordChallengePanel_STT: Calling BattleScene quit function")
		battle_scene._on_battle_quit_requested()
	else:
		print("WordChallengePanel_STT: Could not find BattleScene, canceling challenge instead")
		# Fallback to canceling the challenge
		_fade_out_and_signal("challenge_cancelled")
