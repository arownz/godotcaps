extends Control

# Core systems
var tts: TextToSpeech = null
var module_progress = null
var current_passage_index: int = 0
var is_reading: bool = false
var current_sentence_index: int = 0
var reading_speed: float = 150.0 # words per minute
var completed_activities: Array = [] # Track completed guided reading activities

# STT functionality
var recognition_active = false
var mic_permission_granted = false
var permission_check_complete = false
var current_target_sentence = ""
var stt_feedback_active = false
var stt_listening = false

# Guided Reading Passages - dyslexia-friendly with structured guidance
var passages = [
	{
		"title": "The Friendly Cat",
		"text": "Mia has a cat named Sam. Sam is orange and white. Sam likes to play with a red ball. Mia gives Sam food every day. Sam is very happy.",
		"sentences": [
			"Mia has a cat named Sam.",
			"Sam is orange and white.",
			"Sam likes to play with a red ball.",
			"Mia gives Sam food every day.",
			"Sam is very happy."
		],
		"guide_notes": [
			"Let's read about Mia and her cat. Take your time with each sentence.",
			"Notice the color words: orange, white, and red.",
			"Listen for the action words: play, gives, likes.",
			"See how each sentence tells us something new about Sam.",
			"Think about how Sam feels at the end."
		],
		"vocabulary": [
			{"word": "happy", "definition": "feeling good and cheerful"}
		],
		"level": 1
	},
	{
		"title": "The Garden Surprise",
		"text": "Ben planted seeds in his garden. He watered them every day. Small green plants started to grow. After many weeks, big red tomatoes appeared. Ben picked them for dinner.",
		"sentences": [
			"Ben planted seeds in his garden.",
			"He watered them every day.",
			"Small green plants started to grow.",
			"After many weeks, big red tomatoes appeared.",
			"Ben picked them for dinner."
		],
		"guide_notes": [
			"This story teaches patience and caring for plants.",
			"Notice the time words: every day, many weeks.",
			"Watch for the growing process: seeds, plants, tomatoes.",
			"Think about how hard work pays off.",
			"Think about what Ben can do with his tomatoes."
		],
		"vocabulary": [
			{"word": "appeared", "definition": "showed up or became visible"}
		],
		"level": 1
	},
	{
		"title": "The School Bus Adventure",
		"text": "Every morning, Lisa waits for the yellow school bus. The bus driver, Mr. Joe, always waves hello. Lisa sits with her friend Emma. They talk about their favorite books. When they reach school, they are ready to learn.",
		"sentences": [
			"Every morning, Lisa waits for the yellow school bus.",
			"The bus driver, Mr. Joe, always waves hello.",
			"Lisa sits with her friend Emma.",
			"They talk about their favorite books.",
			"When they reach school, they are ready to learn."
		],
		"guide_notes": [
			"This story shows a daily routine and friendship.",
			"Notice the friendly characters: Lisa, Mr. Joe, Emma.",
			"Think about routines that happen every day.",
			"See how friends enjoy talking together.",
			"Think about how the girls feel about going to school."
		],
		"vocabulary": [
			{"word": "favorite", "definition": "the thing you like best"}
		],
		"level": 2
	},
	{
		"title": "The Rainy Day Plan",
		"text": "Dark clouds covered the sky on Saturday morning. Rain began to fall softly. Maria and her brother Carlos could not play outside. Instead, they decided to build a fort with blankets and chairs. They had fun reading stories inside their cozy fort.",
		"sentences": [
			"Dark clouds covered the sky on Saturday morning.",
			"Rain began to fall softly.",
			"Maria and her brother Carlos could not play outside.",
			"Instead, they decided to build a fort with blankets and chairs.",
			"They had fun reading stories inside their cozy fort."
		],
		"guide_notes": [
			"This story shows how to make the best of rainy weather.",
			"Notice the weather words: dark clouds, rain, softly.",
			"Watch for the describing words: dark, softly, cozy.",
			"Think about creative ways to have fun indoors.",
			"See how siblings can work together and have fun."
		],
		"vocabulary": [
			{"word": "cozy", "definition": "warm and comfortable"}
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
	else:
		tts.set_rate(0.8) # Slightly slower for dyslexic learners

func _init_module_progress():
	if Firebase and Firebase.Auth and Firebase.Auth.auth:
		module_progress = ModuleProgress.new()
		print("ReadAloudGuided: ModuleProgress initialized")
	else:
		print("ReadAloudGuided: Firebase not available, using local tracking")

func _connect_button_events():
	"""Connect all button events with hover sounds"""
	var buttons = [
		$MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton,
		$MainContainer/HeaderPanel/GuideButton,
		$MainContainer/HeaderPanel/TTSSettingButton,
		$MainContainer/ControlsContainer/PreviousButton,
		$MainContainer/ControlsContainer/ReadButton,
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
	"""Check for speech recognition results - Enhanced polling like WordChallengePanel_STT"""
	if stt_listening and OS.get_name() == "Web" and JavaScriptBridge.has_method("eval"):
		# Check for recognition results
		var result_json = JavaScriptBridge.eval("getGuidedResult();")
		if result_json != null and result_json != "" and result_json != "null":
			var json = JSON.new()
			var parse_result = json.parse(result_json)
			
			if parse_result == OK:
				var result_data = json.data
				print("ReadAloudGuided: Got STT result: ", result_data)
				
				if result_data.has("type"):
					if result_data.type == "result" and result_data.has("text"):
						var text = result_data.text
						if text and text.length() > 0:
							print("ReadAloudGuided: Processing speech result: ", text)
							stt_listening = false
							_handle_stt_result(text, 0.8) # Default confidence
					elif result_data.type == "error" and result_data.has("error"):
						var error = result_data.error
						print("ReadAloudGuided: Speech recognition error: ", error)
						stt_listening = false
						_handle_stt_error(error)
		
		# Also check for interim results for live feedback (optional)
		var interim_result = JavaScriptBridge.eval("getGuidedInterimResult();")
		if interim_result != null and interim_result != "" and interim_result != "null":
			# Show interim feedback (optional live transcription)
			var interim_text = str(interim_result).strip_edges()
			if interim_text.length() > 0 and interim_text != current_target_sentence:
				# Could show live transcription here if desired
				pass

func _initialize_web_audio_environment():
	"""Initialize JavaScript environment for web audio - FIXED ENGINE DETECTION"""
	if JavaScriptBridge.has_method("eval"):
		var js_code = """
		// Global speech recognition variables
		window.guidedRecognition = null;
		window.guidedRecognitionActive = false;
		window.guidedPermissionGranted = false;
		window.guidedPermissionChecked = false;
		window.guidedFinalResult = '';
		window.guidedInterimResult = '';
		window.guidedResult = null;
		
		// Permission check function
		function checkGuidedPermissions() {
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
		}
		
		// Request microphone permission
		function requestGuidedMicPermission() {
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
		}
		
		// Initialize speech recognition
		function initGuidedSpeechRecognition() {
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
				recognition.continuous = false;
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
					
					console.log('ReadAloudGuided: Final:', finalTranscript, 'Interim:', interimTranscript);
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
				};
				
				return true;
			} catch (error) {
				console.log('ReadAloudGuided: Failed to initialize recognition:', error);
				return false;
			}
		}
		
		// Start recognition
		function startGuidedRecognition() {
			if (!window.guidedRecognition) {
				console.log('ReadAloudGuided: Recognition not initialized');
				return false;
			}
			
			if (window.guidedRecognitionActive) {
				console.log('ReadAloudGuided: Recognition already active');
				return false;
			}
			
			try {
				window.guidedResult = null; // Clear previous result
				window.guidedRecognition.start();
				return true;
			} catch (error) {
				console.log('ReadAloudGuided: Failed to start recognition:', error);
				return false;
			}
		}
		
		// Stop recognition
		function stopGuidedRecognition() {
			if (window.guidedRecognition && window.guidedRecognitionActive) {
				try {
					window.guidedRecognition.stop();
				} catch (error) {
					console.log('ReadAloudGuided: Error stopping recognition:', error);
				}
			}
		}
		
		// Get recognition result
		function getGuidedResult() {
			if (window.guidedResult) {
				var result = window.guidedResult;
				window.guidedResult = null; // Clear after reading
				return JSON.stringify(result);
			}
			return null;
		}
		
		// Get interim result for live feedback
		function getGuidedInterimResult() {
			return window.guidedInterimResult || '';
		}
		
		// Check if recognition is active
		function isGuidedRecognitionActive() {
			return window.guidedRecognitionActive || false;
		}
		
		// Initialize everything
		checkGuidedPermissions();
		var initResult = initGuidedSpeechRecognition();
		console.log('ReadAloudGuided: Initialization complete:', initResult);
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
			checkGuidedPermissions();
			
			// Wait for permission check to complete
			var checkInterval = setInterval(function() {
				if (window.guidedPermissionChecked) {
					clearInterval(checkInterval);
					// Use a more direct approach to communicate with Godot
					console.log('ReadAloudGuided: Permission granted:', window.guidedPermissionGranted);
				}
			}, 50);
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
	else:
		mic_permission_granted = false
		print("ReadAloudGuided: Microphone permission: ", state)

func _start_speech_recognition():
	"""Start speech recognition"""
	print("ReadAloudGuided: Starting speech recognition...")
	
	if not mic_permission_granted:
		print("ReadAloudGuided: Requesting microphone permission...")
		_request_microphone_permission()
		return false
	
	if OS.get_name() == "Web":
		if JavaScriptBridge.has_method("eval"):
			var result = JavaScriptBridge.eval("startGuidedRecognition();")
			if result:
				recognition_active = true
				stt_listening = true
				_update_listen_button()
				print("ReadAloudGuided: Speech recognition started successfully")
				return true
			else:
				print("ReadAloudGuided: Failed to start web speech recognition")
	
	return false

func _stop_speech_recognition():
	"""Stop speech recognition"""
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("stopGuidedRecognition();")
	recognition_active = false
	stt_listening = false
	_update_listen_button()

func _request_microphone_permission():
	"""Request microphone permission"""
	print("ReadAloudGuided: Requesting microphone permission...")
	permission_check_complete = false
	
	if JavaScriptBridge.has_method("eval"):
		var request_js = """
		(function() {
			requestGuidedMicPermission().then(function(granted) {
				window.guidedPermissionGranted = granted;
				window.guidedPermissionChecked = true;
				console.log('ReadAloudGuided: Permission request result:', granted);
			});
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
	"""Apply phonetic improvements for dyslexic-friendly recognition"""
	if recognized_text.is_empty() or target_sentence.is_empty():
		return recognized_text
	
	var target_lower = target_sentence.to_lower().strip_edges()
	var recognized_lower = recognized_text.to_lower().strip_edges()
	
	# Enhanced phonetic substitutions for better STT accuracy
	var phonetic_substitutions = {
		# Common STT misunderstandings
		"to": "two", "too": "two", "for": "four", "fore": "four", "ate": "eight",
		"won": "one", "sun": "son", "no": "know", "there": "their", "where": "wear",
		"right": "write", "night": "knight", "sea": "see", "be": "bee",
		# Dyslexic common confusions
		"was": "saw", "now": "won", "tap": "pat", "top": "pot", "god": "dog",
		"net": "ten", "rats": "star", "ward": "draw", "evil": "live"
	}
	
	# Split into words and apply substitutions
	var words = recognized_lower.split(" ")
	var improved_words = []
	
	for word in words:
		word = word.strip_edges()
		if word in phonetic_substitutions:
			# Check if the substitution makes sense in context
			var substituted = phonetic_substitutions[word]
			if target_lower.contains(substituted):
				improved_words.append(substituted)
			else:
				improved_words.append(word)
		else:
			improved_words.append(word)
	
	return " ".join(improved_words)

func _calculate_enhanced_sentence_similarity(text1: String, text2: String) -> float:
	"""Calculate enhanced similarity between two sentences with word order flexibility"""
	var words1 = text1.split(" ")
	var words2 = text2.split(" ")
	
	if words2.size() == 0:
		return 0.0
	
	var matches = 0
	var partial_matches = 0
	
	# Count exact word matches
	for word1 in words1:
		if word1 in words2:
			matches += 1
		else:
			# Check for partial/phonetic matches
			for word2 in words2:
				if _is_phonetic_match(word1, word2):
					partial_matches += 1
					break
	
	# Calculate similarity with partial match bonus
	var exact_score = float(matches) / float(words2.size())
	var partial_score = float(partial_matches) / float(words2.size()) * 0.7 # Partial matches worth 70%
	
	return min(exact_score + partial_score, 1.0)

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


func _show_success_feedback(recognized_text: String):
	"""Show success feedback"""
	print("ReadAloudGuided: Success! Moving to next sentence.")
	var feedback_panel = get_node_or_null("STTFeedbackPanel")
	if feedback_panel:
		var feedback_label = feedback_panel.get_node("FeedbackLabel")
		if feedback_label:
			feedback_label.text = "Great reading! ✓\nYou said: \"" + recognized_text + "\""
			feedback_label.modulate = Color.GREEN
		feedback_panel.visible = true
		
		# Auto-hide after 2 seconds and move to next sentence
		await get_tree().create_timer(2.0).timeout
		feedback_panel.visible = false
		stt_feedback_active = false
		
		# Reset button state and advance to next sentence
		var speak_button = $MainContainer/ControlsContainer/SpeakButton
		if speak_button:
			speak_button.text = "Speak"
			speak_button.disabled = false
		
		_next_guided_sentence()

func _show_encouragement_feedback(recognized_text: String, target_text: String):
	"""Show encouragement feedback"""
	print("ReadAloudGuided: Close match, encouraging user to try again.")
	var feedback_panel = get_node_or_null("STTFeedbackPanel")
	if feedback_panel:
		var feedback_label = feedback_panel.get_node("FeedbackLabel")
		if feedback_label:
			feedback_label.text = "Close! Try again:\n\"" + target_text + "\"\nYou said: \"" + recognized_text + "\""
			feedback_label.modulate = Color.YELLOW
		feedback_panel.visible = true
	
	# Reset button state for retry
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.text = "Speak"
		speak_button.disabled = false

func _show_partial_match_feedback(_recognized_text: String, target_text: String):
	"""Show partial match feedback - new function for moderate similarity"""
	print("ReadAloudGuided: Partial match, providing guidance.")
	var feedback_panel = get_node_or_null("STTFeedbackPanel")
	if feedback_panel:
		var feedback_label = feedback_panel.get_node("FeedbackLabel")
		if feedback_label:
			feedback_label.text = "Good try! Let's practice:\n\"" + target_text + "\"\nKeep trying!"
			feedback_label.modulate = Color.ORANGE
		feedback_panel.visible = true
	
	# Reset button state for retry
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.text = "Speak"
		speak_button.disabled = false

func _show_try_again_feedback(_recognized_text: String, target_text: String):
	"""Show try again feedback"""
	print("ReadAloudGuided: Low similarity, asking user to try again.")
	var feedback_panel = get_node_or_null("STTFeedbackPanel")
	if feedback_panel:
		var feedback_label = feedback_panel.get_node("FeedbackLabel")
		if feedback_label:
			feedback_label.text = "Let's try again:\n\"" + target_text + "\""
			feedback_label.modulate = Color.LIGHT_CORAL
		feedback_panel.visible = true
	
	# Reset button state for retry
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.text = "Speak"
		speak_button.disabled = false

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
			if saved_passage_id in completed_activities:
				print("ReadAloudGuided: Saved passage '", saved_passage_id, "' already completed, finding next uncompleted")
				for i in range(passages.size()):
					var passage_id = "passage_" + str(i)
					if not passage_id in completed_activities:
						resume_index = i
						break
			
			current_passage_index = resume_index
			print("ReadAloudGuided: Resuming at passage: ", current_passage_index, " (saved index was: ", saved_index, ")")
			var progress_percent = (float(completed_activities.size()) / float(passages.size())) * 100.0
			_update_progress_display(progress_percent)
		else:
			_update_progress_display(0)
	else:
		_update_progress_display(0)

func _update_progress_display(progress_percentage: float):
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	if progress_bar:
		progress_bar.value = progress_percentage
		print("ReadAloudGuided: Progress updated to ", progress_percentage, "%")

func _setup_initial_display():
	_display_passage(current_passage_index)
	_update_navigation_buttons()

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
	_update_play_button_text()

func _update_navigation_buttons():
	var prev_button = $MainContainer/ControlsContainer/PreviousButton
	var next_button = $MainContainer/ControlsContainer/NextButton
	
	if prev_button:
		prev_button.disabled = (current_passage_index <= 0)
	if next_button:
		next_button.disabled = (current_passage_index >= passages.size() - 1)

func _update_play_button_text():
	var play_button = $MainContainer/ControlsContainer/ReadButton
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
		
		# Highlight current sentence
		_highlight_current_sentence()
		
		# Set up STT feedback
		stt_feedback_active = true
		
		# Start speech recognition
		if not _start_speech_recognition():
			_show_microphone_error()

func _highlight_current_sentence():
	"""Highlight the current sentence for practice"""
	var passage = passages[current_passage_index]
	var text_display = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageText
	
	if text_display and current_sentence_index < passage.sentences.size():
		text_display.clear()
		
		# Add sentences before current one (normal color)
		for i in range(current_sentence_index):
			text_display.append_text(passage.sentences[i])
			if i < current_sentence_index - 1:
				text_display.append_text(" ")
		
		# Add current sentence (highlighted)
		if current_sentence_index > 0:
			text_display.append_text(" ")
		text_display.push_color(Color.YELLOW)
		text_display.push_bgcolor(Color(1, 1, 0, 0.3))
		text_display.append_text(passage.sentences[current_sentence_index])
		text_display.pop()
		text_display.pop()
		
		# Add sentences after current one (normal color)
		for i in range(current_sentence_index + 1, passage.sentences.size()):
			text_display.append_text(" ")
			text_display.append_text(passage.sentences[i])

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
		# All sentences practiced, mark passage as complete
		await _complete_passage()
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
			tts.speak(sentence)
		
		# Wait based on sentence length and reading speed
		var wait_time = _calculate_reading_time(sentence)
		await get_tree().create_timer(wait_time).timeout
		
		# Brief pause between sentences for comprehension
		await get_tree().create_timer(0.5).timeout
	
	# Mark as completed and save progress
	await _complete_passage()
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
	
	# Reset text display to normal
	_display_passage(current_passage_index)

func _complete_passage():
	if module_progress and module_progress.is_authenticated():
		var passage_id = "passage_" + str(current_passage_index)
		print("ReadAloudGuided: Completing passage: ", passage_id)
		
		var success = await module_progress.complete_read_aloud_activity("guided_reading", passage_id)
		
		if success:
			completed_activities.append(passage_id)
			print("ReadAloudGuided: Passage completed and saved!")
		else:
			print("ReadAloudGuided: Failed to save passage completion")

# Button event handlers
func _on_back_button_pressed():
	$ButtonClick.play()
	_fade_out_and_change_scene("res://Scenes/ReadAloudModule.tscn")

func _on_play_button_pressed():
	$ButtonClick.play()
	var play_button = $MainContainer/ControlsContainer/ReadButton
	
	if not is_reading:
		# Start STT practice mode
		is_reading = true
		current_sentence_index = 0
		_start_sentence_practice()
		if play_button:
			play_button.text = "Stop Practice"
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
		_display_passage(current_passage_index)
		_update_navigation_buttons()
		
		# Save current position to Firebase
		if module_progress and module_progress.is_authenticated():
			var save_success = await module_progress.set_read_aloud_current_index("guided_reading", current_passage_index)
			if save_success:
				print("ReadAloudGuided: Saved current position: ", current_passage_index)

func _on_next_passage_button_pressed():
	$ButtonClick.play()
	if current_passage_index < passages.size() - 1:
		_stop_guided_reading()
		current_passage_index += 1
		_display_passage(current_passage_index)
		_update_navigation_buttons()
		
		# Save current position to Firebase
		if module_progress and module_progress.is_authenticated():
			var save_success = await module_progress.set_read_aloud_current_index("guided_reading", current_passage_index)
			if save_success:
				print("ReadAloudGuided: Saved current position: ", current_passage_index)

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
	"""Show completion message when all passages are completed"""
	var title_label = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageTitleLabel
	var text_display = $MainContainer/PassagePanel/MarginContainer/PassageContainer/PassageText
	var guide_display = $MainContainer/GuidePanel/MarginContainer/GuideContainer/GuideNotes
	
	if title_label:
		title_label.text = "All Passages Complete!"
	if text_display:
		text_display.clear()
		text_display.append_text("[center][b]Congratulations![/b]\n\nYou have completed all guided reading passages![/center]")
	if guide_display:
		guide_display.text = "Excellent work! You've mastered guided reading skills."

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
		_load_progress()

# STT Functions for Web Speech API integration
func _update_listen_button():
	"""Update listen button state based on STT status"""
	var listen_button = get_node_or_null("MainContainer/ControlsContainer/SpeakButton")
	if listen_button:
		if stt_listening:
			listen_button.text = "Listening..."
			listen_button.disabled = true
		else:
			listen_button.text = "Speak"
			listen_button.disabled = false

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
	"""Read button - TTS reads one sentence at a time"""
	$ButtonClick.play()
	print("ReadAloudGuided: Read button pressed")

	if current_passage_index < passages.size():
		var passage = passages[current_passage_index]
		
		if current_sentence_index < passage.sentences.size():
			var sentence = passage.sentences[current_sentence_index].strip_edges()
			
			if sentence != "":
				# Highlight current sentence in yellow
				_highlight_sentence(current_sentence_index)
				
				# Update button text to show reading state
				var read_button = $MainContainer/ControlsContainer/ReadButton
				if read_button:
					read_button.text = "Reading..."
					read_button.disabled = true
				
				# Use TTS to read only this sentence
				if tts:
					tts.speak(sentence)
					
					# Calculate reading time based on sentence length
					var words = sentence.split(" ").size()
					var reading_time = (words / float(reading_speed)) * 60.0 # Convert to seconds
					
					# Wait for the sentence to be read, then re-enable buttons
					await get_tree().create_timer(reading_time + 0.5).timeout
					
					if read_button:
						read_button.text = "Read"
						read_button.disabled = false
					
					print("ReadAloudGuided: Finished reading sentence ", current_sentence_index + 1, " of ", passage.sentences.size())
			else:
				print("ReadAloudGuided: Empty sentence, advancing...")
				current_sentence_index += 1
				_on_read_button_pressed() # Try next sentence

func _on_speak_button_pressed():
	"""Speak button - STT functionality for current sentence"""
	$ButtonClick.play()
	print("ReadAloudGuided: Speak button pressed")

	if current_passage_index < passages.size():
		var passage = passages[current_passage_index]
		
		if current_sentence_index < passage.sentences.size():
			var sentence = passage.sentences[current_sentence_index].strip_edges()
			current_target_sentence = sentence
			
			if sentence != "":
				print("ReadAloudGuided: Target sentence for STT: ", sentence)
				
				# Update button text to show listening state
				var speak_button = $MainContainer/ControlsContainer/SpeakButton
				if speak_button:
					speak_button.text = "Listening..."
					speak_button.disabled = true
				
				# Start speech recognition for this specific sentence
				if _start_speech_recognition():
					# STT started successfully
					stt_feedback_active = true
				else:
					print("ReadAloudGuided: Failed to start speech recognition")
					# Reset button state on failure
					if speak_button:
						speak_button.text = "Speak"
						speak_button.disabled = false
			else:
				print("ReadAloudGuided: No sentence to practice")

func _on_guide_button_pressed():
	"""Guide button - Provide TTS guidance for guided reading"""
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Guided Reading! This activity helps you practice reading with step-by-step guidance. Read the guide notes first to understand what to do. Listen to the passage by clicking 'Read', then practice reading each sentence yourself. The yellow highlighting shows you which sentence is being read. Take your time and follow the guidance!"
		tts.speak(guide_text)

func _on_tts_setting_button_pressed():
	"""TTS Settings button - Open TTS settings popup"""
	$ButtonClick.play()
	print("ReadAloudGuided: TTS Settings button pressed")
	
	# Open TTS settings popup
	var tts_popup = load("res://Scenes/TTSSettingsPopup.tscn").instantiate()
	get_tree().current_scene.add_child(tts_popup)
