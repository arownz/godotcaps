extends Control

# Core systems
var tts: TextToSpeech = null
var tts_speaking = false # Track TTS speaking state manually
var module_progress = null
var current_passage_index: int = 0
var is_reading: bool = false
var current_sentence_index: int = 0
var reading_speed: float = 150.0 # words per minute
var completed_activities: Array = [] # Track completed guided reading activities
var completed_sentences: Array = [] # Track completed sentences in current passage

# STT functionality - Enhanced from WordChallengePanel_STT.gd
var recognition_active = false
var mic_permission_granted = false
var permission_check_complete = false
var current_target_sentence = ""
var stt_feedback_active = false
var stt_listening = false
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

# Live word highlighting for STT feedback
var highlighted_words = []
var current_spoken_words = []
var sentence_words = []

# TTS timer fallback
var use_timer_fallback_for_tts = false
var tts_timer: Timer = null

# Highlighting reset timer for partial speech
var highlighting_reset_timer: Timer = null

# Completion celebration system
var completion_celebration: CanvasLayer = null

# Guided Reading Passages - dyslexia-friendly with structured guidance 4/4
var passages = [
    {
        "title": "The Friendly Cat",
        "text": "Mia owns one cheerful cat named Sam. Sam has orange fur with white patches. Sam enjoys chasing one red ball around the room. Mia feeds Sam meals each day. Sam feels joyful and content.",
        "sentences": [
            "Mia owns one cheerful cat named Sam.",
            "Sam has orange fur with white patches.",
            "Sam enjoys chasing one red ball around the room.",
            "Mia feeds Sam meals each day.",
            "Sam feels joyful and content."
        ],
        "guide_notes": [
            "Read about Mia and her cheerful pet.",
            "Notice color words: orange, white, red.",
            "Look for action words: enjoys, chasing, feeds.",
            "Each sentence reveals something new about Sam.",
            "Consider how Sam feels by the end."
        ],
        "vocabulary": [
            {"word": "joyful", "definition": "feeling very happy and pleased"}
        ],
        "level": 1
    },
    {
        "title": "The Garden Surprise",
        "text": "Ben placed seeds into soil within his backyard garden. He poured water over them daily. Tiny green sprouts began growing. After several weeks, large red tomatoes appeared. Ben gathered them for supper.",
        "sentences": [
            "Ben placed seeds into soil within his backyard garden.",
            "He poured water over them daily.",
            "Tiny green sprouts began growing.",
            "After several weeks, large red tomatoes appeared.",
            "Ben gathered them for supper."
        ],
        "guide_notes": [
            "This story teaches patience and plant care.",
            "Notice time phrases: daily, several weeks.",
            "Observe growth stages: seeds, sprouts, tomatoes.",
            "Hard work leads to tasty rewards.",
            "Think about meals Ben might prepare."
        ],
        "vocabulary": [
            {"word": "gathered", "definition": "collected or picked up"}
        ],
        "level": 1
    },
    {
        "title": "The School Bus",
        "text": "Each morning, Lisa waits beside the road for her yellow school bus. The driver, Mr. Joe, waves with a smile. Lisa sits beside her friend Emma. They chat about favorite stories. Once they reach school, both girls feel eager to learn.",
        "sentences": [
            "Each morning, Lisa waits beside the road for her yellow school bus.",
            "The driver, Mr. Joe, waves with a smile.",
            "Lisa sits beside her friend Emma.",
            "They chat about favorite stories.",
            "Once they reach school, both girls feel eager to learn."
        ],
        "guide_notes": [
            "This story shows daily habits and friendship.",
            "Notice friendly people: Lisa, Mr. Joe, Emma.",
            "Think about routines followed each morning.",
            "Friends enjoy chatting together.",
            "Consider how school makes them feel."
        ],
        "vocabulary": [
            {"word": "eager", "definition": "excited and ready to do something"}
        ],
        "level": 2
    },
    {
        "title": "The Rainy Plan",
        "text": "Thick clouds filled the sky during Saturday morning. Rain started falling gently. Maria and her brother Carlos stayed indoors. They built one blanket fort using chairs. Inside their fort, both siblings read stories and laughed together.",
        "sentences": [
            "Thick clouds filled the sky during Saturday morning.",
            "Rain started falling gently.",
            "Maria and her brother Carlos stayed indoors.",
            "They built one blanket fort using chairs.",
            "Inside their fort, both siblings read stories and laughed together."
        ],
        "guide_notes": [
            "This story shows creative fun during rainy weather.",
            "Notice weather phrases: thick clouds, rain, gently.",
            "Look for descriptive words: thick, gently, cozy.",
            "Think about indoor activities during storms.",
            "See how teamwork brings joy."
        ],
        "vocabulary": [
            {"word": "sibling", "definition": "a brother or sister"}
        ],
        "level": 2
    }
]

func _ready():
	print("ReadAloudGuided: Initializing guided reading interface")
	
	# Enhanced fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Initialize components
	_init_tts()
	_init_module_progress()
	_init_completion_celebration()
	
#	# Connect button events
	_connect_button_events()
	
	# Initialize STT
	_setup_speech_recognition()
	
	# Load progress first, then setup display at resumed position
	await _load_progress()
	_setup_initial_display()

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)

	# Load TTS settings for dyslexia-friendly reading
	var voice_id = SettingsManager.get_setting("accessibility", "tts_voice_id")
	var rate = SettingsManager.get_setting("accessibility", "tts_rate")
	
	if voice_id != null and voice_id != "":
		tts.set_voice(voice_id)
	if rate != null:
		tts.set_rate(rate)
	
	# Connect TTS finished signal for guided reading flow
	if tts:
		# Check what signals are available and connect the appropriate one
		if tts.has_signal("utterance_finished"):
			tts.utterance_finished.connect(_on_tts_finished)
			print("ReadAloudGuided: Connected to utterance_finished signal")
		elif tts.has_signal("finished"):
			tts.finished.connect(_on_tts_finished)
			print("ReadAloudGuided: Connected to finished signal")
		elif tts.has_signal("speaking_finished"):
			tts.speaking_finished.connect(_on_tts_finished)
			print("ReadAloudGuided: Connected to speaking_finished signal")
		else:
			print("ReadAloudGuided: No suitable TTS finished signal found")
			use_timer_fallback_for_tts = true
	
	# ALWAYS create a backup timer to ensure button resets even if TTS signals fail
	tts_timer = Timer.new()
	tts_timer.one_shot = true
	add_child(tts_timer)
	tts_timer.timeout.connect(_on_tts_finished)
	print("ReadAloudGuided: Created backup TTS timer")
	
	# Create highlighting reset timer for partial speech detection
	highlighting_reset_timer = Timer.new()
	highlighting_reset_timer.one_shot = true
	add_child(highlighting_reset_timer)
	highlighting_reset_timer.timeout.connect(_on_highlighting_reset_timeout)
	print("ReadAloudGuided: Created highlighting reset timer")

func _init_module_progress():
	if Firebase and Firebase.Auth and Firebase.Auth.auth:
		module_progress = ModuleProgress.new()
		print("ReadAloudGuided: ModuleProgress initialized")
	else:
		print("ReadAloudGuided: Firebase not available, using local tracking")

func _init_completion_celebration():
	"""Initialize completion celebration system"""
	var celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")
	completion_celebration = celebration_scene.instantiate()
	add_child(completion_celebration)
	
	# Connect celebration signals
	completion_celebration.try_again_pressed.connect(_on_celebration_try_again)
	completion_celebration.next_item_pressed.connect(_on_celebration_next)
	completion_celebration.closed.connect(_on_celebration_closed)
	print("ReadAloudGuided: Completion celebration initialized")

func _connect_button_events():
	"""Connect all button events with hover sounds"""
	var buttons = [
		$MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton,
		$MainContainer/HeaderPanel/GuideButton,
		$MainContainer/HeaderPanel/TTSSettingButton,
		$MainContainer/ControlsContainer/PreviousButton,
		$MainContainer/PassagePanel/ReadButton,
		$MainContainer/ControlsContainer/SpeakButton,
		$MainContainer/ControlsContainer/NextButton
	]
	
	for button in buttons:
		if button and not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)

func _setup_speech_recognition():
	"""Initialize speech recognition for web platform"""
	if OS.get_name() == "Web":
		_initialize_web_audio_environment()
		call_deferred("_check_and_wait_for_permissions")

func _process(_delta):
	"""Check for speech recognition results - Enhanced polling for continuous listening"""
	if stt_listening and OS.get_name() == "Web" and JavaScriptBridge.has_method("eval"):
		# Check for interim results with improved polling for continuous listening
		var interim_js = """
		(function() {
			if (window.guidedInterimResult) {
				var result = window.guidedInterimResult;
				window.guidedInterimResult = '';
				return result;
			}
			return '';
		})();
		"""
		var interim_result = JavaScriptBridge.eval(interim_js)
		if interim_result != null and str(interim_result) != "null" and str(interim_result) != "":
			var text_str = str(interim_result).strip_edges()
			if text_str != "":
				_process_interim_transcription(text_str)
		
		# Check for final results with enhanced handling
		var final_js = """
		(function() {
			if (window.guidedFinalResult) {
				var result = window.guidedFinalResult;
				window.guidedFinalResult = '';
				return result;
			}
			return '';
		})();
		"""
		var final_result = JavaScriptBridge.eval(final_js)
		if final_result != null and str(final_result) != "null" and str(final_result) != "":
			var text_str = str(final_result).strip_edges()
			if text_str != "" and not result_being_processed:
				print("ReadAloudGuided: Final result received: ", text_str)
				_process_speech_result(text_str, 1.0)
	
	# Safeguard: Check if TTS has been speaking too long and reset button if needed
	_check_tts_button_state()

func _check_tts_button_state():
	"""Safeguard function to ensure Read button doesn't get stuck"""
	var read_button = $MainContainer/PassagePanel/ReadButton
	if read_button and tts_speaking:
		# Check if TTS has been speaking for more than 30 seconds (way too long)
		if tts_timer and tts_timer.is_stopped():
			print("ReadAloudGuided: TTS timer stopped but button still stuck - resetting")
			tts_speaking = false
			read_button.text = "Read"
			read_button.disabled = false
			read_button.modulate = Color.WHITE

func _initialize_web_audio_environment():
	"""Initialize JavaScript environment for web audio - FIXED ENGINE DETECTION"""
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
		// Check if functions already exist to avoid redefinition
		if (typeof window.guidedRecognition === 'undefined') {
			// Global speech recognition variables
			window.guidedRecognition = null;
			window.guidedRecognitionActive = false;
			window.guidedPermissionGranted = false;
			window.guidedPermissionChecked = false;
			window.guidedFinalResult = '';
			window.guidedInterimResult = '';
			window.guidedResult = null;
			
			// Permission check function
			window.checkGuidedPermissions = function() {
				if (navigator.permissions) {
					navigator.permissions.query({name: 'microphone'}).then(function(result) {
						window.guidedPermissionGranted = (result.state === 'granted');
						window.guidedPermissionChecked = true;
						console.log('ReadAloudGuided: Permission state:', result.state);
					}).catch(function(error) {
						console.log('ReadAloudGuided: Permission check failed:', error);
						window.guidedPermissionChecked = true;
					});
				} else {
					// Fallback for browsers without permission API
					window.guidedPermissionChecked = true;
				}
			};
			
			// Request microphone permission
			window.requestGuidedMicPermission = function() {
				return navigator.mediaDevices.getUserMedia({ audio: true })
					.then(function(stream) {
						window.guidedPermissionGranted = true;
						stream.getTracks().forEach(track => track.stop()); // Clean up
						return true;
					})
					.catch(function(error) {
						console.log('ReadAloudGuided: Permission denied:', error);
						window.guidedPermissionGranted = false;
						return false;
					});
			};
			
			// Initialize speech recognition
			window.initGuidedSpeechRecognition = function() {
				try {
					if ('webkitSpeechRecognition' in window) {
						window.guidedRecognition = new webkitSpeechRecognition();
					} else if ('SpeechRecognition' in window) {
						window.guidedRecognition = new SpeechRecognition();
					} else {
						console.log('ReadAloudGuided: Speech recognition not supported');
						return false;
					}
					
					var recognition = window.guidedRecognition;
					recognition.continuous = true; // Enable continuous recognition for dyslexic users
					recognition.interimResults = true;
					recognition.lang = 'en-US';
					recognition.maxAlternatives = 1;
					
					recognition.onstart = function() {
						console.log('ReadAloudGuided: Recognition started');
						window.guidedRecognitionActive = true;
						window.guidedFinalResult = '';
						window.guidedInterimResult = '';
					};
					
					recognition.onresult = function(event) {
						var finalTranscript = '';
						var interimTranscript = '';
						
						for (var i = event.resultIndex; i < event.results.length; i++) {
							var transcript = event.results[i][0].transcript;
							if (event.results[i].isFinal) {
								finalTranscript += transcript;
							} else {
								interimTranscript += transcript;
							}
						}
						
						window.guidedFinalResult = finalTranscript;
						window.guidedInterimResult = interimTranscript;
						
						// Enhanced console logging for user feedback
						if (interimTranscript.trim() !== '') {
							console.log('ReadAloudGuided: LIVE SPEECH: "' + interimTranscript + '"');
						}
						if (finalTranscript.trim() !== '') {
							console.log('ReadAloudGuided: FINAL RESULT: "' + finalTranscript + '"');
						}
					};
					
					recognition.onerror = function(event) {
						console.log('ReadAloudGuided: Recognition error:', event.error);
						window.guidedRecognitionActive = false;
						
						// Store error result
						window.guidedResult = {
							type: 'error',
							error: event.error,
							timestamp: Date.now()
						};
					};
					
					recognition.onend = function() {
						console.log('ReadAloudGuided: Recognition ended');
						window.guidedRecognitionActive = false;
						
						// Store final result if we have one
						if (window.guidedFinalResult && window.guidedFinalResult.trim() !== '') {
							window.guidedResult = {
								type: 'result',
								text: window.guidedFinalResult.trim(),
								timestamp: Date.now()
							};
						}
						
						// Auto-restart for continuous listening if still active
						if (window.guidedContinuousMode && !window.guidedStopRequested) {
							console.log('ReadAloudGuided: Auto-restarting recognition for continuous mode');
							setTimeout(function() {
								try {
									window.guidedRecognition.start();
								} catch (error) {
									console.log('ReadAloudGuided: Failed to auto-restart:', error);
								}
							}, 100);
						}
					};
					
					return true;
				} catch (error) {
					console.log('ReadAloudGuided: Failed to initialize recognition:', error);
					return false;
				}
			};
			
			// Start recognition
			window.startGuidedRecognition = function() {
				// Ensure recognition is initialized before starting
				if (!window.guidedRecognition) {
					console.log('ReadAloudGuided: Recognition not initialized, initializing now...');
					if (!window.initGuidedSpeechRecognition()) {
						console.log('ReadAloudGuided: Failed to initialize recognition');
						return false;
					}
				}
				
				if (window.guidedRecognitionActive) {
					console.log('ReadAloudGuided: Recognition already active, returning true for existing session');
					return true; // Return true since recognition is already running
				}
				
				try {
					window.guidedResult = null; // Clear previous result
					window.guidedContinuousMode = true; // Enable continuous mode for dyslexic users
					window.guidedStopRequested = false; // Reset stop flag
					window.guidedRecognition.start();
					return true;
				} catch (error) {
					console.log('ReadAloudGuided: Failed to start recognition:', error);
					return false;
				}
			};
			
			// Stop recognition
			window.stopGuidedRecognition = function() {
				console.log('ReadAloudGuided: Stopping recognition...');
				window.guidedStopRequested = true; // Prevent auto-restart
				window.guidedContinuousMode = false; // Disable continuous mode
				if (window.guidedRecognition && window.guidedRecognitionActive) {
					try {
						window.guidedRecognition.stop();
						console.log('ReadAloudGuided: Recognition stopped successfully');
					} catch (error) {
						console.log('ReadAloudGuided: Error stopping recognition:', error);
					}
				}
				// Force state reset to prevent stuck states
				window.guidedRecognitionActive = false;
				window.guidedFinalResult = '';
				window.guidedInterimResult = '';
			};
			
			// Get recognition result
			window.getGuidedResult = function() {
				if (window.guidedResult) {
					var result = window.guidedResult;
					window.guidedResult = null; // Clear after reading
					return JSON.stringify(result);
				}
				return null;
			};
			
			// Get interim result for live feedback
			window.getGuidedInterimResult = function() {
				return window.guidedInterimResult || '';
			};
			
			// Check if recognition is active
			window.isGuidedRecognitionActive = function() {
				return window.guidedRecognitionActive || false;
			};
			
			// Initialize everything
			window.checkGuidedPermissions();
			var initResult = window.initGuidedSpeechRecognition();
			console.log('ReadAloudGuided: Initialization complete:', initResult);
		} else {
			console.log('ReadAloudGuided: JavaScript functions already initialized');
		}
		"""
		
		JavaScriptBridge.eval(js_code)
		print("ReadAloudGuided: JavaScript environment initialized for web speech recognition")

func _check_and_wait_for_permissions():
	"""Check microphone permissions"""
	print("ReadAloudGuided: Checking microphone permissions...")
	permission_check_complete = false
	
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
		(function() {
			if (typeof window.checkGuidedPermissions === 'function') {
				window.checkGuidedPermissions();
				
				// Wait for permission check to complete
				var checkInterval = setInterval(function() {
					if (window.guidedPermissionChecked) {
						clearInterval(checkInterval);
						console.log('ReadAloudGuided: Permission granted:', window.guidedPermissionGranted);
					}
				}, 50);
			} else {
				console.log('ReadAloudGuided: checkGuidedPermissions function not available');
			}
		})();
		"""
		JavaScriptBridge.eval(js_code)
		
		# Wait for permission check to complete
		var max_wait_time = 3.0
		var wait_time = 0.0
		while not permission_check_complete and wait_time < max_wait_time:
			await get_tree().process_frame
			wait_time += 0.016 # Approximate frame time
			
			# Check permission status from JavaScript
			if JavaScriptBridge.has_method("eval"):
				var permission_status = JavaScriptBridge.eval("window.guidedPermissionChecked || false")
				if permission_status:
					var granted = JavaScriptBridge.eval("window.guidedPermissionGranted || false")
					update_mic_permission_state("granted" if granted else "prompt")
					break
		
		print("ReadAloudGuided: Permission check completed. Granted: ", mic_permission_granted)

func update_mic_permission_state(state):
	"""Callback for permission state updates"""
	permission_check_complete = true
	if state == "granted":
		mic_permission_granted = true
		print("ReadAloudGuided: Microphone permission granted")
		
		# Initialize speech recognition immediately after permission is granted
		if JavaScriptBridge.has_method("eval"):
			var init_result = JavaScriptBridge.eval("window.initGuidedSpeechRecognition && window.initGuidedSpeechRecognition()")
			if init_result:
				print("ReadAloudGuided: Speech recognition initialized successfully")
			else:
				print("ReadAloudGuided: Failed to initialize speech recognition")
	else:
		mic_permission_granted = false
		print("ReadAloudGuided: Microphone permission: ", state)

func _start_speech_recognition():
	"""Start speech recognition with enhanced conflict prevention"""
	print("ReadAloudGuided: Starting speech recognition...")
	
	# Enhanced check: Force stop any existing recognition first
	if OS.get_name() == "Web" and JavaScriptBridge.has_method("eval"):
		var js_active = JavaScriptBridge.eval("window.guidedRecognitionActive || false")
		if js_active or recognition_active or stt_listening:
			print("ReadAloudGuided: Recognition already active, forcing stop before restart")
			_force_stop_recognition()
			# Small delay to ensure cleanup
			await get_tree().create_timer(0.1).timeout
	
	if not mic_permission_granted:
		print("ReadAloudGuided: Requesting microphone permission...")
		_request_microphone_permission()
		return false
	
	if OS.get_name() == "Web":
		if JavaScriptBridge.has_method("eval"):
			var result = JavaScriptBridge.eval("window.startGuidedRecognition && window.startGuidedRecognition()")
			if result:
				recognition_active = true
				stt_listening = true
				_update_listen_button()
				print("ReadAloudGuided: Speech recognition started successfully")
				return true
			else:
				print("ReadAloudGuided: Failed to start web speech recognition")
	
	return false

func _force_stop_recognition():
	"""Force stop recognition to prevent conflicts"""
	print("ReadAloudGuided: Force stopping any active recognition...")
	
	if OS.get_name() == "Web" and JavaScriptBridge.has_method("eval"):
		# Force stop with enhanced cleanup
		var js_code = """
		(function() {
			if (window.guidedRecognition) {
				try {
					window.guidedRecognition.stop();
					window.guidedRecognition.abort(); // Force abort to release microphone
					window.guidedRecognition = null; // Critical: Set to null
					console.log('ReadAloudGuided: Force stopped and cleaned up recognition');
				} catch (error) {
					console.log('ReadAloudGuided: Error in force stop:', error);
				}
			}
			// Force state reset
			window.guidedRecognitionActive = false;
			window.guidedStopRequested = true;
			window.guidedContinuousMode = false;
			window.guidedFinalResult = '';
			window.guidedInterimResult = '';
			return true;
		})();
		"""
		JavaScriptBridge.eval(js_code)
	
	# Reset all local state
	recognition_active = false
	stt_listening = false
	stt_feedback_active = false
	result_being_processed = false
	
	# Stop timers
	if highlighting_reset_timer and not highlighting_reset_timer.is_stopped():
		highlighting_reset_timer.stop()
	
	_update_listen_button()
	print("ReadAloudGuided: Force stop completed")

func _stop_speech_recognition():
	"""Stop speech recognition with comprehensive cleanup"""
	print("ReadAloudGuided: Stopping speech recognition...")
	
	# Stop highlighting reset timer when manually stopping STT
	if highlighting_reset_timer and not highlighting_reset_timer.is_stopped():
		highlighting_reset_timer.stop()
		print("ReadAloudGuided: Stopped highlighting reset timer - STT manually stopped")
	
	if OS.get_name() == "Web":
		if JavaScriptBridge.has_method("eval"):
			# Use the same cleanup pattern as WordChallengePanel_STT
			var js_code = """
				(function() {
					if (window.guidedRecognition) {
						console.log('ReadAloudGuided: Stopping recognition...');
						window.guidedStopRequested = true; // Prevent auto-restart
						window.guidedContinuousMode = false; // Disable continuous mode
						try {
							window.guidedRecognition.stop();
							window.guidedRecognition.abort(); // Force abort to release microphone
						} catch (error) {
							console.log('ReadAloudGuided: Error stopping recognition:', error);
						}
						// Critical: Set to null to allow new recognition instances
						window.guidedRecognition = null;
						console.log('ReadAloudGuided: Recognition stopped and cleaned up');
						return true;
					}
					// Force state reset even if no recognition
					window.guidedRecognitionActive = false;
					window.guidedFinalResult = '';
					window.guidedInterimResult = '';
					console.log('ReadAloudGuided: State reset completed');
					return false;
				})();
			"""
			var _result = JavaScriptBridge.eval(js_code)
	
	# Reset all STT-related state
	recognition_active = false
	stt_listening = false
	stt_feedback_active = false
	live_transcription_enabled = false
	result_being_processed = false
	
	# Clear interim results
	current_interim_result = ""
	last_interim_result = ""
	
	_update_listen_button()
	print("ReadAloudGuided: Speech recognition stopped and state reset")

func _request_microphone_permission():
	"""Request microphone permission"""
	print("ReadAloudGuided: Requesting microphone permission...")
	permission_check_complete = false
	
	if JavaScriptBridge.has_method("eval"):
		var request_js = """
		(function() {
			if (typeof window.requestGuidedMicPermission === 'function') {
				window.requestGuidedMicPermission().then(function(granted) {
					window.guidedPermissionGranted = granted;
					window.guidedPermissionChecked = true;
					console.log('ReadAloudGuided: Permission request result:', granted);
				});
			} else {
				console.log('ReadAloudGuided: requestGuidedMicPermission function not available');
				window.guidedPermissionChecked = true;
			}
		})();
		"""
		JavaScriptBridge.eval(request_js)
		
		# Wait for permission request to complete
		var max_wait_time = 5.0
		var wait_time = 0.0
		while not permission_check_complete and wait_time < max_wait_time:
			await get_tree().process_frame
			wait_time += 0.016
			
			# Check permission status from JavaScript
			if JavaScriptBridge.has_method("eval"):
				var permission_checked = JavaScriptBridge.eval("window.guidedPermissionChecked || false")
				if permission_checked:
					var granted = JavaScriptBridge.eval("window.guidedPermissionGranted || false")
					update_mic_permission_state("granted" if granted else "denied")
					break
		
		print("ReadAloudGuided: Permission request completed. Granted: ", mic_permission_granted)

func speech_result_callback(text, confidence):
	"""Callback for speech recognition results"""
	if stt_feedback_active:
		_process_speech_result(text, confidence)

func speech_error_callback(error):
	"""Callback for speech recognition errors"""
	print("ReadAloudGuided: Speech recognition error: ", error)
	recognition_active = false

func recognition_ended_callback():
	"""Callback when recognition ends"""
	recognition_active = false

func _process_speech_result(recognized_text: String, confidence: float):
	"""Process speech recognition result and compare with target sentence - Enhanced for dyslexic users"""
	
	# Check if current sentence is already completed
	if current_sentence_index in completed_sentences:
		print("ReadAloudGuided: Current sentence ", current_sentence_index, " already completed, ignoring STT input")
		return
	
	# Prevent double processing during continuous listening
	if result_being_processed:
		print("ReadAloudGuided: Result already being processed, skipping...")
		return
	
	result_being_processed = true
	print("ReadAloudGuided: Recognized: '", recognized_text, "' (confidence: ", confidence, ")")
	print("ReadAloudGuided: Target: '", current_target_sentence, "'")
	
	# Enhanced text processing pipeline like WordChallengePanel_STT
	var processed_text = recognized_text
	
	# Step 1: Convert numbers to words
	processed_text = _convert_numbers_to_words(processed_text)
	
	# Step 2: Clean text (remove non-letters except spaces)
	processed_text = _clean_text_for_words(processed_text)
	
	# Step 3: Apply phonetic improvements for dyslexic-friendly recognition
	processed_text = _apply_phonetic_improvements(processed_text, current_target_sentence)
	
	# Step 4: Normalize for comparison
	var recognized_normalized = processed_text.to_lower().strip_edges()
	var target_normalized = current_target_sentence.to_lower().strip_edges()
	
	print("ReadAloudGuided: Enhanced processing pipeline:")
	print("  Original: '", recognized_text, "'")
	print("  After numbers->words: '", _convert_numbers_to_words(recognized_text), "'")
	print("  After cleaning: '", _clean_text_for_words(_convert_numbers_to_words(recognized_text)), "'")
	print("  After phonetic: '", processed_text, "'")
	print("  Final normalized: '", recognized_normalized, "'")
	print("  Target: '", target_normalized, "'")
	
	# Enhanced similarity calculation for sentences
	var similarity = _calculate_enhanced_sentence_similarity(recognized_normalized, target_normalized)
	print("ReadAloudGuided: Enhanced similarity score: ", similarity)
	
	# More forgiving thresholds for dyslexic learners
	if similarity >= 0.8: # 80% similarity - excellent match
		_show_success_feedback(recognized_text)
	elif similarity >= 0.65: # 65% similarity - good attempt, encourage
		_show_encouragement_feedback(recognized_text, current_target_sentence)
	elif similarity >= 0.4: # 40% similarity - partial match, guide them
		_show_partial_match_feedback(recognized_text, current_target_sentence)
	else:
		_show_try_again_feedback(recognized_text, current_target_sentence)
	
	# Reset processing flag for continuous listening
	result_being_processed = false

func _convert_numbers_to_words(text: String) -> String:
	"""Convert numbers to words for better speech recognition matching"""
	var number_map = {
		"0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
		"5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine",
		"10": "ten", "11": "eleven", "12": "twelve", "13": "thirteen", "14": "fourteen",
		"15": "fifteen", "16": "sixteen", "17": "seventeen", "18": "eighteen", "19": "nineteen",
		"20": "twenty", "30": "thirty", "40": "forty", "50": "fifty"
	}
	
	var result = text
	for num in number_map.keys():
		result = result.replace(num, number_map[num])
	
	return result

func _clean_text_for_words(text: String) -> String:
	"""Clean text and keep only letters and spaces"""
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z ]")
	var cleaned = regex.sub(text, "", true)
	
	# Normalize multiple spaces to single space
	var space_regex = RegEx.new()
	space_regex.compile("[ ]+")
	cleaned = space_regex.sub(cleaned, " ", true)
	
	return cleaned.strip_edges()

func _apply_phonetic_improvements(recognized_text: String, target_sentence: String) -> String:
	"""Apply enhanced phonetic improvements for dyslexic-friendly STT recognition"""
	if recognized_text.is_empty() or target_sentence.is_empty():
		return recognized_text
	
	var target_lower = target_sentence.to_lower().strip_edges()
	var recognized_lower = recognized_text.to_lower().strip_edges()
	
	# ENHANCED phonetic substitutions for STT mistakes and dyslexic users
	var phonetic_substitutions = {
		# Common STT confusions
		"to": "two", "too": "two", "for": "four", "fore": "four", "ate": "eight",
		"one": "won", "sun": "son", "no": "know", "there": "their", "wear": "where",
		"right": "write", "night": "knight", "sea": "see", "be": "bee",
		
		# STT system mistakes that disadvantage dyslexic users
		"cut": "cat", "cap": "cat", "bat": "cat", "rat": "cat", "mat": "cat",
		"dog": "god", "bog": "dog", "log": "dog", "fog": "dog",
		"saw": "was", "now": "won", "tap": "pat", "top": "pot", "pit": "tip", "net": "ten",
		
		# Dyslexic common letter reversals and confusions
		"left": "felt", "felt": "left", "form": "from", "from": "form",
		"trail": "trial", "trial": "trail", "unite": "untie", "untie": "unite",
		
		# Common sight word confusions
		"them": "then", "then": "them", "were": "where", "what": "want", "want": "what",
		"with": "wish", "wish": "with",
		
		# Phonetically similar words that STT often confuses
		"red": "read", "read": "red", "call": "ball", "play": "pray", "pray": "play",
		"happy": "happen", "happen": "happy", "garden": "guardian", "planted": "plant",
		"watered": "water", "yellow": "fellow", "school": "cool", "morning": "mourning"
	}
	
	# Enhanced bidirectional substitution system
	var target_words = target_lower.split(" ")
	var recognized_words = recognized_lower.split(" ")
	var improved_words = []
	
	for rec_word in recognized_words:
		rec_word = rec_word.strip_edges()
		var best_match = rec_word
		var best_similarity = 0.0
		
		# First check direct phonetic substitutions
		if rec_word in phonetic_substitutions:
			var substituted = phonetic_substitutions[rec_word]
			for target_word in target_words:
				if target_word == substituted:
					best_match = substituted
					best_similarity = 1.0
					break
		
		# If no direct substitution found, check similarity with target words
		if best_similarity < 1.0:
			for target_word in target_words:
				# Calculate phonetic similarity
				var similarity = _calculate_word_phonetic_similarity(rec_word, target_word)
				if similarity > best_similarity and similarity >= 0.6: # 60% threshold for STT tolerance
					best_match = target_word
					best_similarity = similarity
		
		improved_words.append(best_match)
		
		if best_match != rec_word:
			print("ReadAloudGuided: STT Correction - '", rec_word, "' -> '", best_match, "' (similarity: ", best_similarity, ")")
	
	return " ".join(improved_words)

func _calculate_word_phonetic_similarity(word1: String, word2: String) -> float:
	"""Calculate enhanced phonetic similarity for STT tolerance"""
	if word1 == word2:
		return 1.0
	
	# Phonetic transformations for better matching
	var phonetic1 = _apply_phonetic_normalization(word1)
	var phonetic2 = _apply_phonetic_normalization(word2)
	
	# Calculate Levenshtein similarity
	var distance = levenshtein_distance(phonetic1, phonetic2)
	var max_length = max(phonetic1.length(), phonetic2.length())
	var base_similarity = 1.0 - (float(distance) / max_length) if max_length > 0 else 0.0
	
	# Bonus for similar sounds (especially helpful for dyslexic users)
	var sound_bonus = 0.0
	if _have_similar_sounds(word1, word2):
		sound_bonus = 0.15 # 15% bonus for similar phonetic patterns
	
	# Bonus for same length (STT often preserves syllable count)
	var length_bonus = 0.0
	if abs(word1.length() - word2.length()) <= 1:
		length_bonus = 0.1 # 10% bonus for similar length
	
	return min(base_similarity + sound_bonus + length_bonus, 1.0)

func _apply_phonetic_normalization(word: String) -> String:
	"""Apply phonetic normalization to improve matching"""
	var normalized = word.to_lower()
	
	# Common sound substitutions for better STT tolerance
	var sound_mappings = {
		"ph": "f", "gh": "f", "ck": "k", "qu": "kw",
		"c": "k", "x": "ks", "y": "i", "tion": "shun",
		"sion": "shun", "ough": "uff", "augh": "aff"
	}
	
	for sound in sound_mappings.keys():
		normalized = normalized.replace(sound, sound_mappings[sound])
	
	return normalized

func _have_similar_sounds(word1: String, word2: String) -> bool:
	"""Check if words have similar phonetic patterns"""
	var w1 = word1.to_lower()
	var w2 = word2.to_lower()
	
	# Check for similar starting sounds
	if w1.length() > 0 and w2.length() > 0:
		if w1[0] == w2[0]: # Same first letter
			return true
	
	# Check for similar ending sounds
	if w1.length() > 1 and w2.length() > 1:
		if w1.substr(w1.length() - 2) == w2.substr(w2.length() - 2): # Same last 2 letters
			return true
	
	# Check for rhyming patterns (same ending sounds)
	var common_endings = ["ing", "ed", "er", "ly", "tion", "ness", "ment"]
	for ending in common_endings:
		if w1.ends_with(ending) and w2.ends_with(ending):
			return true
	
	return false

func _calculate_enhanced_sentence_similarity(text1: String, text2: String) -> float:
	"""Calculate enhanced similarity with maximum forgiveness for dyslexic learners and STT mistakes"""
	var words1 = text1.split(" ")
	var words2 = text2.split(" ")
	
	if words2.size() == 0:
		return 0.0
	
	var exact_matches = 0
	var phonetic_matches = 0
	var partial_matches = 0
	
	# Enhanced matching system with multiple levels of forgiveness
	for word1 in words1:
		var best_match_score = 0.0
		var matched = false
		
		for word2 in words2:
			if word1 == word2:
				# Perfect match
				exact_matches += 1
				matched = true
				break
			elif _is_phonetic_match(word1, word2):
				# Strong phonetic match
				if not matched:
					phonetic_matches += 1
					matched = true
			else:
				# Check for partial/similar match
				var similarity = _calculate_word_phonetic_similarity(word1, word2)
				if similarity > best_match_score:
					best_match_score = similarity
		
		# Count partial matches (60%+ similarity)
		if not matched and best_match_score >= 0.6:
			partial_matches += 1
	
	# Calculate weighted similarity score (very forgiving for dyslexic users)
	var exact_score = float(exact_matches) / float(words2.size())
	var phonetic_score = float(phonetic_matches) / float(words2.size()) * 0.85 # 85% value
	var partial_score = float(partial_matches) / float(words2.size()) * 0.65 # 65% value
	
	var total_similarity = exact_score + phonetic_score + partial_score
	
	# Bonus for length similarity (STT often gets word count right)
	var length_bonus = 0.0
	var length_ratio = min(words1.size(), words2.size()) / float(max(words1.size(), words2.size()))
	if length_ratio >= 0.8: # 80% or more words present
		length_bonus = 0.1 # 10% bonus
	
	# Final forgiveness: if user got most of the content, be very generous
	var final_score = min(total_similarity + length_bonus, 1.0)
	
	print("ReadAloudGuided: Similarity breakdown - Exact:", exact_matches, " Phonetic:", phonetic_matches, " Partial:", partial_matches, " Final:", final_score)
	
	return final_score

func _is_phonetic_match(word1: String, word2: String) -> bool:
	"""Check if two words are phonetically similar"""
	if word1 == word2:
		return true
	
	# Calculate Levenshtein distance for similarity
	var distance = levenshtein_distance(word1, word2)
	var max_length = max(word1.length(), word2.length())
	var similarity = 1.0 - (float(distance) / max_length) if max_length > 0 else 0.0
	
	# More lenient threshold for phonetic matching (75% similarity)
	return similarity >= 0.75

func levenshtein_distance(s1: String, s2: String) -> int:
	"""Calculate Levenshtein distance between two strings"""
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
			var cost = 0 if s1[i - 1] == s2[j - 1] else 1
			d[i][j] = min(
				d[i - 1][j] + 1, # deletion
				min(d[i][j - 1] + 1, # insertion
				d[i - 1][j - 1] + cost) # substitution
			)
	
	return d[m][n]

# TTS finished handler for guided reading flow
func _on_tts_finished():
	"""Called when TTS finishes reading a sentence"""
	print("ReadAloudGuided: TTS finished, prompting user to speak")
	
	# Prevent multiple calls if both signal and timer fire
	if not tts_speaking:
		print("ReadAloudGuided: TTS already finished, ignoring duplicate call")
		return
	
	# Reset TTS speaking flag
	tts_speaking = false
	
	# Stop the backup timer if it's running
	if tts_timer and not tts_timer.is_stopped():
		tts_timer.stop()
		print("ReadAloudGuided: Stopped backup timer")
	
	# Reset read button
	var read_button = $MainContainer/PassagePanel/ReadButton
	if read_button:
		read_button.text = "Read"
		read_button.disabled = false
		read_button.modulate = Color.WHITE
		print("ReadAloudGuided: Read button reset to 'Read' state")
	
	# Update guide to prompt user to speak
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	if guide_display:
		guide_display.text = "Now click the 'Speak' button to repeat what I said: \"" + current_target_sentence + "\""
		guide_display.modulate = Color.ORANGE # Make it stand out
	
	# Enable speak button and make it prominent
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.disabled = false
		speak_button.modulate = Color.LIGHT_GREEN # Highlight the button
		speak_button.text = "Speak"
		
	# Remove automatic audio prompt - user controls when to hear instructions
	print("ReadAloudGuided: TTS finished, waiting for user to click Speak button")

func _on_highlighting_reset_timeout():
	"""Called when highlighting reset timer expires - clears yellow highlighting for incomplete speech"""
	print("ReadAloudGuided: Auto-resetting yellow highlighting due to incomplete speech")
	_clear_word_highlighting()
	
	# Update guide to encourage trying again
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	if guide_display:
		guide_display.text = "Try reading the whole sentence: \"" + current_target_sentence + "\""
		guide_display.modulate = Color.ORANGE

# Live word highlighting function
func _update_live_word_highlighting(interim_text: String):
	"""Update live word highlighting based on STT interim results with fast progression"""
	if current_target_sentence.is_empty():
		return
		
	# Clean and process interim text
	var processed_interim = _clean_text_for_words(interim_text.to_lower())
	var spoken_words = processed_interim.split(" ")
	
	# Get target sentence words
	sentence_words = current_target_sentence.to_lower().split(" ")
	
	# Clear previous highlighting
	_clear_word_highlighting()
	
	# Find matching words with phonetic tolerance
	highlighted_words.clear()
	
	for spoken_word in spoken_words:
		if spoken_word.length() < 2: # Skip very short words
			continue
			
		for i in range(sentence_words.size()):
			var target_word = sentence_words[i]
			if _is_word_match_for_highlighting(spoken_word, target_word):
				if i not in highlighted_words:
					highlighted_words.append(i)
	
	# Apply highlighting to the passage text
	_apply_word_highlighting()
	
	# FAST PROGRESSION: If user has highlighted 80%+ of words, immediately progress
	var completion_threshold = max(1, int(sentence_words.size() * 0.8)) # At least 80% of words
	if highlighted_words.size() >= completion_threshold:
		print("ReadAloudGuided: Fast progression triggered - ", highlighted_words.size(), "/", sentence_words.size(), " words matched")
		# Stop any timers
		if highlighting_reset_timer and not highlighting_reset_timer.is_stopped():
			highlighting_reset_timer.stop()
		# Immediately trigger success
		call_deferred("_trigger_fast_success")
		return
	
	# Start/restart the highlighting reset timer for incomplete speech detection
	# If user has highlighted some words but not enough, prepare for auto-reset
	if highlighted_words.size() > 0 and highlighted_words.size() < completion_threshold:
		if highlighting_reset_timer:
			highlighting_reset_timer.stop() # Stop any existing timer
			highlighting_reset_timer.wait_time = 2.0 # Reduced to 2 seconds for faster feedback
			highlighting_reset_timer.start()
			print("ReadAloudGuided: Started highlighting reset timer - partial speech detected")

func _trigger_fast_success():
	"""Immediately trigger success for fast progression"""
	print("ReadAloudGuided: Fast success triggered - completing sentence immediately")
	
	# Stop STT
	if stt_listening:
		_stop_speech_recognition()
	
	# Mark as completed and progress
	_show_success_feedback("(Fast progression)")

# Word matching for live highlighting (more forgiving than final matching)
func _is_word_match_for_highlighting(spoken_word: String, target_word: String) -> bool:
	"""Check if spoken word matches target word for live highlighting"""
	if spoken_word == target_word:
		return true
		
	# Apply phonetic improvements
	var improved_spoken = _apply_phonetic_improvements(spoken_word, target_word)
	if improved_spoken == target_word:
		return true
		
	# Calculate similarity (more lenient for live feedback)
	var distance = levenshtein_distance(spoken_word, target_word)
	var max_length = max(spoken_word.length(), target_word.length())
	var similarity = 1.0 - (float(distance) / max_length) if max_length > 0 else 0.0
	
	# 70% similarity for live highlighting (more forgiving)
	return similarity >= 0.7

# Apply yellow highlighting to matched words
func _apply_word_highlighting():
	"""Apply yellow highlighting to matched words in the passage"""
	var text_display = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageText
	if not text_display or sentence_words.is_empty():
		return
		
	# Build highlighted text with BBCode
	var highlighted_text = ""
	for i in range(sentence_words.size()):
		var word = sentence_words[i]
		if i in highlighted_words:
			highlighted_text += "[bgcolor=yellow][color=black]" + word + "[/color][/bgcolor] "
		else:
			highlighted_text += word + " "
	
	# Update only the current sentence with highlighting
	var passage = passages[current_passage_index]
	var full_text = ""
	
	for j in range(passage.sentences.size()):
		if j == current_sentence_index:
			full_text += highlighted_text.strip_edges() + "\n\n"
		else:
			full_text += passage.sentences[j] + "\n\n"
	
	text_display.text = full_text.strip_edges()

# Clear word highlighting
func _clear_word_highlighting():
	"""Clear word highlighting by restoring sentence highlighting"""
	print("ReadAloudGuided: Clearing word highlighting")
	# Simply restore the sentence highlighting without recursion
	var passage = passages[current_passage_index]
	var text_display = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageText
	
	if text_display:
		# Build clean text with sentence highlighting only
		var highlighted_text = ""
		for i in range(passage.sentences.size()):
			if i in completed_sentences:
				# GREEN: Keep completed sentences green
				highlighted_text += "[bgcolor=green][color=white]" + passage.sentences[i] + "[/color][/bgcolor]\n\n"
			elif i == current_sentence_index:
				# YELLOW: Current sentence  
				highlighted_text += "[bgcolor=yellow][color=black]" + passage.sentences[i] + "[/color][/bgcolor]\n\n"
			else:
				# Normal text for future sentences
				highlighted_text += passage.sentences[i] + "\n\n"
		
		text_display.text = highlighted_text.strip_edges()
		print("ReadAloudGuided: Word highlighting cleared, sentence highlighting restored")


func _show_success_feedback(_recognized_text: String):
	"""Show success feedback and move to next sentence"""
	print("ReadAloudGuided: Success! Moving to next sentence.")
	
	# Stop highlighting reset timer since user succeeded
	if highlighting_reset_timer and not highlighting_reset_timer.is_stopped():
		highlighting_reset_timer.stop()
		print("ReadAloudGuided: Stopped highlighting reset timer - success achieved")
	
	# Mark current sentence as completed
	if current_sentence_index not in completed_sentences:
		completed_sentences.append(current_sentence_index)
		print("ReadAloudGuided: Marked sentence ", current_sentence_index, " as completed")
	
	# Update display to show completed sentence with permanent green highlighting
	_update_sentence_highlighting()
	
	# Stop STT and reset button
	if stt_listening:
		_stop_speech_recognition()
	
	# Reset speak button
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.text = "Speak"
		speak_button.disabled = false
		speak_button.modulate = Color.WHITE
	
	# Show success message
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	if guide_display:
		guide_display.text = "Great! Moving to next sentence..."
		guide_display.modulate = Color.GREEN
	
	# INSTANT progression for better user experience
	await get_tree().create_timer(0.05).timeout
	
	# Check if all sentences in passage are completed
	_check_passage_completion()
	
	# Move to next sentence or complete passage
	_advance_to_next_sentence()

func _check_passage_completion():
	"""Check if all sentences in current passage are completed and provide feedback"""
	var passage = passages[current_passage_index]
	var total_sentences = passage.sentences.size()
	var completed_count = completed_sentences.size()
	
	print("ReadAloudGuided: Passage progress - ", completed_count, "/", total_sentences, " sentences completed")
	
	if completed_count == total_sentences:
		print("ReadAloudGuided: All sentences completed! User can progress to next passage")
		var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
		if guide_display:
			guide_display.text = "Amazing! You've completed ALL sentences in this passage! Ready for the next passage!"
			guide_display.modulate = Color.GOLD
		
		if tts:
			tts.speak("Great! Passage complete!")
	elif completed_count == total_sentences - 1:
		print("ReadAloudGuided: Almost done - only 1 sentence left!")
		var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
		if guide_display:
			guide_display.text = "Great progress! Only 1 more sentence to complete this passage!"
			guide_display.modulate = Color.ORANGE

func _show_encouragement_feedback(_recognized_text: String, target_text: String):
	"""Show encouragement feedback for close matches"""
	print("ReadAloudGuided: Close match, encouraging user to try again.")
	
	# Stop STT to reset state
	if stt_listening:
		_stop_speech_recognition()
	
	# Reset speak button
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.text = "Speak"
		speak_button.disabled = false
		speak_button.modulate = Color.WHITE
	
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	if guide_display:
		guide_display.text = "Good try! Very close! Let's try again: \"" + target_text + "\""
		guide_display.modulate = Color.ORANGE
	
	# Shorter audio encouragement for faster feedback
	if tts:
		tts.speak("Close! Try again.")
		await get_tree().create_timer(0.3).timeout
		tts.speak(target_text)

func _show_partial_match_feedback(_recognized_text: String, target_text: String):
	"""Show partial match feedback with extra help for dyslexic learners"""
	print("ReadAloudGuided: Partial match, providing extra guidance.")
	
	# Stop STT to reset state
	if stt_listening:
		_stop_speech_recognition()
	
	# Reset speak button
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.text = "Speak"
		speak_button.disabled = false
		speak_button.modulate = Color.WHITE
	
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	if guide_display:
		guide_display.text = "Good effort! Let's break it down: \"" + target_text + "\""
		guide_display.modulate = Color.CYAN
	
	# Break down sentence for dyslexic learners
	if tts:
		tts.speak("Let me help you!")
		await get_tree().create_timer(0.5).timeout
		
		# Read slowly word by word (faster pace)
		var words = target_text.split(" ")
		for word in words:
			tts.speak(word)
			await get_tree().create_timer(0.4).timeout # Shorter pause between words
		
		await get_tree().create_timer(0.3).timeout
		tts.speak("Now try the whole sentence: " + target_text)

func _show_try_again_feedback(_recognized_text: String, target_text: String):
	"""Show try again feedback with patient encouragement for dyslexic learners"""
	print("ReadAloudGuided: Low similarity, asking user to try again with extra help.")
	
	# Stop STT to reset state
	if stt_listening:
		_stop_speech_recognition()
	
	# Reset speak button
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.text = "Speak"
		speak_button.disabled = false
		speak_button.modulate = Color.WHITE
	
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	if guide_display:
		guide_display.text = "Let's practice together. I'll read it slowly: \"" + target_text + "\""
		guide_display.modulate = Color.LIGHT_CORAL
	
	# Faster patient support for dyslexic learners
	if tts:
		tts.speak("Let's try again!")
		await get_tree().create_timer(0.5).timeout
		
		# Set slower rate for struggling readers (but shorter wait)
		var original_rate = tts.get_rate()
		tts.set_rate(0.7) # Slightly slower but not too slow
		tts.speak(target_text)
		await get_tree().create_timer(1.0).timeout # Shorter wait
		
		# Restore original rate
		tts.set_rate(original_rate)
		tts.speak("Now you try!")

func _load_progress():
	if module_progress and module_progress.is_authenticated():
		print("ReadAloudGuided: Loading guided reading progress")
		var progress_data = await module_progress.get_read_aloud_progress()
		if progress_data and progress_data.has("guided_reading"):
			var guided_data = progress_data["guided_reading"]
			completed_activities = guided_data.get("activities_completed", [])
			var saved_index = guided_data.get("current_index", 0)
			
			# Resume at saved position OR find first uncompleted passage
			var resume_index = saved_index
			
			# Validate saved index is within bounds
			if saved_index >= passages.size():
				resume_index = passages.size() - 1
			
			# If saved position passage is already completed, find next uncompleted
			var saved_passage_id = "passage_" + str(resume_index)
			if completed_activities.has(saved_passage_id):
				print("ReadAloudGuided: Saved passage '", saved_passage_id, "' already completed, finding next uncompleted")
				for i in range(passages.size()):
					var passage_id = "passage_" + str(i)
					if not completed_activities.has(passage_id):
						resume_index = i
						break
			
			current_passage_index = resume_index
			print("ReadAloudGuided: Resuming at passage: ", current_passage_index, " (saved index was: ", saved_index, ")")
			_update_progress_display()
		else:
			_update_progress_display()
	else:
		_update_progress_display()

func _update_progress_display(_progress_percentage: float = 0.0):
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	
	# Calculate passage-specific progress
	var completed_count = completed_activities.size()
	var total_passages = passages.size()
	var passages_percent = (float(completed_count) / float(total_passages)) * 100.0
	
	if progress_label:
		progress_label.text = str(completed_count) + "/" + str(total_passages) + " Passages"
	if progress_bar:
		progress_bar.value = passages_percent
		print("ReadAloudGuided: Progress updated to ", passages_percent, "% (", completed_count, "/", total_passages, " passages)")

func _setup_initial_display():
	"""Setup initial display with first sentence ready for practice"""
	_display_passage(current_passage_index)
	_update_navigation_buttons()
	
	# Initialize first sentence for practice
	if current_passage_index < passages.size():
		var passage = passages[current_passage_index]
		if current_sentence_index < passage.sentences.size():
			current_target_sentence = passage.sentences[current_sentence_index]
			
			# Use new highlighting system that preserves completed sentences
			_update_sentence_highlighting()
			
			# Update guide for first sentence
			var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
			if guide_display:
				guide_display.text = "Click 'Read' to hear the first sentence, then click 'Speak' to practice reading it yourself!"
				guide_display.modulate = Color.CYAN

func _display_passage(passage_index: int):
	if passage_index < 0 or passage_index >= passages.size():
		return
		
	var passage = passages[passage_index]
	
	# Update title
	var title_label = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageTitleLabel
	if title_label:
		title_label.text = passage.title
	
	# Display full text initially
	var text_display = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageText
	if text_display:
		text_display.clear()
		text_display.append_text(passage.text)
	
	# Show initial guide note
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	if guide_display and passage.guide_notes.size() > 0:
		guide_display.text = passage.guide_notes[0]
	
	# Reset sentence tracking
	current_sentence_index = 0
	
	# Apply proper sentence highlighting
	_update_sentence_highlighting()
	
	_update_play_button_text()

func _update_navigation_buttons():
	var prev_button = $MainContainer/ControlsContainer/PreviousButton
	var next_button = $MainContainer/ControlsContainer/NextButton
	
	if prev_button:
		prev_button.visible = (current_passage_index > 0)
	if next_button:
		next_button.visible = (current_passage_index < passages.size() - 1)

func _update_play_button_text():
	var play_button = $MainContainer/PassagePanel/ReadButton
	if play_button:
		if is_reading:
			play_button.text = "Stop"
		else:
			play_button.text = "Read"

func _start_sentence_practice():
	"""Start STT practice for current sentence"""
	var passage = passages[current_passage_index]
	if current_sentence_index < passage.sentences.size():
		current_target_sentence = passage.sentences[current_sentence_index].strip_edges()
		print("ReadAloudGuided: Starting practice for sentence: ", current_target_sentence)
		
		# Check if sentence is already completed
		if current_sentence_index in completed_sentences:
			print("ReadAloudGuided: Sentence ", current_sentence_index, " already completed, skipping to next")
			_advance_to_next_sentence()
			return
		
		# Highlight current sentence while preserving completed sentences
		_update_sentence_highlighting()
		
		# Set up STT feedback
		stt_feedback_active = true
		
		# Start speech recognition
		if not await _start_speech_recognition():
			_show_microphone_error()

func _highlight_current_sentence():
	"""Highlight the current sentence while preserving completed sentences"""
	var passage = passages[current_passage_index]
	var text_display = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageText
	
	if text_display and current_sentence_index < passage.sentences.size():
		# Build text with proper highlighting - preserve completed sentences as GREEN
		var highlighted_text = ""
		for i in range(passage.sentences.size()):
			if i in completed_sentences:
				# GREEN: Keep completed sentences highlighted
				highlighted_text += "[bgcolor=green][color=white]" + passage.sentences[i] + "[/color][/bgcolor]\n\n"
			elif i == current_sentence_index:
				# YELLOW: Current sentence for reading (changed from lightblue to yellow for consistency)
				highlighted_text += "[bgcolor=yellow][color=black]" + passage.sentences[i] + "[/color][/bgcolor]\n\n"
			else:
				# Normal text for future sentences
				highlighted_text += passage.sentences[i] + "\n\n"
		
		text_display.text = highlighted_text.strip_edges()
		print("ReadAloudGuided: Current sentence highlighted while preserving ", completed_sentences.size(), " completed sentences")
		
		# Store sentence words for live highlighting
		sentence_words = passage.sentences[current_sentence_index].to_lower().split(" ")
		current_target_sentence = passage.sentences[current_sentence_index]

func _show_microphone_error():
	"""Show error when microphone is not available"""
	var feedback_panel = get_node_or_null("STTFeedbackPanel")
	if feedback_panel:
		var feedback_label = feedback_panel.get_node("FeedbackLabel")
		if feedback_label:
			feedback_label.text = "Microphone not available. Please check your settings."
			feedback_label.modulate = Color.RED
		feedback_panel.visible = true

func _next_guided_sentence():
	"""Move to next sentence for practice"""
	var passage = passages[current_passage_index]
	if current_sentence_index < passage.sentences.size() - 1:
		current_sentence_index += 1
		_start_sentence_practice()
	else:
		# All sentences practiced, mark passage as complete and advance properly
		await _complete_current_passage()
		_stop_guided_reading()

func _previous_guided_sentence():
	"""Move to previous sentence for practice"""
	if current_sentence_index > 0:
		current_sentence_index -= 1
		_start_sentence_practice()

func _read_sentence_aloud():
	"""Read current sentence using TTS"""
	var passage = passages[current_passage_index]
	if current_sentence_index < passage.sentences.size() and tts:
		var sentence = passage.sentences[current_sentence_index].strip_edges()
		tts_speaking = true # Set speaking flag
		tts.speak(sentence)

func _start_guided_reading():
	if is_reading:
		_stop_guided_reading()
		return
		
	is_reading = true
	_update_play_button_text()
	
	var passage = passages[current_passage_index]
	print("ReadAloudGuided: Starting guided reading of '", passage.title, "'")
	
	# Read through each sentence with highlighting and guidance
	for i in range(passage.sentences.size()):
		if not is_reading:
			break
		current_sentence_index = i
		var sentence = passage.sentences[i]
		
		# Highlight current sentence
		_highlight_sentence(i)
		
		# Show relevant guide note
		if i < passage.guide_notes.size():
			var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
			if guide_display:
				guide_display.text = passage.guide_notes[i]
		
		# Speak the sentence
		if tts:
			tts_speaking = true # Set speaking flag
			tts.speak(sentence)
		
		# Wait based on sentence length and reading speed
		var wait_time = _calculate_reading_time(sentence)
		await get_tree().create_timer(wait_time).timeout
		
		# Brief pause between sentences for comprehension
		await get_tree().create_timer(0.5).timeout
	
	# Mark as completed and save progress  
	await _complete_current_passage()
	_stop_guided_reading()

func _highlight_sentence(sentence_index: int):
	var passage = passages[current_passage_index]
	var text_display = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageText
	
	if text_display and sentence_index < passage.sentences.size():
		text_display.clear()
		
		for i in range(passage.sentences.size()):
			if i == sentence_index:
				# Highlight current sentence with yellow background
				text_display.append_text("[bgcolor=yellow]" + passage.sentences[i] + "[/bgcolor]")
			else:
				text_display.append_text(passage.sentences[i])
			
			# Add spacing between sentences
			if i < passage.sentences.size() - 1:
				text_display.append_text(" ")

func _calculate_reading_time(text: String) -> float:
	# Calculate reading time based on word count and WPM
	var word_count = text.split(" ").size()
	var time_in_minutes = word_count / reading_speed
	return time_in_minutes * 60.0 # Convert to seconds

func _stop_guided_reading():
	is_reading = false
	current_sentence_index = 0
	_update_play_button_text()
	
	if tts:
		tts.stop()
		tts_speaking = false # Reset speaking flag when manually stopped
	
	# Reset text display to normal
	_display_passage(current_passage_index)

# Button event handlers
func _on_back_button_pressed():
	$ButtonClick.play()
	_fade_out_and_change_scene("res://Scenes/ReadAloudModule.tscn")

func _on_play_button_pressed():
	$ButtonClick.play()
	var play_button = $MainContainer/PassagePanel/ReadButton
	
	if not is_reading:
		# Start STT practice mode
		is_reading = true
		current_sentence_index = 0
		_start_sentence_practice()
		if play_button:
			play_button.text = "Stop"
	else:
		# Stop practice
		_stop_guided_reading()
		_stop_speech_recognition()
		stt_feedback_active = false
		if play_button:
			play_button.text = "Read"
		is_reading = false
		# Reset passage display
		_display_passage(current_passage_index)

func _on_previous_passage_button_pressed():
	$ButtonClick.play()
	if current_passage_index > 0:
		_stop_guided_reading()
		current_passage_index -= 1
		current_sentence_index = 0
		
		# Reset completed sentences for new passage
		completed_sentences.clear()
		print("ReadAloudGuided: Reset completed sentences for previous passage ", current_passage_index)
		
		_display_passage(current_passage_index)
		_update_navigation_buttons()

func _on_next_passage_button_pressed():
	$ButtonClick.play()
	if current_passage_index < passages.size() - 1:
		_stop_guided_reading()
		current_passage_index += 1
		current_sentence_index = 0
		
		# Reset completed sentences for new passage
		completed_sentences.clear()
		print("ReadAloudGuided: Reset completed sentences for next passage ", current_passage_index)
		
		_display_passage(current_passage_index)
		_update_navigation_buttons()

func _on_practice_complete_button_pressed():
	"""Mark current guided reading passage as completed"""
	$ButtonClick.play()
	print("ReadAloudGuided: Practice complete button pressed for passage ", current_passage_index)
	
	# Mark passage as completed with proper error handling
	if module_progress and module_progress.is_authenticated():
		var passage_id = "passage_" + str(current_passage_index)
		print("ReadAloudGuided: Attempting to save passage completion: ", passage_id)
		
		var success = await module_progress.complete_read_aloud_activity("guided_reading", passage_id)
		if success:
			print("ReadAloudGuided: Passage '", passage_id, "' marked as completed in Firebase")
		else:
			print("ReadAloudGuided: Failed to save passage completion to Firebase")
	else:
		print("ReadAloudGuided: Module progress not available or not authenticated")
	
	# Show completion message and advance to next passage
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	if guide_display:
		guide_display.text = "Great job! You completed this guided reading passage."
	
	# Auto-advance to next passage after a short delay
	await get_tree().create_timer(1.5).timeout
	if current_passage_index < passages.size() - 1:
		current_passage_index += 1
		_display_passage(current_passage_index)
		_update_navigation_buttons()
	else:
		# All passages completed
		_show_all_passages_completed()

func _show_all_passages_completed():
	"""Show completion celebration when all passages are completed"""
	print("ReadAloudGuided: All passages completed!")
	
	# Create progress data for completion celebration
	var progress_data = {
		"activities_completed": completed_activities,
		"total_passages": passages.size()
	}
	
	# Show completion celebration like other modules
	if completion_celebration:
		completion_celebration.show_completion(
			completion_celebration.CompletionType.READ_ALOUD_PASSAGE,
			"All Guided Reading Passages",
			progress_data,
			"read_aloud"
		)
	
	# Update progress display
	_update_progress_display()
	
	# Save final completion status to Firebase
	if module_progress and module_progress.is_authenticated():
		var final_save = await module_progress.complete_read_aloud_activity("guided_reading", "all_passages_complete")
		if final_save:
			print("ReadAloudGuided: Final completion status saved to Firebase")

func _fade_out_and_change_scene(scene_path: String):
	_stop_guided_reading()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _exit_tree():
	_stop_guided_reading()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window gains focus
		call_deferred("_refresh_progress")

func _refresh_progress():
	"""Refresh progress display when user returns to guided reading"""
	print("ReadAloudGuided: Refreshing progress display")
	await _load_progress()
	_update_progress_display()

# STT Functions for Web Speech API integration
func _update_listen_button():
	"""Update listen button state based on STT status"""
	var listen_button = get_node_or_null("MainContainer/ControlsContainer/SpeakButton")
	if listen_button:
		if stt_listening:
			listen_button.text = "Stop"
			listen_button.disabled = false # Keep button enabled so user can stop
			listen_button.modulate = Color.ORANGE
		else:
			listen_button.text = "Speak"
			listen_button.disabled = false
			listen_button.modulate = Color.WHITE

func _handle_stt_error(error: String):
	"""Handle speech recognition errors"""
	print("ReadAloudGuided: STT Error: ", error)
	stt_listening = false
	_update_listen_button()
	
	# Show user-friendly error message
	var error_message = "Speech recognition error. Please try again."
	if error == "not-allowed" or error == "not-found":
		error_message = "Microphone access denied. Please allow microphone access and try again."
	elif error == "network":
		error_message = "Network error. Please check your connection and try again."
	
	_show_stt_feedback(error_message, Color.RED)

func _process_interim_transcription(text):
	"""Process interim speech results for live feedback during guided reading"""
	if not live_transcription_enabled:
		return
	
	print("ReadAloudGuided: Processing interim text: '", text, "'")
	
	# Update the last interim result for continuous listening
	last_interim_result = text
	
	# Clean the text for display
	var cleaned_text = text.strip_edges()
	current_interim_result = cleaned_text
	
	# Reset debounce timer to keep recognition active longer for dyslexic users
	_reset_debounce_timer()
	
	# IMPORTANT: Trigger live word highlighting for dyslexic users
	_update_live_word_highlighting(cleaned_text)
	
	# Update any live transcription display if we have one
	if has_node("VBoxContainer/LiveTranscriptionText"):
		var live_text = get_node("VBoxContainer/LiveTranscriptionText")
		if live_text:
			live_text.text = "You said: " + cleaned_text
	
	# Optional: Check if interim result matches current sentence for real-time feedback
	_check_interim_match(cleaned_text)

func _reset_debounce_timer():
	"""Reset the debounce timer to extend listening time for dyslexic users"""
	if debounce_timer:
		debounce_timer.queue_free()
	
	debounce_timer = Timer.new()
	debounce_timer.wait_time = 3.0 # Extended wait time for dyslexic users
	debounce_timer.one_shot = true
	add_child(debounce_timer)
	debounce_timer.timeout.connect(_on_debounce_timeout)
	debounce_timer.start()

func _on_debounce_timeout():
	"""Handle debounce timeout - continue listening if no final result yet"""
	print("ReadAloudGuided: Debounce timeout - extending listening time for dyslexic users")
	# Keep the recognition active - the continuous JavaScript mode will handle this

func _check_interim_match(interim_text):
	"""Check if interim speech matches parts of the current sentence"""
	if current_target_sentence.is_empty() or interim_text.is_empty():
		return
	
	# Simple word matching for dyslexia-friendly feedback
	var target_words = current_target_sentence.to_lower().split(" ")
	var spoken_words = interim_text.to_lower().split(" ")
	
	# Count matching words for encouragement
	var matches = 0
	for spoken_word in spoken_words:
		if spoken_word in target_words:
			matches += 1
	
	# Provide gentle feedback for progress with visual guide updates
	if matches > 0:
		print("ReadAloudGuided: Found ", matches, " matching words - good progress!")
		
		# Update guide with encouraging feedback
		var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
		if guide_display:
			var progress_text = "Great! Found " + str(matches) + " word"
			if matches > 1:
				progress_text += "s"
			progress_text += ". Keep going: \"" + current_target_sentence + "\""
			guide_display.text = progress_text
			guide_display.modulate = Color.LIGHT_GREEN

func _handle_stt_result(text: String, confidence: float):
	"""Handle successful speech recognition result"""
	print("ReadAloudGuided: Processing STT result: ", text)
	_process_speech_result(text, confidence)

func _show_stt_feedback(message: String, color: Color):
	"""Show STT feedback to user"""
	var feedback_label = get_node_or_null("STTFeedbackPanel/FeedbackLabel")
	if feedback_label:
		feedback_label.text = message
		feedback_label.modulate = color
		feedback_label.visible = true
		
		# Hide feedback after 3 seconds
		await get_tree().create_timer(3.0).timeout
		if feedback_label:
			feedback_label.visible = false

# New button functions for the redesigned UI
func _on_button_hover():
	"""Play hover sound when mouse enters any button"""
	$ButtonHover.play()

func _on_read_button_pressed():
	"""Read button - TTS reads current sentence with start/stop control"""
	$ButtonClick.play()
	print("ReadAloudGuided: Read button pressed")

	var read_button = $MainContainer/PassagePanel/ReadButton
	
	# Check if TTS is currently speaking (allow stop functionality)
	# Note: Godot's TTS doesn't have is_speaking(), so we track state manually
	if tts_speaking:
		# Stop TTS
		if tts:
			tts.stop()
		
		# Stop backup timer if running
		if tts_timer and not tts_timer.is_stopped():
			tts_timer.stop()
			print("ReadAloudGuided: Stopped backup timer on manual stop")
		
		# Reset yellow highlighting when user stops reading
		_clear_word_highlighting()
		
		tts_speaking = false
		if read_button:
			read_button.text = "Read"
			read_button.disabled = false
			read_button.modulate = Color.WHITE
		print("ReadAloudGuided: TTS stopped by user")
		return

	if current_passage_index < passages.size():
		var passage = passages[current_passage_index]
		
		if current_sentence_index < passage.sentences.size():
			var sentence = passage.sentences[current_sentence_index].strip_edges()
			current_target_sentence = sentence
			
			if sentence != "":
				# Highlight current sentence PROPERLY (preserve completed green sentences)
				_update_sentence_highlighting() # Use consistent highlighting function instead of _highlight_current_sentence
				
				# Update button text to show reading state with stop capability
				if read_button:
					read_button.text = "Stop"
					read_button.disabled = false
					read_button.modulate = Color.ORANGE
				
				# Use TTS to read this sentence (will trigger _on_tts_finished when done)
				if tts:
					tts_speaking = true # Set speaking flag
					tts.speak(sentence)
					print("ReadAloudGuided: Reading sentence: ", sentence)
					
					# ALWAYS start a backup timer to ensure button resets even if TTS signal fails
					if tts_timer:
						var word_count = sentence.split(" ").size()
						var estimated_time = (word_count / 2.5) + 2.0 # ~150 WPM + generous buffer
						tts_timer.wait_time = estimated_time
						tts_timer.start()
						print("ReadAloudGuided: Started backup timer for ", estimated_time, " seconds")
				else:
					print("ReadAloudGuided: TTS not available")
					if read_button:
						read_button.text = "Read"
						read_button.modulate = Color.WHITE
					
					# If using timer fallback, estimate reading time and start timer
					if use_timer_fallback_for_tts and tts_timer:
						var word_count = sentence.split(" ").size()
						var estimated_time = (word_count / 2.5) + 1.0 # ~150 WPM + buffer
						tts_timer.wait_time = estimated_time
						tts_timer.start()
					
				print("ReadAloudGuided: Reading sentence ", current_sentence_index + 1, ": ", sentence)
			else:
				print("ReadAloudGuided: Empty sentence, advancing...")
				current_sentence_index += 1
				_on_read_button_pressed() # Try next sentence

func _on_speak_button_pressed():
	"""Speak button - STT functionality with start/stop control"""
	$ButtonClick.play()
	print("ReadAloudGuided: Speak button pressed")

	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	
	# Check if currently listening (allowing stop functionality)
	if stt_listening:
		print("ReadAloudGuided: Stopping speech recognition")
		_stop_speech_recognition()
		
		# Reset yellow highlighting when user stops speaking
		_clear_word_highlighting()
		
		# Reset button state
		if speak_button:
			speak_button.text = "Speak"
			speak_button.disabled = false
			speak_button.modulate = Color.WHITE
		
		# Reset guide message
		var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
		if guide_display:
			guide_display.text = "Click 'Speak' to try reading the sentence again."
			guide_display.modulate = Color.WHITE
		
		# Clear any interim results and reset STT state
		current_interim_result = ""
		last_interim_result = ""
		result_being_processed = false
		
		return

	# Start speech recognition
	if current_passage_index < passages.size():
		var passage = passages[current_passage_index]
		
		if current_sentence_index < passage.sentences.size():
			var sentence = passage.sentences[current_sentence_index].strip_edges()
			current_target_sentence = sentence
			
			if sentence != "":
				print("ReadAloudGuided: Target sentence for STT: ", sentence)
				
				# ENSURE CLEAN STATE before starting new recognition
				_stop_speech_recognition() # Stop any existing recognition first
				await get_tree().process_frame # Wait one frame for cleanup
				
				# Clear ALL STT state for fresh start
				current_interim_result = ""
				last_interim_result = ""
				result_being_processed = false
				stt_feedback_active = false
				live_transcription_enabled = false
				
				# Update guide message
				var guide_panel = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
				if guide_panel:
					guide_panel.text = "Now speak: \"" + sentence + "\""
					guide_panel.modulate = Color.CYAN
				
				# Enable live transcription for better feedback
				live_transcription_enabled = true
				
				# Start speech recognition for this specific sentence (ENHANCED CONFLICT PREVENTION)
				var start_success = await _start_speech_recognition()
				if start_success:
					stt_feedback_active = true
					
					# Update button state AFTER successful start
					if speak_button:
						speak_button.text = "Stop"
						speak_button.modulate = Color("#ff6b6b") # Red color for stop
					
					print("ReadAloudGuided: Speech recognition started for sentence practice")
					
					# Update guide to show listening state
					var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
					if guide_display:
						guide_display.text = "Listening... Click 'Stop' to cancel."
						guide_display.modulate = Color.CYAN
				else:
					print("ReadAloudGuided: Failed to start speech recognition")
					# Reset button if failed to start
					if speak_button:
						speak_button.text = "Speak"
						speak_button.modulate = Color.WHITE
			else:
				print("ReadAloudGuided: No sentence to practice")

func _on_guide_button_pressed():
	"""Guide button - Provide TTS guidance for guided reading"""
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Guided Reading! This activity helps you practice reading with step-by-step guidance. Read the guide notes first to understand what to do. Listen to the passage by clicking 'Read', then practice reading each sentence yourself. The yellow highlighting shows you which sentence is being read. Take your time and follow the guidance!"
		tts.speak(guide_text)

func _on_tts_setting_button_pressed():
	"""TTS Settings button - Open settings as popup overlay"""
	$ButtonClick.play()
	print("ReadAloudGuided: Settings button pressed")
	
	# Open settings as popup instead of changing scene
	var settings_popup_scene = load("res://Scenes/SettingScene.tscn")
	if settings_popup_scene:
		var popup = settings_popup_scene.instantiate()
		add_child(popup)
		if popup.has_method("set_context"):
			popup.set_context(false) # normal settings; hide battle buttons

# New function to advance to next sentence with progress tracking
func _advance_to_next_sentence():
	"""Advance to the next sentence with complete passage handling"""
	var passage = passages[current_passage_index]
	
	print("ReadAloudGuided: Advanced to sentence ", current_sentence_index + 1, " of ", passage.sentences.size())
	
	if current_sentence_index < passage.sentences.size() - 1:
		# Move to next sentence in current passage
		current_sentence_index += 1
		current_target_sentence = passage.sentences[current_sentence_index]
		
		# Update display to highlight current sentence while preserving completed sentences
		_update_sentence_highlighting()
		
		# Update guide text for next sentence
		var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
		if guide_display:
			guide_display.text = "Read the highlighted sentence: \"" + current_target_sentence + "\""
			guide_display.modulate = Color.WHITE
			
	else:
		# All sentences completed - show completion celebration and wait for user choice
		print("ReadAloudGuided: All sentences in passage completed! Showing completion celebration...")
		await _complete_current_passage()
		# Celebration system handles progression - no auto-advance here

func _update_sentence_highlighting():
	"""Update sentence highlighting with persistent green for completed sentences"""
	var passage = passages[current_passage_index]
	var text_display = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageText
	
	if text_display and current_sentence_index < passage.sentences.size():
		# Build text with proper highlighting for all sentences
		var highlighted_text = ""
		for i in range(passage.sentences.size()):
			if i in completed_sentences:
				# GREEN: Completed sentences (permanent and visible)
				highlighted_text += "[bgcolor=green][color=white]" + passage.sentences[i] + "[/color][/bgcolor]\n\n"
				print("ReadAloudGuided: Sentence ", i, " highlighted as COMPLETED (GREEN)")
			elif i == current_sentence_index:
				# YELLOW: Current sentence being worked on
				highlighted_text += "[bgcolor=yellow][color=black]" + passage.sentences[i] + "[/color][/bgcolor]\n\n"
				print("ReadAloudGuided: Sentence ", i, " highlighted as CURRENT (YELLOW)")
			else:
				# Normal text for future sentences
				highlighted_text += passage.sentences[i] + "\n\n"
		
		text_display.text = highlighted_text.strip_edges()
		print("ReadAloudGuided: Updated highlighting - Completed: ", completed_sentences, " Current: ", current_sentence_index)
		
		# Store sentence words for live highlighting
		if current_sentence_index < passage.sentences.size():
			current_target_sentence = passage.sentences[current_sentence_index]
			sentence_words = current_target_sentence.to_lower().split(" ")
			print("ReadAloudGuided: Target sentence set: ", current_target_sentence)
		sentence_words = passage.sentences[current_sentence_index].to_lower().split(" ")
		current_target_sentence = passage.sentences[current_sentence_index]
		
		print("ReadAloudGuided: Updated highlighting - Completed: ", completed_sentences, " Current: ", current_sentence_index)
		
		# Update guide for the new sentence with encouraging progress info
		var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
		if guide_display:
			var progress_text = "Sentence " + str(current_sentence_index + 1) + " of " + str(passage.sentences.size())
			progress_text += " - You're doing great! Ready for the next one?"
			if current_sentence_index < passage.guide_notes.size():
				progress_text += "\n" + passage.guide_notes[current_sentence_index]
			guide_display.text = progress_text
			guide_display.modulate = Color.CYAN
		
		# Reset speak button for new sentence
		var speak_button = $MainContainer/ControlsContainer/SpeakButton
		if speak_button:
			speak_button.disabled = false
			speak_button.modulate = Color.WHITE
			speak_button.text = "Speak"
		
		# Clear any previous highlighting
		_clear_word_highlighting()
		
		# Update display only - user must click Read button to hear it
		print("ReadAloudGuided: Advanced to sentence ", current_sentence_index + 1, " of ", passage.sentences.size())
		
		# Update guide to prompt user to click Read
		var guide_notes = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
		if guide_notes:
			guide_notes.text = "Click 'Read' to hear the next sentence: \"" + current_target_sentence + "\""
			guide_notes.modulate = Color.CYAN
		
	else:
		# All sentences completed in this passage
		await _complete_current_passage()

# Complete current passage and move to next or finish
func _complete_current_passage():
	"""Complete current passage and advance to next with enhanced progress tracking"""
	print("ReadAloudGuided: Completing passage ", current_passage_index + 1)
	
	# Save passage completion to Firebase
	if module_progress and module_progress.is_authenticated():
		var firebase_passage_id = "passage_" + str(current_passage_index)
		var success = await module_progress.complete_read_aloud_activity("guided_reading", firebase_passage_id)
		if success:
			print("ReadAloudGuided: Passage completion saved to Firebase")
		else:
			print("ReadAloudGuided: Failed to save passage completion")
	
	# Update local completed activities
	var passage_id = "passage_" + str(current_passage_index)
	if passage_id not in completed_activities:
		completed_activities.append(passage_id)
		print("ReadAloudGuided: Added passage to local completed activities: ", passage_id)
	
	# Update progress display immediately
	_update_progress_display()
	print("ReadAloudGuided: Progress updated after passage completion")
	
	# Stop any active TTS before showing celebration
	if tts and tts_speaking:
		tts.stop()
		tts_speaking = false
	
	# Reset button states
	var read_button = $MainContainer/PassagePanel/ReadButton
	if read_button:
		read_button.text = "Read"
		read_button.disabled = false
		read_button.modulate = Color.WHITE
	
	var speak_btn = $MainContainer/ControlsContainer/SpeakButton
	if speak_btn:
		speak_btn.text = "Speak"
		speak_btn.disabled = false
		speak_btn.modulate = Color.WHITE
	
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.text = "Speak"
		speak_button.disabled = false
	
	# Show completion celebration instead of automatic progression
	var passage = passages[current_passage_index]
	var progress_data = {
		"activities_completed": completed_activities,
		"current_passage": current_passage_index + 1,
		"total_passages": passages.size()
	}
	
	# Show celebration with read-aloud specific data
	if completion_celebration:
		completion_celebration.show_completion(
			completion_celebration.CompletionType.READ_ALOUD_PASSAGE,
			passage.title + " passage",
			progress_data,
			"read_aloud"
		)
		print("ReadAloudGuided: Showing completion celebration for passage: ", passage.title)
		# User must click "Next" button to advance - no auto-advance for dyslexia-friendly UX
	else:
		print("ReadAloudGuided: WARNING - Completion celebration not initialized")
		# Fallback to immediate advancement only if celebration fails to load
		await get_tree().create_timer(2.0).timeout
		_advance_to_next_passage_or_complete()

func _advance_to_next_passage_or_complete():
	"""Helper function to advance to next passage or complete all passages"""
	# Check if more passages available
	if current_passage_index < passages.size() - 1:
		# Move to next passage
		current_passage_index += 1
		current_sentence_index = 0
		
		# Reset completed sentences for new passage
		completed_sentences.clear()
		print("ReadAloudGuided: Advanced to passage ", current_passage_index + 1)
		
		_setup_initial_display()
		
		# Show new passage introduction
		var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
		if guide_display:
			var passage = passages[current_passage_index]
			guide_display.text = "Starting new passage: \"" + passage.title + "\". Click 'Read' to begin!"
			guide_display.modulate = Color.CYAN
	else:
		# All passages completed!
		_show_all_passages_completed()
		if module_progress and module_progress.is_authenticated():
			var final_save = await module_progress.complete_read_aloud_activity("guided_reading", "all_passages_complete")
			if final_save:
				print("ReadAloudGuided: Final completion status saved to Firebase")

# Completion celebration handler functions
func _on_celebration_try_again():
	"""Handle 'Try Again' button from completion celebration"""
	print("ReadAloudGuided: Celebration 'Try Again' pressed - replaying current passage")
	
	# Reset current passage to beginning
	current_sentence_index = 0
	completed_sentences.clear()
	
	# Reset display
	_setup_initial_display()
	
	# Show guide instruction
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	if guide_display:
		var passage = passages[current_passage_index]
		guide_display.text = "Let's practice \"" + passage.title + "\" again! Click 'Read' to begin."
		guide_display.modulate = Color.CYAN

func _on_celebration_next():
	"""Handle 'Next' button from completion celebration"""
	print("ReadAloudGuided: Celebration 'Next' pressed - advancing to next passage")
	
	# Hide celebration immediately
	if completion_celebration:
		completion_celebration.hide()
	
	# Check if more passages available
	if current_passage_index < passages.size() - 1:
		# Move to next passage
		current_passage_index += 1
		current_sentence_index = 0
		
		# Reset completed sentences for new passage
		completed_sentences.clear()
		print("ReadAloudGuided: Advanced to passage ", current_passage_index + 1, " (", passages[current_passage_index].title, ")")
		
		# Setup display for new passage
		_setup_initial_display()
		
		# Show new passage introduction
		var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
		if guide_display:
			var passage = passages[current_passage_index]
			guide_display.text = "Starting new passage: \"" + passage.title + "\". Click 'Read' to begin!"
			guide_display.modulate = Color.CYAN
	else:
		# All passages completed - return to module selection
		_show_all_passages_completed()

func _on_celebration_closed():
	"""Handle celebration popup being closed"""
	print("ReadAloudGuided: Celebration popup closed")
	# No specific action needed, user can continue with current state
