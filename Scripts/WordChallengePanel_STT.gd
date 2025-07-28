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

func _ready():
	# Get node references
	random_word_label = $ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel
	live_transcription_label = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/LiveTranscriptionContainer/LiveTranscriptionLabel
	live_transcription_text = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/LiveTranscriptionContainer/LiveTranscriptionText
	permission_status_label = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/PermissionStatusLabel
	speak_button = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/SpeakButton
	status_label = $ChallengePanel/VBoxContainer/SpeechContainer/VBoxContainer/StatusLabel
	tts_settings_panel = $ChallengePanel/VBoxContainer/TTSSettingsPanel
	api_status_label = $ChallengePanel/VBoxContainer/APIStatusLabel
	
	# Create TTS instance and initialize
	tts = TextToSpeech.new()
	add_child(tts)
	tts.speech_ended.connect(_on_tts_speech_ended)
	tts.speech_error.connect(_on_tts_speech_error)
	
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
	speak_button.text = "Start Speaking"
	permission_status_label.text = "Click Start Speaking to begin"
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

func _process(_delta):
	# Poll for speech recognition results from JavaScript
	if live_transcription_enabled and JavaScriptBridge.has_method("eval"):
		# Check for interim results
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
		
		# Check for final results
		var final_js = """
			(function() {
				if (window.latestFinalResult) {
					var result = window.latestFinalResult;
					window.latestFinalResult = null;
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
		status_label.text = "Ready to record - Click Start Speaking"
		speak_button.disabled = false
		speak_button.text = "Start Speaking"
	elif state == "denied":
		# Permission denied, but keep button enabled for retry
		mic_permission_granted = false
		permission_status_label.text = "X Microphone access denied"
		permission_status_label.modulate = Color.RED
		status_label.text = "Permission denied. Click Start Speaking to try again."
		speak_button.disabled = false # Keep enabled for retry
		speak_button.text = "Try Again"
	else:
		# Permission not determined yet, will be requested when button is clicked
		mic_permission_granted = false
		permission_status_label.text = "! Need permission - click Start to grant"
		permission_status_label.modulate = Color.YELLOW
		status_label.text = "Click Start Speaking to grant microphone permission"
		speak_button.disabled = false
		speak_button.text = "Start Speaking"

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
			speak_button.text = "Start Speaking"
			speak_button.disabled = false
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
			speak_button.text = "Stop Recording"
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
					// Request microphone permission first
					const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
					console.log('Microphone permission granted');
					
					// Stop the permission stream immediately
					stream.getTracks().forEach(track => track.stop());
					
					// Create speech recognition instance
					const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
					window.currentRecognition = new SpeechRecognition();
					
					// Configure for live transcription with better accuracy settings
					window.currentRecognition.continuous = true;
					window.currentRecognition.interimResults = true;
					window.currentRecognition.lang = 'en-US';
					window.currentRecognition.maxAlternatives = 3;  // Get multiple alternatives for better accuracy
					
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
							
							// Process multiple alternatives for better accuracy
							if (result.length > 1) {
								let bestTranscript = transcript;
								let bestScore = result[0].confidence;
								
								for (let j = 1; j < result.length; j++) {
									const altTranscript = result[j].transcript.trim();
									const altConfidence = result[j].confidence;
									
									// Prefer word-like alternatives over numbers
									if (altConfidence > bestScore * 0.8 && !altTranscript.match(/^[0-9]+$/)) {
										bestTranscript = altTranscript;
										bestScore = altConfidence;
									}
								}
								transcript = bestTranscript;
							}
							
							// Clean transcript of non-letter characters (except spaces)
							transcript = cleanTranscriptForWords(transcript);
							
							console.log('Speech result:', transcript, 'Final:', isFinal, 'Confidence:', result[0].confidence);
							
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
						console.log('Speech recognition ended');
						try {
							const engine = window.godot?.getEngine?.() || window.engine || window.Module?.engine;
							if (engine && engine.call) {
								console.log('Calling Godot recognition_ended_callback...');
								engine.call('""" + str(get_path()) + """', 'recognition_ended_callback');
							}
						} catch (e) {
							console.error('Error calling Godot on end:', e);
						}
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
	print("Recognition ended callback received")
	if recognition_active:
		recognition_active = false
		live_transcription_enabled = false
		speak_button.text = "Start Speaking"
		speak_button.disabled = false
		status_label.text = "Recognition stopped. Click Start Speaking to try again."

# Callback function for speech recognition result from JavaScript
func speech_result_callback(text):
	print("SPEECH RECOGNITION CALLBACK: Received text from JavaScript: " + text)
	
	if text and text.length() > 0:
		print("CALLING RECOGNITION HANDLER with text: " + text)
		call_deferred("_on_speech_recognized", text)
	else:
		print("EMPTY RECOGNITION RESULT")
		status_label.text = "Could not understand speech"
		speak_button.text = "Start Speaking"
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
	
	# Display the improved single word
	var display_text = improved_text
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
			live_transcription_text.text = "✓ " + display_text + " (Perfect!)"
			print("Perfect match detected!")
		elif _is_phonetic_match(normalized_interim, normalized_target):
			live_transcription_text.modulate = Color.LIME
			live_transcription_text.text = "✓ " + display_text + " (Sounds right!)"
			print("Phonetic match detected!")
		elif _is_close_match(normalized_interim, normalized_target):
			live_transcription_text.modulate = Color.YELLOW
			live_transcription_text.text = "~ " + display_text + " (Close!)"
			print("Close match detected!")
		else:
			live_transcription_text.modulate = Color.WHITE
			live_transcription_text.text = "| " + display_text

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
	
	# Handle common phonetic variations for dyslexic learners - STRICTER FOR EDUCATION
	var phonetic_substitutions = {
		# Only allow very common sound confusions that don't change word meaning
		"bae": "bay", "bay": "bae",
		"dae": "day", "day": "dae", "dai": "day",
		"mae": "may", "may": "mae", "mai": "may",
		"wae": "way", "way": "wae", "wei": "way",
		"sae": "say", "say": "sae", "sei": "say",
		"lae": "lay", "lay": "lae", "lei": "lay",
		"pae": "pay", "pay": "pae", "pai": "pay",
		"rae": "ray", "ray": "rae", "rei": "ray",
		"hae": "hay", "hay": "hae", "hei": "hay",
		"jae": "jay", "jay": "jae", "jei": "jay",
		"fae": "fay", "fay": "fae", "fei": "fay",
		
		# REMOVED problematic pairs that teach wrong pronunciations:
		# No more "or"/"ore", "to"/"two", etc. - students must learn exact pronunciation
		
		# Only keep letter reversals for dyslexia (these don't change pronunciation)
		"bd": "db", "pq": "qp", "mn": "nm",
		"was": "saw", "no": "on", "net": "ten"
	}
	
	# Check if recognized text with phonetic correction matches target
	for wrong_sound in phonetic_substitutions.keys():
		var correct_sound = phonetic_substitutions[wrong_sound]
		if recognized_lower == wrong_sound and target_lower == correct_sound:
			print("Applied phonetic correction: " + wrong_sound + " -> " + correct_sound)
			return correct_sound
		elif recognized_lower == correct_sound and target_lower == wrong_sound:
			print("Applied reverse phonetic correction: " + correct_sound + " -> " + wrong_sound)
			return wrong_sound
	
	# Check for partial word phonetic matching
	var words = recognized_lower.split(" ")
	for i in range(words.size()):
		if words[i] in phonetic_substitutions:
			var corrected = phonetic_substitutions[words[i]]
			if _is_close_match(corrected, target_lower):
				words[i] = corrected
				print("Applied word-level phonetic correction: " + recognized_lower + " -> " + " ".join(words))
				return " ".join(words)
	
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

# Enhanced close match function for dyslexic-friendly recognition
func _is_close_match(word1, word2):
	# First check phonetic matching
	if _is_phonetic_match(word1, word2):
		return true
	
	var similarity = _calculate_word_similarity(word1, word2)
	
	# More lenient thresholds based on word length for dyslexic learners
	var threshold = 0.6 # Base threshold of 60%
	
	if word2.length() <= 3:
		threshold = 0.7 # 70% for short words (need to be more accurate)
	elif word2.length() <= 5:
		threshold = 0.65 # 65% for medium words
	else:
		threshold = 0.6 # 60% for longer words
	
	# Special case for very similar lengths (likely just pronunciation differences)
	if abs(word1.length() - word2.length()) <= 1:
		threshold -= 0.1 # More lenient by 10%
	
	return similarity > threshold

# Callback function for speech recognition error from JavaScript
func speech_error_callback(error):
	print("Speech recognition error: ", error)
	
	# Stop current recognition
	recognition_active = false
	live_transcription_enabled = false
	
	# Update UI based on error type
	if error == "not-allowed" or error == "permission-denied":
		status_label.text = "Microphone permission denied. Click 'Try Again' to retry."
		speak_button.text = "Try Again"
		permission_status_label.text = "X Permission denied"
		permission_status_label.modulate = Color.RED
	elif error == "no-speech":
		status_label.text = "No speech detected. Try speaking louder."
		speak_button.text = "Start Speaking"
		permission_status_label.text = "! No speech heard"
		permission_status_label.modulate = Color.YELLOW
	else:
		status_label.text = "Error: " + error + ". Click to try again."
		speak_button.text = "Try Again"
		permission_status_label.text = "X Recognition error"
		permission_status_label.modulate = Color.RED
	
	speak_button.disabled = false

# Function to calculate bonus damage based on player stats
func calculate_bonus_damage() -> int:
	# Get player's current damage from battle scene
	var battle_scene = get_node("/root/BattleScene")
	if battle_scene and battle_scene.has_method("get") and battle_scene.player_manager:
		var player_base_damage = battle_scene.player_manager.player_damage
		# Random bonus between 30% to 60% of base damage (reasonable range)
		var bonus_percent = randf_range(0.30, 0.60)
		var bonus_amount = int(player_base_damage * bonus_percent)
		# Ensure minimum bonus of 3 and reasonable maximum (not overpowered)
		bonus_amount = max(3, min(bonus_amount, int(player_base_damage * 0.75)))
		print("STT Challenge: Base damage: ", player_base_damage, " Bonus: ", bonus_amount, " Total: ", player_base_damage + bonus_amount)
		return bonus_amount # Return only the bonus, not base + bonus
	else:
		# Fallback to fixed value if battle scene not accessible
		return 8

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
	
	# 1. Exact match check
	if recognized_normalized == target_normalized:
		is_success = true
		match_type = "exact"
	
	# 2. Phonetic match check
	elif _is_phonetic_match(recognized_normalized, target_normalized):
		is_success = true
		match_type = "phonetic"
	
	# 3. Extract best word match from phrase
	elif " " in processed_text:
		var best_word = _extract_best_word_match(processed_text, challenge_word)
		if _is_phonetic_match(best_word.to_lower(), target_normalized) or best_word.to_lower() == target_normalized:
			is_success = true
			match_type = "word_extraction"
			recognized_normalized = best_word.to_lower()
	
	# 4. Fuzzy matching for longer words (more lenient for dyslexic learners)
	elif target_normalized.length() > 3 and recognized_normalized.length() > 2:
		var similarity = _calculate_word_similarity(recognized_normalized, target_normalized)
		# Increased threshold to 75% for better dyslexic support
		if similarity >= 0.75:
			is_success = true
			match_type = "fuzzy"
	
	# 5. Partial match for very close attempts
	elif _is_close_match(recognized_normalized, target_normalized):
		is_success = true
		match_type = "close"
	
	# Calculate bonus damage only if successful
	if is_success:
		bonus_damage = calculate_bonus_damage()
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
	
	# Set the result data - use "said" for the STT
	result_panel.set_result(text, challenge_word, is_success, bonus_damage, "said")
	
	# Connect the continue signal with an anonymous function
	result_panel.continue_pressed.connect(
		func():
			print("RESULT PANEL CONTINUE SIGNAL RECEIVED")
			if is_success:
				emit_signal("challenge_completed", bonus_damage)
			else:
				emit_signal("challenge_failed")
			queue_free() # Free our panel
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
		if target_word.length() <= 4: # Updated to handle 4-letter words better
			# For short words like "gate" or "blue", check for near-matches
			var distance = levenshtein_distance(word, target_word)
			if distance <= 1: # Allow 1 character difference for short words
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