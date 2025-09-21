extends Control

# Core systems
var tts: TextToSpeech = null
var module_progress = null
var current_word_index: int = 0
var completed_activities: Array = []

# STT functionality 
var recognition_active = false
var current_target_syllables = []
var stt_listening = false
var result_being_processed = false

# Enhanced permission variables like ReadAloudGuided
var mic_permission_granted = false
var permission_check_complete = false

# Enhanced debouncing for similar-sounding words like ReadAloudGuided
var last_interim_result = ""
var interim_change_count = 0
var last_change_time = 0

# TTS timer fallback like ReadAloudGuided
var use_timer_fallback_for_tts = false
var tts_timer: Timer = null

# Highlighting reset timer for partial speech like ReadAloudGuided
var highlighting_reset_timer: Timer = null

# Yellow highlighting system for successful recognition
var highlighted_syllables = []
var highlighted_words = []

# Completion celebration system
var completion_celebration: CanvasLayer = null

# Syllable breaking words - progressive difficulty
var syllable_words = [
	# 2 syllables (starting level)
	{"word": "rabbit", "syllables": ["rab", "bit"], "difficulty": 2},
	{"word": "carpet", "syllables": ["car", "pet"], "difficulty": 2},
	{"word": "garden", "syllables": ["gar", "den"], "difficulty": 2},
	
	# 3 syllables
  	{"word": "butterfly", "syllables": ["but", "ter", "fly"], "difficulty": 3},
  	{"word": "tomorrow", "syllables": ["to", "mor", "row"], "difficulty": 3},
	{"word": "happiness", "syllables": ["hap", "pee", "ness"], "difficulty": 3},
	
	# 4 syllables (advanced level)
	{"word": "watermelon", "syllables": ["wuah", "ter", "mel", "on"], "difficulty": 4},
	{"word": "information", "syllables": ["in", "for", "may", "tion"], "difficulty": 4},
	{"word": "calculator", "syllables": ["cal", "cue", "lay", "tor"], "difficulty": 4}
]

# UI References
@onready var current_word_label = $MainContainer/WordDisplayPanel/MarginContainer/WordDisplayContainer/CurrentWordLabel
@onready var syllable_display_label = $MainContainer/WordDisplayPanel/MarginContainer/WordDisplayContainer/SyllableDisplayLabel
@onready var activity_title_label = $MainContainer/ActivityPanel/MarginContainer/ScrollContainer/ActivityContainer/ActivityTitleLabel
@onready var instruction_label = $MainContainer/ActivityPanel/MarginContainer/ScrollContainer/ActivityContainer/InstructionLabel
@onready var stt_button = $MainContainer/ActivityPanel/MarginContainer/ScrollContainer/ActivityContainer/STTContainer/STTButton
@onready var stt_status_label = $MainContainer/ActivityPanel/MarginContainer/ScrollContainer/ActivityContainer/STTContainer/STTStatusLabel
@onready var stt_result_label = $MainContainer/ActivityPanel/MarginContainer/ScrollContainer/ActivityContainer/STTContainer/STTResultLabel
@onready var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
@onready var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
@onready var prev_button = $MainContainer/ActivityPanel/MarginContainer/ScrollContainer/ActivityContainer/STTContainer/ControlsContainer/PrevButton
@onready var next_button = $MainContainer/ActivityPanel/MarginContainer/ScrollContainer/ActivityContainer/STTContainer/ControlsContainer/NextButton

func _ready():
	print("SyllableBuildingModule: Initializing syllable workshop")
	
	# Enhanced fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Initialize helpers
	_init_tts()
	_init_module_progress()
	_init_completion_celebration()
	
	# Connect hover events
	_connect_hover_events()
	
	# Initialize STT button state
	if stt_button:
		stt_button.text = "Speak"
		stt_button.disabled = false
	if stt_status_label:
		stt_status_label.text = "Click Speak to begin"
	if stt_result_label:
		stt_result_label.text = ""
	
	# Load initial word
	_update_word_display()
	_update_navigation_buttons()
	
	# Load progress
	call_deferred("_load_progress")

func _process(_delta):
	# Poll for speech recognition results if active
	if recognition_active and OS.has_feature("JavaScript") and JavaScriptBridge.has_method("eval"):
		_poll_for_interim_results()

# Continuous polling for speech results in _process
func _poll_for_interim_results():
	if JavaScriptBridge.has_method("eval"):
		# Check for final results first - AUTO PROCESS like ReadAloudGuided
		var final_js = """
		(function() {
			if (window.syllableFinalResult) {
				var result = window.syllableFinalResult;
				window.syllableFinalResult = '';
				return result;
			}
			return '';
		})();
		"""
		var final_result = JavaScriptBridge.eval(final_js)
		if final_result != null and str(final_result) != "null" and str(final_result) != "":
			var text_str = str(final_result).strip_edges()
			if text_str != "" and not result_being_processed:
				print("SyllableBuildingModule: Final result received - auto-processing: ", text_str)
				_check_syllable_recognition(text_str)
				return
		
		# Check for interim results for live highlighting
		var interim_js = """
		(function() {
			if (window.syllableInterimResult) {
				var result = window.syllableInterimResult;
				window.syllableInterimResult = '';  // Clear after reading
				return result;
			}
			return '';
		})();
		"""
		var interim_check = JavaScriptBridge.eval(interim_js)
		if interim_check and str(interim_check) != "null" and str(interim_check) != "":
			var interim_text = str(interim_check)
			
			# Extract only the last word for display like WordChallengePanel_STT
			var processed_text = _clean_text_for_words(interim_text.to_lower())
			var words = processed_text.strip_edges().split(" ")
			var last_word = ""
			if words.size() > 0:
				# Get the last non-empty word
				for i in range(words.size() - 1, -1, -1):
					if words[i].strip_edges() != "":
						last_word = words[i].strip_edges()
						break
			
			if stt_result_label:
				# Show only the last word like WordChallengePanel_STT
				var display_word = last_word.capitalize()
				stt_result_label.text = "Hearing: " + display_word
				print("SyllableBuildingModule: Live interim result: ", display_word)
			
			# Apply live highlighting during speech
			_update_live_syllable_highlighting(interim_text)
		
		# Check for errors
		var error_check = JavaScriptBridge.eval("window.syllableRecognitionError")
		if error_check and str(error_check) != "null" and str(error_check) != "":
			print("SyllableBuildingModule: Recognition error: ", error_check)
			JavaScriptBridge.eval("window.syllableRecognitionError = null")
			_stop_syllable_recognition()

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
	
	# Connect TTS finished signal like ReadAloudGuided
	if tts:
		# Check what signals are available and connect the appropriate one
		if tts.has_signal("utterance_finished"):
			tts.utterance_finished.connect(_on_tts_finished)
			print("SyllableBuildingModule: Connected to utterance_finished signal")
		elif tts.has_signal("finished"):
			tts.finished.connect(_on_tts_finished)
			print("SyllableBuildingModule: Connected to finished signal")
		elif tts.has_signal("speaking_finished"):
			tts.speaking_finished.connect(_on_tts_finished)
			print("SyllableBuildingModule: Connected to speaking_finished signal")
		else:
			print("SyllableBuildingModule: No suitable TTS finished signal found")
			use_timer_fallback_for_tts = true
	
	# ALWAYS create a backup timer to ensure TTS resets even if signals fail
	tts_timer = Timer.new()
	tts_timer.one_shot = true
	add_child(tts_timer)
	tts_timer.timeout.connect(_on_tts_finished)
	print("SyllableBuildingModule: Created backup TTS timer")
	
	# Create highlighting reset timer for partial speech detection like ReadAloudGuided
	highlighting_reset_timer = Timer.new()
	highlighting_reset_timer.one_shot = true
	add_child(highlighting_reset_timer)
	highlighting_reset_timer.timeout.connect(_on_highlighting_reset_timeout)
	print("SyllableBuildingModule: Created highlighting reset timer")

func _init_module_progress():
	if Firebase and Firebase.Auth and Firebase.Auth.auth:
		module_progress = ModuleProgress.new()
		print("SyllableBuildingModule: ModuleProgress initialized")
	else:
		print("SyllableBuildingModule: Firebase not available, using local tracking")

func _init_completion_celebration():
	"""Initialize completion celebration system"""
	var celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")
	completion_celebration = celebration_scene.instantiate()
	add_child(completion_celebration)
	
	# Connect celebration signals
	completion_celebration.try_again_pressed.connect(_on_celebration_try_again)
	completion_celebration.next_item_pressed.connect(_on_celebration_next)
	completion_celebration.closed.connect(_on_celebration_closed)
	print("SyllableBuildingModule: Completion celebration initialized")

# Connect hover events for all buttons
func _connect_hover_events():
	var buttons = [
		$MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton,
		$MainContainer/WordDisplayPanel/HearWordButton,
		$MainContainer/WordDisplayPanel/HearSyllablesButton,
		$MainContainer/HeaderPanel/GuideButton,
		$MainContainer/HeaderPanel/TTSSettingButton,
		stt_button,
		prev_button,
		next_button
	]
	
	for button in buttons:
		if button and not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)

func _setup_web_speech_recognition():
	"""Setup web speech recognition for syllable practice - using ReadAloudGuided approach"""
	print("SyllableBuildingModule: Setting up web speech recognition...")
	
	if not JavaScriptBridge.has_method("eval"):
		print("SyllableBuildingModule: JavaScriptBridge not available")
		return
	
	# Initialize web environment and check permissions like ReadAloudGuided
	_initialize_web_audio_environment()
	call_deferred("_check_and_wait_for_permissions")

# Enhanced permission checking like ReadAloudGuided
func _check_and_wait_for_permissions():
	"""Check microphone permissions like ReadAloudGuided"""
	print("SyllableBuildingModule: Checking microphone permissions...")
	permission_check_complete = false
	
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
		(function() {
			if (typeof window.checkSyllablePermissions === 'function') {
				window.checkSyllablePermissions();
				
				// Wait for permission check to complete
				var checkInterval = setInterval(function() {
					if (window.syllablePermissionChecked) {
						clearInterval(checkInterval);
						console.log('SyllableBuildingModule: Permission granted:', window.syllablePermissionGranted);
					}
				}, 50);
			} else {
				console.log('SyllableBuildingModule: checkSyllablePermissions function not available');
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
				var permission_status = JavaScriptBridge.eval("window.syllablePermissionChecked || false")
				if permission_status:
					var granted = JavaScriptBridge.eval("window.syllablePermissionGranted || false")
					update_mic_permission_state("granted" if granted else "prompt")
					break
		
		print("SyllableBuildingModule: Permission check completed. Granted: ", mic_permission_granted)

func update_mic_permission_state(state):
	"""Callback for permission state updates like ReadAloudGuided"""
	permission_check_complete = true
	if state == "granted":
		mic_permission_granted = true
		print("SyllableBuildingModule: Microphone permission granted")
	else:
		mic_permission_granted = false
		print("SyllableBuildingModule: Microphone permission: ", state)
	
	var js_code = """
		(function() {
			// Check if functions already exist to avoid redefinition
			if (typeof window.syllableRecognition === 'undefined') {
				// Global speech recognition variables
				window.syllableRecognition = null;
				window.syllableRecognitionActive = false;
				window.syllablePermissionGranted = false;
				window.syllablePermissionChecked = false;
				window.syllableFinalResult = '';
				window.syllableInterimResult = '';
				window.syllableResult = null;
				
				// Permission check function
				window.checkSyllablePermissions = function() {
					if (navigator.permissions) {
						navigator.permissions.query({name: 'microphone'}).then(function(result) {
							window.syllablePermissionGranted = (result.state === 'granted');
							window.syllablePermissionChecked = true;
							console.log('SyllableBuildingModule: Permission state:', result.state);
						}).catch(function(error) {
							console.log('SyllableBuildingModule: Permission check failed:', error);
							window.syllablePermissionChecked = true;
						});
					} else {
						// Fallback for browsers without permission API
						window.syllablePermissionChecked = true;
					}
				};
				
				// Request microphone permission
				window.requestSyllableMicPermission = function() {
					return navigator.mediaDevices.getUserMedia({audio: true})
						.then(function(stream) {
							window.syllablePermissionGranted = true;
							stream.getTracks().forEach(function(track) {
								track.stop();
							});
							return true;
						})
						.catch(function(error) {
							console.log('SyllableBuildingModule: Permission denied:', error);
							window.syllablePermissionGranted = false;
							return false;
						});
				};
				
				// Initialize speech recognition using ReadAloudGuided pattern
				window.initSyllableSpeechRecognition = function() {
					try {
						if ('webkitSpeechRecognition' in window) {
							window.syllableRecognition = new webkitSpeechRecognition();
						} else if ('SpeechRecognition' in window) {
							window.syllableRecognition = new SpeechRecognition();
						} else {
							console.log('SyllableBuildingModule: Speech recognition not supported');
							return false;
						}
						
						// Configure recognition for better short word detection
						window.syllableRecognition.continuous = true;
						window.syllableRecognition.interimResults = true;
						window.syllableRecognition.lang = 'en-US';
						window.syllableRecognition.maxAlternatives = 3; // More alternatives for better accuracy
						
						// Enhanced event handlers like ReadAloudGuided
						window.syllableRecognition.onstart = function() {
							console.log('SyllableBuildingModule: Recognition started');
							window.syllableRecognitionActive = true;
						};
						
						window.syllableRecognition.onresult = function(event) {
							var finalTranscript = '';
							var interimTranscript = '';
							
							for (var i = event.resultIndex; i < event.results.length; i++) {
								var transcript = event.results[i][0].transcript;
								if (event.results[i].isFinal) {
									finalTranscript += transcript;
									console.log('SyllableBuildingModule: Final result:', transcript);
								} else {
									interimTranscript += transcript;
								}
							}
							
							if (finalTranscript.trim()) {
								window.syllableFinalResult = finalTranscript.trim();
							}
							
							if (interimTranscript.trim()) {
								window.syllableInterimResult = interimTranscript.trim();
							}
						};
						
						window.syllableRecognition.onerror = function(event) {
							console.log('SyllableBuildingModule: Recognition error:', event.error);
							window.syllableRecognitionActive = false;
							window.syllableRecognitionError = event.error;
						};
						
						window.syllableRecognition.onend = function() {
							console.log('SyllableBuildingModule: Recognition ended');
							window.syllableRecognitionActive = false;
						};
						
						return true;
					} catch (error) {
						console.log('SyllableBuildingModule: Failed to initialize recognition:', error);
						return false;
					}
				};
				
				// Start recognition function with better setup
				window.startSyllableRecognition = function() {
					if (!window.syllableRecognition) {
						if (!window.initSyllableSpeechRecognition()) {
							return false;
						}
					}
					
					try {
						window.syllableFinalResult = '';
						window.syllableInterimResult = '';
						window.syllableRecognitionError = '';
						window.syllableRecognition.start();
						return true;
					} catch (error) {
						console.log('SyllableBuildingModule: Failed to start recognition:', error);
						return false;
					}
				};
				
				// Stop recognition function
				window.stopSyllableRecognition = function() {
					if (window.syllableRecognition) {
						try {
							window.syllableRecognition.stop();
						} catch (error) {
							console.log('SyllableBuildingModule: Error stopping recognition:', error);
						}
					}
				};
				
				// Initialize everything
				var initResult = window.initSyllableSpeechRecognition();
				console.log('SyllableBuildingModule: JavaScript initialization result:', initResult);
				if (initResult) {
					window.checkSyllablePermissions();
					console.log('SyllableBuildingModule: All syllable systems initialized successfully');
				}
				
				return initResult;
			}
			return true;
		})();
	"""
	
	var result = JavaScriptBridge.eval(js_code)
	if result:
		print("SyllableBuildingModule: JavaScript environment initialized for web speech recognition")
	else:
		print("SyllableBuildingModule: Failed to initialize JavaScript environment")

# Initialize JavaScript environment for web audio - enhanced like ReadAloudGuided
func _initialize_web_audio_environment():
	"""Initialize JavaScript environment for web audio - ENHANCED with ReadAloudGuided patterns"""
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
		(function() {
			// Check if functions already exist to avoid redefinition
			if (typeof window.syllableRecognition === 'undefined') {
				// Global speech recognition variables
				window.syllableRecognition = null;
				window.syllableRecognitionActive = false;
				window.syllablePermissionGranted = false;
				window.syllablePermissionChecked = false;
				window.syllableFinalResult = '';
				window.syllableInterimResult = '';
				window.syllableResult = null;
				
				// Permission check function
				window.checkSyllablePermissions = function() {
					if (navigator.permissions) {
						navigator.permissions.query({name: 'microphone'}).then(function(result) {
							window.syllablePermissionGranted = (result.state === 'granted');
							window.syllablePermissionChecked = true;
							console.log('SyllableBuildingModule: Permission state:', result.state);
						}).catch(function(error) {
							console.log('SyllableBuildingModule: Permission check failed:', error);
							window.syllablePermissionChecked = true;
						});
					} else {
						// Fallback for browsers without permission API
						window.syllablePermissionChecked = true;
					}
				};
				
				// Request microphone permission
				window.requestSyllableMicPermission = function() {
					return navigator.mediaDevices.getUserMedia({audio: true})
						.then(function(stream) {
							window.syllablePermissionGranted = true;
							stream.getTracks().forEach(function(track) {
								track.stop();
							});
							return true;
						})
						.catch(function(error) {
							console.log('SyllableBuildingModule: Permission denied:', error);
							window.syllablePermissionGranted = false;
							return false;
						});
				};
		})();
		"""
		
		var result = JavaScriptBridge.eval(js_code)
		if result:
			print("SyllableBuildingModule: JavaScript environment initialized for web speech recognition")
		else:
			print("SyllableBuildingModule: Failed to initialize JavaScript environment")
# Enhanced speech-to-text processing with dyslexia-friendly improvements
func _process_speech_result(result: String) -> String:
	"""Process speech recognition result with enhanced accuracy - DYSLEXIA-FRIENDLY"""
	var processed = result.strip_edges().to_lower()
	
	# Remove common speech artifacts
	processed = processed.replace(".", "").replace(",", "").replace("?", "").replace("!", "")
	
	# Handle multiple alternatives if JavaScript provided them
	if "||" in processed: # Multiple alternatives separated by ||
		var alternatives = processed.split("||")
		for alt in alternatives:
			alt = alt.strip_edges()
			if alt.length() > 0:
				processed = alt
				break
	
	# Dyslexia-friendly preprocessing
	processed = _normalize_for_dyslexia(processed)
	
	print("SyllableBuildingModule: Processed speech result: '", processed, "'")
	return processed

# Dyslexia-friendly text normalization
func _normalize_for_dyslexia(text: String) -> String:
	"""Normalize text for dyslexia-friendly matching"""
	var normalized = text.to_lower().strip_edges()
	
	# Common phonetic confusions for dyslexic users
	var phonetic_map = {
		"ph": "f", # phone → fone
		"gh": "f", # laugh → laff
		"ck": "k", # back → bak
		"qu": "kw", # quick → kwik
	}
	
	# Apply phonetic normalizations
	for pattern in phonetic_map:
		normalized = normalized.replace(pattern, phonetic_map[pattern])
	
	# Remove doubled letters (common dyslexic pattern)
	var single_letters = ""
	var last_char = ""
	for i in range(normalized.length()):
		var current_char = normalized[i]
		if current_char != last_char or current_char in "aeiou": # Keep vowel doubles
			single_letters += current_char
		last_char = current_char
	
	return single_letters

# Enhanced accuracy checking for syllables
func _check_syllable_accuracy_enhanced(spoken: String, target: String) -> Dictionary:
	"""Enhanced accuracy checking with dyslexia-friendly fuzzy matching"""
	var result = {"accurate": false, "similarity": 0.0, "feedback": ""}
	
	if spoken.is_empty():
		result.feedback = "No speech detected. Try again!"
		return result
	
	# Normalize both for comparison
	var spoken_norm = _normalize_for_dyslexia(spoken)
	var target_norm = _normalize_for_dyslexia(target)
	
	print("SyllableBuildingModule: Comparing '", spoken_norm, "' with '", target_norm, "'")
	
	# Exact match after normalization
	if spoken_norm == target_norm:
		result.accurate = true
		result.similarity = 1.0
		result.feedback = "Perfect!"
		return result
	
	# Calculate fuzzy similarity
	var similarity = _calculate_fuzzy_similarity(spoken_norm, target_norm)
	result.similarity = similarity
	
	# Dyslexia-friendly threshold (more forgiving)
	if similarity >= 0.7: # 70% threshold for dyslexic users
		result.accurate = true
		result.feedback = "Great job!"
	elif similarity >= 0.5: # Partial credit
		result.accurate = false
		result.feedback = "Close! Try: " + target
	else:
		result.accurate = false
		result.feedback = "Try saying: " + target
	
	print("SyllableBuildingModule: Accuracy result - similarity: ", similarity, ", accurate: ", result.accurate)
	return result

# Enhanced fuzzy matching algorithm
func _calculate_fuzzy_similarity(text1: String, text2: String) -> float:
	"""Calculate fuzzy similarity between two strings using multiple algorithms"""
	if text1.is_empty() or text2.is_empty():
		return 0.0
	
	if text1 == text2:
		return 1.0
	
	# Levenshtein distance similarity
	var leven_sim = _levenshtein_similarity(text1, text2)
	
	# Phonetic similarity (first/last letter matching for dyslexia)
	var phonetic_sim = 0.0
	if text1.length() > 0 and text2.length() > 0:
		if text1[0] == text2[0]: # Same starting sound
			phonetic_sim += 0.3
		if text1[-1] == text2[-1]: # Same ending sound
			phonetic_sim += 0.2
	
	# Combine similarities with weights
	var combined = (leven_sim * 0.7) + (phonetic_sim * 0.3)
	return min(combined, 1.0)

# Levenshtein distance similarity
func _levenshtein_similarity(s1: String, s2: String) -> float:
	"""Calculate similarity based on Levenshtein distance"""
	var len1 = s1.length()
	var len2 = s2.length()
	
	if len1 == 0:
		return 0.0 if len2 > 0 else 1.0
	if len2 == 0:
		return 0.0
	
	# Create matrix
	var matrix = []
	for i in range(len1 + 1):
		matrix.append([])
		for j in range(len2 + 1):
			matrix[i].append(0)
	
	# Initialize first row and column
	for i in range(len1 + 1):
		matrix[i][0] = i
	for j in range(len2 + 1):
		matrix[0][j] = j
	
	# Fill matrix
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost = 0 if s1[i - 1] == s2[j - 1] else 1
			matrix[i][j] = min(
				matrix[i - 1][j] + 1, # deletion
				matrix[i][j - 1] + 1, # insertion
				matrix[i - 1][j - 1] + cost # substitution
			)
	
	var distance = matrix[len1][len2]
	var max_len = max(len1, len2)
	return 1.0 - (float(distance) / float(max_len))

# Force stop speech recognition - CRITICAL for navigation
func force_stop_speech_recognition():
	"""Force stop all speech recognition - CRITICAL for clean navigation"""
	print("SyllableBuildingModule: Force stopping speech recognition")
	
	# Stop JavaScript recognition with enhanced cleanup
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
		(function() {
			if (window.syllableRecognition) {
				try {
					window.syllableRecognition.stop();
					window.syllableRecognition.abort(); // Force abort to release microphone
					window.syllableRecognition = null; // Critical: Set to null
					console.log('SyllableBuildingModule: Force stopped and cleaned up recognition');
				} catch (error) {
					console.log('SyllableBuildingModule: Error in force stop:', error);
				}
			}
			// Force state reset
			window.syllableRecognitionActive = false;
			window.syllableRecognitionError = null;
			return true;
		})();
		"""
		JavaScriptBridge.eval(js_code)
	
	# Reset all recognition states
	recognition_active = false
	
	# Stop all timers to prevent callbacks
	if is_instance_valid(tts_timer):
		tts_timer.stop()
	if is_instance_valid(highlighting_reset_timer):
		highlighting_reset_timer.stop()
	
	print("SyllableBuildingModule: All speech systems stopped")

# Enhanced cleanup on scene exit - CRITICAL for WebGL
func _on_tree_exiting():
	"""Enhanced cleanup when exiting scene - prevents WebGL memory leaks"""
	print("SyllableBuildingModule: Scene exiting - performing enhanced cleanup")
	
	# Force stop all recognition
	force_stop_speech_recognition()
	
	# Stop TTS
	if is_instance_valid(tts):
		tts.stop()
	
	# Clean up timers
	if is_instance_valid(tts_timer):
		tts_timer.queue_free()
	if is_instance_valid(highlighting_reset_timer):
		highlighting_reset_timer.queue_free()
	
	print("SyllableBuildingModule: Enhanced cleanup completed")

func _update_word_display():
	"""Update the display with current word and syllables"""
	if current_word_index >= syllable_words.size():
		current_word_index = 0
	
	var current_data = syllable_words[current_word_index]
	var word = current_data["word"]
	var syllables = current_data["syllables"]
	
	# Update word display
	if current_word_label:
		current_word_label.text = "[center]" + word + "[/center]"
	
	# Update syllable display with bullet separation
	if syllable_display_label:
		syllable_display_label.text = " • ".join(syllables)
	
	# Update activity based on difficulty
	var difficulty = current_data["difficulty"]
	if activity_title_label:
		activity_title_label.text = "Activity: " + str(difficulty) + "-Syllable Breaking"
	
	if instruction_label:
		if difficulty == 1:
			instruction_label.text = "This is a single syllable word. Say it clearly!"
		else:
			instruction_label.text = "Say each syllable separately: " + " • ".join(syllables)
	
	# Store current target for STT
	current_target_syllables = syllables
	
	print("SyllableBuildingModule: Updated display - Word: ", word, " Syllables: ", syllables)

func _update_navigation_buttons():
	"""Update navigation button states"""
	if prev_button:
		prev_button.visible = (current_word_index > 0)
	if next_button:
		next_button.visible = (current_word_index < syllable_words.size() - 1)

func _load_progress():
	"""Load syllable workshop progress"""
	if module_progress and module_progress.is_authenticated():
		print("SyllableBuildingModule: Loading syllable progress via ModuleProgress")
		var read_aloud_progress = await module_progress.get_read_aloud_progress()
		if read_aloud_progress:
			var syllable_data = read_aloud_progress.get("syllable_workshop", {})
			completed_activities = syllable_data.get("activities_completed", [])
			var saved_index = syllable_data.get("current_word_index", 0)
			
			print("SyllableBuildingModule: Loaded progress - Completed: ", completed_activities, " Saved index: ", saved_index)
			
			# Find the correct resumption point
			var resume_index = 0
			
			# Method 1: Find first uncompleted word in order
			for i in range(syllable_words.size()):
				var word = syllable_words[i]["word"]
				if not word in completed_activities:
					resume_index = i
					print("SyllableBuildingModule: Found first uncompleted word '", word, "' at index ", i)
					break
			
			# Method 2: If all words completed, use last word
			if resume_index < syllable_words.size() and syllable_words[resume_index]["word"] in completed_activities:
				resume_index = syllable_words.size() - 1
				print("SyllableBuildingModule: All words completed, staying at last word")
			
			# Method 3: Fallback to saved index if it's valid and uncompleted
			if saved_index < syllable_words.size():
				var saved_word = syllable_words[saved_index]["word"]
				if not saved_word in completed_activities:
					resume_index = saved_index
					print("SyllableBuildingModule: Using saved index ", saved_index, " for uncompleted word '", saved_word, "'")
			
			current_word_index = resume_index
			print("SyllableBuildingModule: Resuming at word index ", current_word_index, " ('", syllable_words[current_word_index]["word"], "')")
			_update_word_display()
			_update_navigation_buttons()
			_update_progress_display()
		else:
			print("SyllableBuildingModule: No previous progress found")
			_update_progress_display()
	else:
		print("SyllableBuildingModule: ModuleProgress not available")
		_update_progress_display()

func _update_progress_display():
	"""Update progress label and bar"""
	var completed_count = completed_activities.size()
	var total_words = syllable_words.size()
	var current_position = current_word_index + 1
	var progress_percent = (float(completed_count) / float(total_words)) * 100.0
	
	if progress_label:
		progress_label.text = str(current_position) + "/" + str(total_words) + " Words (" + str(completed_count) + " completed)"
	if progress_bar:
		progress_bar.value = progress_percent
		print("SyllableBuildingModule: Progress updated to ", progress_percent, "% (", completed_count, "/", total_words, " words completed, on word ", current_position, ")")

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("SyllableBuildingModule: Returning to read aloud module")
	_fade_out_and_change_scene("res://Scenes/ReadAloudModule.tscn")

func _on_hear_word_button_pressed():
	$ButtonClick.play()
	if tts and current_word_index < syllable_words.size():
		var word = syllable_words[current_word_index]["word"]
		print("SyllableBuildingModule: Speaking full word: ", word)
		tts.speak(word)

func _on_hear_syllables_button_pressed():
	$ButtonClick.play()
	if tts and current_word_index < syllable_words.size():
		var syllables = syllable_words[current_word_index]["syllables"]
		print("SyllableBuildingModule: Speaking syllables separately: ", syllables)
		
		# Speak each syllable with pauses
		_speak_syllables_separately(syllables)

func _speak_syllables_separately(syllables: Array):
	"""Speak each syllable with pauses for better learning"""
	for i in range(syllables.size()):
		var syllable = syllables[i]
		
		# Add emphasis markers for TTS
		var emphasized_syllable = syllable + "..."
		
		if tts:
			tts.speak(emphasized_syllable)
		
		# Add pause between syllables (except last one)
		if i < syllables.size() - 1:
			await get_tree().create_timer(1.0).timeout

func _on_stt_button_pressed():
	$ButtonClick.play()
	
	print("SyllableBuildingModule: STT button pressed, recognition_active: ", recognition_active)
	
	if recognition_active:
		print("SyllableBuildingModule: Stopping current recognition...")
		_stop_syllable_recognition()
	else:
		print("SyllableBuildingModule: Starting new recognition session...")
		# Clear previous results
		if stt_result_label:
			stt_result_label.text = "Preparing to listen..."
		
		# Start new recognition session
		stt_button.text = "Requesting..."
		stt_button.disabled = true
		if stt_status_label:
			stt_status_label.text = "Please allow microphone access..."
		
		# Try to start recognition
		var success = await _start_syllable_recognition()
		
		if success:
			print("SyllableBuildingModule: Recognition started successfully")
			# Successfully started
			recognition_active = true
			stt_listening = true
			stt_button.text = "Stop"
			stt_button.modulate = Color.ORANGE
			stt_button.disabled = false
			if stt_status_label:
				stt_status_label.text = "Listening... speak the word clearly"
			
			if stt_result_label:
				stt_result_label.text = "Listening..."
		else:
			print("SyllableBuildingModule: Failed to start recognition")
			# Failed to start
			recognition_active = false
			stt_button.text = "Speak"
			stt_button.disabled = false
			if stt_status_label:
				stt_status_label.text = "Failed to start - try again"

func _start_syllable_recognition() -> bool:
	if not JavaScriptBridge.has_method("eval"):
		print("SyllableBuildingModule: JavaScript bridge not available")
		return false
		
	print("SyllableBuildingModule: Starting speech recognition...")
	
	# Setup environment if not already done
	_setup_web_speech_recognition()
	
	# Use the new JavaScript functions
	var js_code = """
		(function() {
			try {
				// Request permission and start recognition
				return navigator.mediaDevices.getUserMedia({ audio: true })
					.then(function(stream) {
						stream.getTracks().forEach(track => track.stop());
						return window.startSyllableRecognition();
					})
					.catch(function(error) {
						console.error('SyllableBuildingModule: Permission denied:', error);
						return false;
					});
			} catch (error) {
				console.error('SyllableBuildingModule: Error starting recognition:', error);
				return false;
			}
		})();
	"""
	
	JavaScriptBridge.eval(js_code)
	
	# Give time for permission dialog and setup
	await get_tree().create_timer(0.5).timeout
	
	var check_js = """
		(function() {
			return window.syllableRecognitionActive === true;
		})();
	"""
	
	var is_active = JavaScriptBridge.eval(check_js)
	print("SyllableBuildingModule: Recognition active check: ", is_active)
	
	return bool(is_active)

func _stop_syllable_recognition():
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
			(function() {
				if (window.syllableRecognition) {
					console.log('SyllableBuildingModule: Stopping recognition...');
					try {
						window.syllableRecognition.stop();
						window.syllableRecognition.abort(); // Force abort to release microphone
					} catch (error) {
						console.log('SyllableBuildingModule: Error stopping recognition:', error);
					}
					// Critical: Set to null to allow new recognition instances
					window.syllableRecognition = null;
					console.log('SyllableBuildingModule: Recognition stopped and cleaned up');
					return true;
				}
				// Force state reset even if no recognition
				window.syllableRecognitionActive = false;
				window.syllableRecognitionError = null;
				console.log('SyllableBuildingModule: State reset completed');
				return false;
			})();
		"""
		JavaScriptBridge.eval(js_code)
	
	recognition_active = false
	stt_listening = false
	
	# Reset button state like ReadAloudGuided
	if stt_button:
		stt_button.text = "Speak"
		stt_button.disabled = false
		stt_button.modulate = Color.WHITE
	
	print("SyllableBuildingModule: Speech recognition stopped")

func _process_final_result():
	"""Process the final speech recognition result"""
	if not JavaScriptBridge.has_method("eval"):
		return
	
	var js_code = """
		(function() {
			if (!window.syllableResults) return null;
			var result = window.syllableResults.final;
			window.syllableResults.final = null; // Clear after reading
			return result;
		})();
	"""
	
	var final_result = JavaScriptBridge.eval(js_code)
	if final_result and typeof(final_result) == TYPE_STRING:
		_check_syllable_recognition(final_result.strip_edges())
	else:
		stt_status_label.text = "No speech detected. Try again."
		stt_result_label.text = ""

func _check_syllable_recognition(spoken_text: String):
	"""Check if spoken text matches target word - ENHANCED like ReadAloudGuided"""
	if result_being_processed:
		print("SyllableBuildingModule: Already processing result, skipping...")
		return
	
	result_being_processed = true
	
	var current_word = syllable_words[current_word_index]["word"]
	
	print("SyllableBuildingModule: Checking recognition - Spoken: '", spoken_text, "' Target: '", current_word, "'")
	
	# Enhanced text processing pipeline like ReadAloudGuided
	var processed_text = spoken_text
	
	# Step 1: Clean text (remove non-letters except spaces)
	processed_text = _clean_text_for_words(processed_text)
	
	# Step 2: Normalize for comparison
	var spoken_normalized = processed_text.to_lower().strip_edges()
	var target_normalized = current_word.to_lower().strip_edges()
	
	print("SyllableBuildingModule: Enhanced processing:")
	print("  Original: '", spoken_text, "'")
	print("  After cleaning: '", processed_text, "'")
	print("  Final normalized: '", spoken_normalized, "'")
	print("  Target: '", target_normalized, "'")
	
	# Enhanced similarity calculation like ReadAloudGuided
	var similarity = _calculate_enhanced_sentence_similarity(spoken_normalized, target_normalized)
	print("SyllableBuildingModule: Enhanced similarity score: ", similarity)
	
	# More forgiving thresholds for dyslexic learners (same as ReadAloudGuided)
	if similarity >= 0.8: # 80% similarity - excellent match
		_handle_correct_response("excellent_match")
	elif similarity >= 0.65: # 65% similarity - good attempt
		_handle_correct_response("good_match")
	elif similarity >= 0.4: # 40% similarity - partial match, still count as success for encouragement
		_handle_correct_response("partial_match")
	else:
		_handle_incorrect_response(spoken_text)
	
	# Reset processing flag
	result_being_processed = false

func _check_syllable_sequence(spoken: String, target_syllables: Array) -> bool:
	"""Check if spoken text contains syllables in sequence"""
	var spoken_words = spoken.split(" ")
	
	# Check if syllables appear in order
	var syllable_index = 0
	for spoken_word in spoken_words:
		if syllable_index < target_syllables.size():
			var target_syllable = target_syllables[syllable_index].to_lower()
			if _syllables_match(spoken_word, target_syllable):
				syllable_index += 1
	
	return syllable_index >= target_syllables.size()

func _check_partial_syllables(spoken: String, target_syllables: Array) -> bool:
	"""Check for partial syllable matches (dyslexia-friendly)"""
	var spoken_clean = spoken.replace(" ", "")
	var target_word = "".join(target_syllables).to_lower()
	
	# Calculate similarity
	var similarity = _calculate_similarity(spoken_clean, target_word)
	return similarity >= 0.7 # 70% similarity threshold

func _syllables_match(spoken: String, target: String) -> bool:
	"""Check if two syllables match with dyslexia-friendly tolerance"""
	if spoken == target:
		return true
	
	# Allow for common dyslexic substitutions
	var similarity = _calculate_similarity(spoken, target)
	return similarity >= 0.8 # 80% similarity for individual syllables

func _calculate_similarity(word1: String, word2: String) -> float:
	"""Calculate similarity between two words"""
	if word1 == word2:
		return 1.0
	
	var longer = word1 if word1.length() > word2.length() else word2
	
	if longer.length() == 0:
		return 0.0
	
	var distance = _levenshtein_distance(word1, word2)
	return 1.0 - (float(distance) / float(longer.length()))

func _levenshtein_distance(a: String, b: String) -> int:
	"""Calculate Levenshtein distance between two strings"""
	var matrix = []
	for i in range(a.length() + 1):
		matrix.append([])
		for j in range(b.length() + 1):
			matrix[i].append(0)
	
	for i in range(a.length() + 1):
		matrix[i][0] = i
	for j in range(b.length() + 1):
		matrix[0][j] = j
	
	for i in range(1, a.length() + 1):
		for j in range(1, b.length() + 1):
			var cost = 0 if a[i - 1] == b[j - 1] else 1
			matrix[i][j] = min(
				matrix[i - 1][j] + 1, # deletion
				matrix[i][j - 1] + 1, # insertion
				matrix[i - 1][j - 1] + cost # substitution
			)
	
	return matrix[a.length()][b.length()]

func _handle_correct_response(match_type: String):
	"""Handle correct syllable recognition"""
	var current_data = syllable_words[current_word_index]
	var current_word = current_data["word"]
	
	stt_status_label.text = "Excellent!"
	stt_result_label.text = "Perfect syllable breaking!"
	stt_result_label.modulate = Color.GREEN
	
	# Only highlight the whole word (remove syllable highlighting)
	_apply_word_highlighting()
	
	# Stop STT automatically like ReadAloudGuided
	if recognition_active:
		_stop_syllable_recognition()
		print("SyllableBuildingModule: Automatically stopped STT after correct recognition")
	
	# Mark activity as completed AND SAVE IMMEDIATELY
	if not current_word in completed_activities:
		completed_activities.append(current_word)
		# Save completion immediately to Firebase
		await _save_progress()
		print("SyllableBuildingModule: Word '", current_word, "' completion saved to Firebase")
	
	# Show completion celebration instead of auto-advancing
	await get_tree().create_timer(1.5).timeout
	if completion_celebration:
		# Prepare progress data for celebration
		var progress_data = {
			"activities_completed": completed_activities,
			"total_words": syllable_words.size()
		}
		completion_celebration.show_completion(
			completion_celebration.CompletionType.SYLLABLE_WORD,
			current_word,
			progress_data,
			"read_aloud"
		)
		print("SyllableBuildingModule: Showing completion celebration for word: ", current_word)
	
	print("SyllableBuildingModule: Correct syllable recognition for ", current_word, " (", match_type, ")")

func _handle_incorrect_response(spoken_text: String):
	"""Handle incorrect syllable recognition"""
	stt_status_label.text = "Try again"
	stt_result_label.text = "Heard: '" + spoken_text + "' - Listen to the syllables and try again"
	stt_result_label.modulate = Color.ORANGE
	
	# Automatically replay syllables for guidance
	await get_tree().create_timer(1.0).timeout
	_on_hear_syllables_button_pressed()

func _save_progress():
	"""Save syllable workshop progress to Firebase"""
	if module_progress and module_progress.is_authenticated():
		var current_word = syllable_words[current_word_index]["word"]
		var success = await module_progress.complete_syllable_workshop_activity(current_word)
		if success:
			print("SyllableBuildingModule: Successfully saved syllable workshop progress for: ", current_word)
		else:
			print("SyllableBuildingModule: Failed to save syllable workshop progress")
		
		# Save current position (for resume functionality)
		var index_success = await module_progress.set_syllable_workshop_current_index(current_word_index)
		if index_success:
			print("SyllableBuildingModule: Successfully saved current word index: ", current_word_index)
		
		_update_progress_display()

func _on_prev_button_pressed():
	$ButtonClick.play()
	if current_word_index > 0:
		current_word_index -= 1
		_update_word_display()
		_update_navigation_buttons()
		
		# Clear STT results
		stt_result_label.text = ""
		stt_status_label.text = "Click to start recording"

func _on_next_button_pressed():
	$ButtonClick.play()
	if current_word_index < syllable_words.size() - 1:
		current_word_index += 1
		_update_word_display()
		_update_navigation_buttons()
		
		# Clear STT results
		stt_result_label.text = ""
		stt_status_label.text = "Click to start recording"
	else:
		# Completed all words
		_show_completion_message()

func _show_completion_message():
	"""Show completion message when all syllable activities are done"""
	stt_status_label.text = "All syllable activities completed!"
	stt_result_label.text = "Great job with phonological awareness!"
	stt_result_label.modulate = Color.GREEN

func _fade_out_and_change_scene(scene_path: String):
	"""Fade out and change to target scene"""
	# Stop TTS and STT before changing scenes like ReadAloudGuided
	_stop_tts()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _exit_tree():
	"""Clean up when leaving scene"""
	if recognition_active:
		_stop_syllable_recognition()
	_stop_tts()

# Clean up TTS when leaving scene
func _stop_tts():
	"""Stop any active TTS speech - copied from ReadAloudGuided pattern"""
	if tts:
		tts.stop()
		print("SyllableBuildingModule: Stopped TTS on scene exit")

# TTS finished handler for syllable workshop flow like ReadAloudGuided
func _on_tts_finished():
	"""Called when TTS finishes speaking"""
	print("SyllableBuildingModule: TTS finished")
	# Additional TTS completion logic can be added here if needed

# Highlighting reset timeout handler like ReadAloudGuided
func _on_highlighting_reset_timeout():
	"""Called when highlighting reset timer expires - clears yellow highlighting for incomplete speech"""
	print("SyllableBuildingModule: Auto-resetting yellow highlighting due to incomplete speech")
	_clear_highlighting()
	
	# Update status to encourage trying again
	if stt_status_label:
		stt_status_label.text = "Try saying the word again"
	if stt_result_label:
		stt_result_label.text = "Click Speak to try again"

func _on_guide_button_pressed():
	$ButtonClick.play()
	"""Guide button - Provide TTS guidance for syllable building"""
	if tts:
		var guide_text = "Welcome to Syllable Workshop! This activity helps you break words into syllables. Listen to each word by clicking 'Hear Word', then hear it broken into syllables with 'Hear Syllables'. Practice saying the syllables yourself using the microphone button. Syllables are the building blocks of words - like clapping out the beats in music!"
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

# Completion celebration handlers
func _on_celebration_try_again():
	"""Handle 'Try Again' button from completion celebration"""
	print("SyllableBuildingModule: Celebration 'Try Again' pressed - replaying current word")
	
	# Clear highlighting
	_clear_highlighting()
	
	# Reset current word recognition
	if stt_result_label:
		stt_result_label.text = ""
	if stt_status_label:
		stt_status_label.text = "Click Speak to begin"
	
	# Reset STT states
	recognition_active = false
	stt_listening = false
	result_being_processed = false
	
	# Update STT button
	if stt_button:
		stt_button.text = "Speak"
		stt_button.disabled = false
	
	print("SyllableBuildingModule: Ready to practice same word again")

func _on_celebration_next():
	"""Handle 'Next' button from completion celebration"""
	print("SyllableBuildingModule: Celebration 'Next' pressed - advancing to next word")
	
	# Hide celebration immediately
	if completion_celebration:
		completion_celebration.hide()
	
	# Clear highlighting before moving to next word
	_clear_highlighting()
	
	# Check if more words available
	if current_word_index < syllable_words.size() - 1:
		# Move to next word FIRST
		current_word_index += 1
		print("SyllableBuildingModule: Advanced to word ", current_word_index + 1, " (", syllable_words[current_word_index].word, ")")
		
		# Save the NEW position to Firebase (completion already saved in _handle_correct_response)
		await _save_current_position()
		
		# Display new word
		_update_word_display()
		_update_navigation_buttons()
		_update_progress_display()
		
		# Reset STT for new word
		if stt_result_label:
			stt_result_label.text = ""
		if stt_status_label:
			stt_status_label.text = "Click Speak to begin"
		
		# Reset STT states
		recognition_active = false
		stt_listening = false
		result_being_processed = false
		
		# Update STT button
		if stt_button:
			stt_button.text = "Speak"
			stt_button.disabled = false
	else:
		# All words completed - show completion
		_show_completion_message()

func _save_current_position():
	"""Save only the current position (for navigation)"""
	if module_progress and module_progress.is_authenticated():
		var index_success = await module_progress.set_syllable_workshop_current_index(current_word_index)
		if index_success:
			print("SyllableBuildingModule: Successfully saved current position: ", current_word_index)
		else:
			print("SyllableBuildingModule: Failed to save current position")

func _on_celebration_closed():
	"""Handle celebration popup being closed"""
	print("SyllableBuildingModule: Celebration popup closed")

func _apply_word_highlighting():
	"""Apply yellow highlighting to the whole word when fully completed"""
	if not current_word_label:
		return
	
	var current_data = syllable_words[current_word_index]
	var word = current_data["word"]
	
	# RichTextLabel with BBCode enabled in scene
	# Highlight the whole word with yellow background
	current_word_label.text = "[center][bgcolor=yellow][color=black]" + word + "[/color][/bgcolor][/center]"
	print("SyllableBuildingModule: Applied yellow highlighting to word: ", word)

func _clear_highlighting():
	"""Clear all highlighting and reset to normal display"""
	highlighted_syllables.clear()
	highlighted_words.clear()
	_update_word_display() # Reset to normal display
	print("SyllableBuildingModule: Cleared all highlighting")

# Live highlighting during speech recognition (word only)
func _update_live_syllable_highlighting(interim_text: String):
	"""Update live word highlighting based on STT interim results - SINGLE WORD FOCUS like WordChallengePanel_STT"""
	if current_target_syllables.is_empty():
		return
		
	# Clean and process interim text
	var processed_interim = _clean_text_for_words(interim_text.to_lower())
	
	# EXTRACT ONLY THE LAST WORD - Focus on single word like WordChallengePanel_STT
	var words = processed_interim.strip_edges().split(" ")
	var last_word = ""
	if words.size() > 0:
		# Get the last non-empty word
		for i in range(words.size() - 1, -1, -1):
			if words[i].strip_edges() != "":
				last_word = words[i].strip_edges()
				break
	
	# Use only the last word for comparison
	var display_word = last_word.to_lower().strip_edges()
	var current_word = syllable_words[current_word_index]["word"].to_lower()
	
	print("SyllableBuildingModule: Live highlighting check - Last Word: '", display_word, "' Target: '", current_word, "'")
	
	# Check if last word matches the target word using single word similarity
	var similarity = _calculate_word_similarity(display_word, current_word)
	print("SyllableBuildingModule: Live similarity score: ", similarity)
	
	# Apply highlighting if similarity is excellent (trigger fast success)
	if similarity >= 0.85: # 85% similarity for fast success
		_apply_word_highlighting()
		print("SyllableBuildingModule: FAST SUCCESS - Live highlighted word from: '", display_word, "' (similarity: ", similarity, ")")
		
		# Trigger fast success processing
		_trigger_fast_success()
		
	elif similarity >= 0.7: # 70% similarity for live highlighting
		_apply_word_highlighting()
		print("SyllableBuildingModule: Live highlighted word from: '", display_word, "' (similarity: ", similarity, ")")
		
		# Start highlighting reset timer in case speech stops midway
		if highlighting_reset_timer:
			highlighting_reset_timer.start(2.0) # Reset after 2 seconds of no speech
	else:
		# Reset to normal display if no match
		_update_word_display()

func _trigger_fast_success():
	"""Trigger fast success when excellent live match is detected - like ReadAloudGuided"""
	if result_being_processed:
		return
	
	print("SyllableBuildingModule: Triggering fast success processing")
	
	# Stop highlighting reset timer since we found a match
	if highlighting_reset_timer:
		highlighting_reset_timer.stop()
	
	# Stop STT recognition since we got the answer
	_stop_syllable_recognition()
	
	# Process as successful recognition
	var current_word = syllable_words[current_word_index]["word"]
	_check_syllable_recognition(current_word) # Use the target word as "recognized" text

func _clean_text_for_words(text: String) -> String:
	"""Clean text and keep only letters and spaces - COPIED from ReadAloudGuided"""
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z ]")
	var cleaned = regex.sub(text, "", true)
	
	# Normalize multiple spaces to single space
	var space_regex = RegEx.new()
	space_regex.compile("[ ]+")
	cleaned = space_regex.sub(cleaned, " ", true)
	
	return cleaned.strip_edges()

func _calculate_enhanced_sentence_similarity(text1: String, text2: String) -> float:
	"""Calculate similarity between two strings - COPIED from ReadAloudGuided"""
	if text1.is_empty() or text2.is_empty():
		return 0.0
	
	if text1 == text2:
		return 1.0
	
	# Split into words
	var words1 = text1.split(" ")
	var words2 = text2.split(" ")
	
	# For single words (syllable case), use word-level similarity
	if words1.size() == 1 and words2.size() == 1:
		return _calculate_word_similarity(words1[0], words2[0])
	
	# For multiple words, calculate word-by-word similarity
	var total_score = 0.0
	var word_count = max(words1.size(), words2.size())
	
	for i in range(word_count):
		var word1 = words1[i] if i < words1.size() else ""
		var word2 = words2[i] if i < words2.size() else ""
		
		if word1.is_empty() or word2.is_empty():
			continue
		
		total_score += _calculate_word_similarity(word1, word2)
	
	return total_score / word_count if word_count > 0 else 0.0

func _calculate_word_similarity(word1: String, word2: String) -> float:
	"""Calculate similarity between two words - ENHANCED from ReadAloudGuided"""
	if word1 == word2:
		return 1.0
	
	if word1.is_empty() or word2.is_empty():
		return 0.0
	
	# Calculate Levenshtein similarity using existing function
	var distance = _levenshtein_distance(word1, word2)
	var max_length = max(word1.length(), word2.length())
	var similarity = 1.0 - (float(distance) / float(max_length)) if max_length > 0 else 0.0
	
	return similarity

func _clean_text_for_syllables(text: String) -> String:
	"""Clean text for syllable matching - DEPRECATED, use _clean_text_for_words instead"""
	return _clean_text_for_words(text)

# Enhanced progress saving with better error handling
func _save_current_progress():
	"""Save current progress with enhanced error handling"""
	if not is_instance_valid(module_progress):
		print("SyllableBuildingModule: ModuleProgress not available for saving")
		return
	
	print("SyllableBuildingModule: Saving current position: ", current_word_index, " out of ", syllable_words.size(), " words")
	
	# Save current position using existing ModuleProgress method
	var save_success = await module_progress.set_syllable_workshop_current_index(current_word_index)
	if save_success:
		print("SyllableBuildingModule: Current position saved successfully")
	else:
		print("SyllableBuildingModule: Failed to save current position to Firebase")

# Enhanced initialization completion check
func _ensure_all_systems_ready():
	"""Ensure all systems are ready before allowing interactions"""
	var systems_ready = (
		is_instance_valid(tts) and
		is_instance_valid(tts_timer) and
		is_instance_valid(highlighting_reset_timer) and
		permission_check_complete
	)
	
	print("SyllableBuildingModule: All systems ready: ", systems_ready)
	return systems_ready

func _is_word_match_for_highlighting(spoken_text: String, target_word: String) -> bool:
	"""Check if spoken text matches target word for live highlighting"""
	if spoken_text == target_word:
		return true
		
	# Calculate similarity (same as syllables but for whole word)
	var distance = _levenshtein_distance(spoken_text, target_word)
	var max_length = max(spoken_text.length(), target_word.length())
	var similarity = 1.0 - (float(distance) / max_length) if max_length > 0 else 0.0
	
	# 70% similarity for live highlighting (same as ReadAloudGuided)
	return similarity >= 0.7