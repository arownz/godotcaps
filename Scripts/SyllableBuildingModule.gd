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

# Yellow highlighting system for successful recognition
var highlighted_syllables = []
var highlighted_words = []

# Completion celebration system
var completion_celebration: CanvasLayer = null

# Syllable breaking words - progressive difficulty
var syllable_words = [
	# 1 syllable (easy start)
	{"word": "cat", "syllables": ["cat"], "difficulty": 1},
	{"word": "dog", "syllables": ["dog"], "difficulty": 1},
	{"word": "sun", "syllables": ["sun"], "difficulty": 1},
	
	# 2 syllables
	{"word": "basket", "syllables": ["bas", "ket"], "difficulty": 2},
	{"word": "water", "syllables": ["wa", "ter"], "difficulty": 2},
	{"word": "hotdog", "syllables": ["hot", "dog"], "difficulty": 2},
	{"word": "garden", "syllables": ["gar", "den"], "difficulty": 2},
	
	# 3 syllables
	{"word": "basketball", "syllables": ["bas", "ket", "ball"], "difficulty": 3},
	{"word": "banana", "syllables": ["ba", "na", "na"], "difficulty": 3},
	{"word": "vanilla", "syllables": ["va", "nil", "la"], "difficulty": 3}
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
		var interim_check = JavaScriptBridge.eval("window.syllableInterimResult")
		if interim_check and str(interim_check) != "null" and str(interim_check) != "":
			var interim_text = str(interim_check)
			if stt_result_label:
				stt_result_label.text = "Hearing: " + interim_text
			
			# Apply live highlighting during speech like ReadAloudGuided
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
	
	var js_code = """
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
	"""
	
	var result = JavaScriptBridge.eval(js_code)
	if result:
		print("SyllableBuildingModule: JavaScript environment initialized for web speech recognition")
	else:
		print("SyllableBuildingModule: Failed to initialize JavaScript environment")

# Initialize JavaScript environment for web audio - copied from working implementations
func _initialize_web_audio_environment():
	# This function is no longer needed as permission handling is now in _setup_web_speech_recognition
	pass

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
			if (window.stopSyllableRecognition) {
				window.stopSyllableRecognition();
			}
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
	"""Check if spoken text matches target syllables"""
	var current_word = syllable_words[current_word_index]["word"]
	var target_syllables = current_target_syllables
	
	print("SyllableBuildingModule: Checking recognition - Spoken: '", spoken_text, "' Target: ", target_syllables)
	
	# Normalize spoken text
	var spoken_normalized = spoken_text.to_lower().strip_edges()
	
	# Check various matching patterns
	var is_correct = false
	var match_type = ""
	
	# 1. Full word match
	if spoken_normalized == current_word.to_lower():
		is_correct = true
		match_type = "full_word"
	
	# 2. Individual syllable matches
	elif _check_syllable_sequence(spoken_normalized, target_syllables):
		is_correct = true
		match_type = "syllable_sequence"
	
	# 3. Partial syllable recognition (dyslexia-friendly)
	elif _check_partial_syllables(spoken_normalized, target_syllables):
		is_correct = true
		match_type = "partial_syllables"
	
	# Provide feedback
	if is_correct:
		_handle_correct_response(match_type)
	else:
		_handle_incorrect_response(spoken_text)

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
	
	# Mark activity as completed
	if not current_word in completed_activities:
		completed_activities.append(current_word)
		_save_progress()
	
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

func _on_guide_button_pressed():
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
		
		# Save the NEW position to Firebase
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
	"""Update live word highlighting based on STT interim results (simplified)"""
	if current_target_syllables.is_empty():
		return
		
	# Clean and process interim text
	var processed_interim = _clean_text_for_syllables(interim_text.to_lower())
	var current_word = syllable_words[current_word_index]["word"].to_lower()
	
	# Check if interim text matches the target word
	if _is_word_match_for_highlighting(processed_interim, current_word):
		_apply_word_highlighting()
		print("SyllableBuildingModule: Live highlighted word from: '", processed_interim, "'")
	else:
		# Reset to normal display if no match
		_update_word_display()

func _clean_text_for_syllables(text: String) -> String:
	"""Clean text for syllable matching"""
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z ]")
	var cleaned = regex.sub(text, "", true)
	
	# Normalize multiple spaces to single space
	var space_regex = RegEx.new()
	space_regex.compile("[ ]+")
	cleaned = space_regex.sub(cleaned, " ", true)
	
	return cleaned.strip_edges()

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