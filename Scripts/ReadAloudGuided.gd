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
	
	# Enhanced fade-in animation matching ReadAloudStories
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
	"""Check for speech recognition results"""
	if stt_listening and OS.get_name() == "Web":
		var result_json = JavaScriptBridge.eval("getGuidedSttResult();")
		if result_json != null and result_json != "":
			var json = JSON.new()
			var parse_result = json.parse(result_json)
			
			if parse_result == OK:
				var result_data = json.data
				if result_data.has("success") and result_data.success:
					var text = result_data.get("text", "")
					var confidence = result_data.get("confidence", 0.8)
					_handle_stt_result(text, confidence)
				elif result_data.has("error"):
					var error = result_data.get("error", "unknown")
					_handle_stt_error(error)
				
				stt_listening = false
				_update_listen_button()

func _initialize_web_audio_environment():
	"""Initialize JavaScript environment for web audio - Simplified approach"""
	var js_code = """
	// Speech recognition setup for ReadAloudGuided
	window.guidedSttRecognition = null;
	window.guidedSttActive = false;
	window.guidedSttCallback = null;
	
	function initGuidedSpeechRecognition() {
		if ('webkitSpeechRecognition' in window) {
			window.guidedSttRecognition = new webkitSpeechRecognition();
		} else if ('SpeechRecognition' in window) {
			window.guidedSttRecognition = new SpeechRecognition();
		} else {
			console.log('Speech recognition not supported');
			return false;
		}
		
		var recognition = window.guidedSttRecognition;
		recognition.continuous = false;
		recognition.interimResults = false;
		recognition.lang = 'en-US';
		recognition.maxAlternatives = 1;
		
		recognition.onresult = function(event) {
			var result = event.results[0];
			var transcript = result[0].transcript;
			var confidence = result[0].confidence || 0.8;
			
			console.log('Speech result:', transcript, 'Confidence:', confidence);
			
			window.guidedSttResult = {
				ready: true,
				success: true,
				text: transcript,
				confidence: confidence
			};
		};
		
		recognition.onerror = function(event) {
			console.log('Speech recognition error:', event.error);
			window.guidedSttResult = {
				ready: true,
				success: false,
				error: event.error
			};
		};
		
		recognition.onend = function() {
			window.guidedSttActive = false;
			console.log('Speech recognition ended');
		};
		
		return true;
	}
	
	function startGuidedSpeechRecognition() {
		if (window.guidedSttRecognition && !window.guidedSttActive) {
			try {
				window.guidedSttRecognition.start();
				window.guidedSttActive = true;
				window.guidedSttResult = { ready: false };
				return true;
			} catch (e) {
				console.log('Failed to start speech recognition:', e);
				return false;
			}
		}
		return false;
	}
	
	function stopGuidedSpeechRecognition() {
		if (window.guidedSttRecognition && window.guidedSttActive) {
			window.guidedSttRecognition.stop();
			window.guidedSttActive = false;
		}
	}
	
	function getGuidedSttResult() {
		if (window.guidedSttResult && window.guidedSttResult.ready) {
			var result = window.guidedSttResult;
			window.guidedSttResult = { ready: false };
			return JSON.stringify(result);
		}
		return null;
	}
	"""
	
	JavaScriptBridge.eval(js_code)
	var init_result = JavaScriptBridge.eval("initGuidedSpeechRecognition();")
	print("ReadAloudGuided: Speech recognition initialized: ", init_result)

func _check_and_wait_for_permissions():
	"""Check microphone permissions"""
	var permission_js = """
	navigator.permissions.query({name: 'microphone'}).then(function(result) {
		godot.ReadAloudGuided.update_mic_permission_state(result.state);
	}).catch(function(error) {
		console.log('Permission check failed:', error);
		godot.ReadAloudGuided.update_mic_permission_state('prompt');
	});
	"""
	JavaScriptBridge.eval(permission_js)

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
	if not mic_permission_granted:
		_request_microphone_permission()
		return false
	
	if OS.get_name() == "Web":
		var result = JavaScriptBridge.eval("startGuidedSpeechRecognition();")
		if result:
			recognition_active = true
			stt_listening = true
			_update_listen_button()
			print("ReadAloudGuided: Speech recognition started")
			return true
		else:
			print("ReadAloudGuided: Failed to start web speech recognition")
	
	return false

func _stop_speech_recognition():
	"""Stop speech recognition"""
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("stopGuidedSpeechRecognition();")
	recognition_active = false

func _request_microphone_permission():
	"""Request microphone permission"""
	var request_js = """
	navigator.mediaDevices.getUserMedia({ audio: true })
		.then(function(stream) {
			godot.ReadAloudGuided.update_mic_permission_state('granted');
		})
		.catch(function(error) {
			godot.ReadAloudGuided.update_mic_permission_state('denied');
		});
	"""
	JavaScriptBridge.eval(request_js)

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
	"""Process speech recognition result and compare with target sentence"""
	print("ReadAloudGuided: Recognized: '", recognized_text, "' (confidence: ", confidence, ")")
	print("ReadAloudGuided: Target: '", current_target_sentence, "'")
	
	# Clean and compare text
	var cleaned_recognized = _clean_text_for_comparison(recognized_text)
	var cleaned_target = _clean_text_for_comparison(current_target_sentence)
	
	var similarity = _calculate_sentence_similarity(cleaned_recognized, cleaned_target)
	print("ReadAloudGuided: Similarity score: ", similarity)
	
	# Show feedback based on similarity
	if similarity >= 0.7: # 70% similarity threshold for dyslexic users
		_show_success_feedback(recognized_text)
	elif similarity >= 0.5: # 50% similarity - encourage and show target
		_show_encouragement_feedback(recognized_text, current_target_sentence)
	else:
		_show_try_again_feedback(recognized_text, current_target_sentence)

func _clean_text_for_comparison(text: String) -> String:
	"""Clean text for comparison"""
	return text.to_lower().strip_edges().replace(".", "").replace(",", "").replace("!", "").replace("?", "")

func _calculate_sentence_similarity(text1: String, text2: String) -> float:
	"""Calculate similarity between two sentences"""
	var words1 = text1.split(" ")
	var words2 = text2.split(" ")
	
	var matches = 0
	for word1 in words1:
		if word1 in words2:
			matches += 1
	
	if words2.size() == 0:
		return 0.0
	
	return float(matches) / float(words2.size())

func _show_success_feedback(recognized_text: String):
	"""Show success feedback"""
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
			speak_button.text = "Practice Speaking"
			speak_button.disabled = false
		
		_next_guided_sentence()

func _show_encouragement_feedback(recognized_text: String, target_text: String):
	"""Show encouragement feedback"""
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
		speak_button.text = "Practice Speaking"
		speak_button.disabled = false

func _show_try_again_feedback(_recognized_text: String, target_text: String):
	"""Show try again feedback"""
	var feedback_panel = get_node_or_null("STTFeedbackPanel")
	if feedback_panel:
		var feedback_label = feedback_panel.get_node("FeedbackLabel")
		if feedback_label:
			feedback_label.text = "Let's try again:\n\"" + target_text + "\""
			feedback_label.modulate = Color.ORANGE
		feedback_panel.visible = true
	
	# Reset button state for retry
	var speak_button = $MainContainer/ControlsContainer/SpeakButton
	if speak_button:
		speak_button.text = "Practice Speaking"
		speak_button.disabled = false

func _load_progress():
	if module_progress and module_progress.is_authenticated():
		print("ReadAloudGuided: Loading guided reading progress")
		var progress_data = await module_progress.get_read_aloud_progress()
		if progress_data and progress_data.has("guided_reading"):
			var guided_data = progress_data["guided_reading"]
			completed_activities = guided_data.get("activities_completed", [])
			
			# Find first uncompleted passage for resume
			var resume_index = 0
			for i in range(passages.size()):
				var passage_id = "passage_" + str(i)
				if not passage_id in completed_activities:
					resume_index = i
					break
			
			current_passage_index = resume_index
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

func _on_next_passage_button_pressed():
	$ButtonClick.play()
	if current_passage_index < passages.size() - 1:
		_stop_guided_reading()
		current_passage_index += 1
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
			listen_button.text = "Practice Speaking"
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
	"""Practice Speaking button - STT functionality for current sentence"""
	$ButtonClick.play()
	print("ReadAloudGuided: Practice Speaking button pressed")
	
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
						speak_button.text = "Practice Speaking"
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
