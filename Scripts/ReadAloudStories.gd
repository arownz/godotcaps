extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null

# STT functionality
var recognition_active = false
var mic_permission_granted = false
var permission_check_complete = false
var current_target_sentence = ""
var current_sentence_for_reading = ""
var stt_feedback_active = false
var stt_listening = false

# Story data - Dyslexia-friendly stories with clear structure
var stories = [
	{
		"title": "The Helpful Cat",
		"text": "Luna is a small cat.\n\nShe lives in a cozy house.\n\nLuna likes to help.\n\nShe helps find lost toys.\n\nShe helps carry light bags.\n\nLuna is a good friend.\n\nEveryone loves Luna.",
		"id": "story_helpful_cat"
	},
	{
		"title": "The Magic Garden",
		"text": "Sam finds a magic garden.\n\nThe flowers are bright colors.\n\nRed roses. Blue bells. Yellow daffodils.\n\nSam waters the plants.\n\nThe garden grows bigger.\n\nNow Sam has many friends who visit.\n\nThe magic garden makes everyone happy.",
		"id": "story_magic_garden"
	},
	{
		"title": "The Little Train",
		"text": "Toby is a little train.\n\nHe works hard every day.\n\nToby carries people to work.\n\nHe carries children to school.\n\nSometimes Toby feels tired.\n\nBut he loves helping people.\n\nToby is proud of his job.",
		"id": "story_little_train"
	},
	{
		"title": "The Kind Baker",
		"text": "Mrs. Rose bakes bread.\n\nHer bakery smells wonderful.\n\nShe makes warm cookies.\n\nShe makes fresh rolls.\n\nChildren love her sweet treats.\n\nMrs. Rose always shares.\n\nShe gives free bread to those who need it.",
		"id": "story_kind_baker"
	},
	{
		"title": "The Brave Firefighter",
		"text": "Jake is a firefighter.\n\nHe helps keep people safe.\n\nJake climbs tall ladders.\n\nHe puts out fires.\n\nHe rescues cats from trees.\n\nJake wears a red helmet.\n\nHe is very brave.",
		"id": "story_brave_firefighter"
	}
]

var current_story_index = 0
var reading_speed = 150 # Words per minute - adjustable for dyslexic readers
var is_playing = false
var current_sentence_index = 0
var story_sentences = []
var completed_stories = []

func _ready():
	print("ReadAloudStories: Story reading module loaded")
	
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
	
	# Connect button events
	_connect_button_events()
	
	# Initialize STT
	_setup_speech_recognition()
	
	# Load progress and display story at resumed position
	await _load_progress()
	_display_current_story()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		call_deferred("_refresh_progress")

func _process(_delta):
	"""Check for speech recognition results"""
	if stt_listening and OS.get_name() == "Web":
		var result_json = JavaScriptBridge.eval("getReadAloudSttResult();")
		if result_json != null and result_json != "":
			var json = JSON.new()
			var parse_result = json.parse(result_json)
			
			if parse_result == OK:
				var result = json.data
				stt_listening = false
				_update_listen_button()
				
				if "error" in result:
					print("ReadAloudStories: Speech recognition error: ", result.error)
					_handle_stt_error(result.error)
				else:
					print("ReadAloudStories: Speech recognition result: ", result.text, " confidence: ", result.confidence)
					_handle_stt_result(result.text, result.confidence)

func _refresh_progress():
	await _load_progress()

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	
	var voice_id = SettingsManager.get_setting("accessibility", "tts_voice_id")
	var rate = SettingsManager.get_setting("accessibility", "tts_rate")
	
	if voice_id != null and voice_id != "":
		tts.set_voice(voice_id)
	if rate != null:
		tts.set_rate(rate)

func _init_module_progress():
	if Firebase and Firebase.Auth and Firebase.Auth.auth:
		module_progress = ModuleProgress.new()
		print("ReadAloudStories: ModuleProgress initialized")
	else:
		print("ReadAloudStories: Firebase not available")

func _setup_speech_recognition():
	"""Initialize speech recognition for web platform"""
	if OS.get_name() == "Web":
		_initialize_web_audio_environment()
		call_deferred("_check_and_wait_for_permissions")

func _initialize_web_audio_environment():
	"""Initialize JavaScript environment for web audio - Simplified approach"""
	var js_code = """
	// Speech recognition setup for ReadAloudStories
	window.readAloudSttRecognition = null;
	window.readAloudSttActive = false;
	window.readAloudSttCallback = null;
	
	function initReadAloudSpeechRecognition() {
		if ('webkitSpeechRecognition' in window) {
			window.readAloudSttRecognition = new webkitSpeechRecognition();
		} else if ('SpeechRecognition' in window) {
			window.readAloudSttRecognition = new SpeechRecognition();
		} else {
			console.log('Speech recognition not supported');
			return false;
		}
		
		var recognition = window.readAloudSttRecognition;
		recognition.continuous = false;
		recognition.interimResults = false;
		recognition.lang = 'en-US';
		recognition.maxAlternatives = 1;
		
		recognition.onresult = function(event) {
			var result = event.results[0];
			var transcript = result[0].transcript;
			var confidence = result[0].confidence || 0.8;
			
			console.log('Speech result:', transcript, 'Confidence:', confidence);
			
			// Store result for Godot to poll
			window.readAloudSttResult = {
				text: transcript,
				confidence: confidence,
				ready: true
			};
		};
		
		recognition.onerror = function(event) {
			console.log('Speech recognition error:', event.error);
			window.readAloudSttResult = {
				error: event.error,
				ready: true
			};
		};
		
		recognition.onend = function() {
			window.readAloudSttActive = false;
			console.log('Speech recognition ended');
		};
		
		return true;
	}
	
	function startReadAloudSpeechRecognition() {
		if (window.readAloudSttRecognition && !window.readAloudSttActive) {
			try {
				window.readAloudSttResult = { ready: false };
				window.readAloudSttRecognition.start();
				window.readAloudSttActive = true;
				return true;
			} catch (e) {
				console.log('Error starting recognition:', e);
				return false;
			}
		}
		return false;
	}
	
	function stopReadAloudSpeechRecognition() {
		if (window.readAloudSttRecognition && window.readAloudSttActive) {
			window.readAloudSttRecognition.stop();
			window.readAloudSttActive = false;
		}
	}
	
	function getReadAloudSttResult() {
		if (window.readAloudSttResult && window.readAloudSttResult.ready) {
			var result = window.readAloudSttResult;
			window.readAloudSttResult = { ready: false };
			return JSON.stringify(result);
		}
		return null;
	}
	"""
	
	JavaScriptBridge.eval(js_code)
	var init_result = JavaScriptBridge.eval("initReadAloudSpeechRecognition();")
	print("ReadAloudStories: Speech recognition initialized: ", init_result)

func _check_and_wait_for_permissions():
	"""Check microphone permissions"""
	var permission_js = """
	navigator.permissions.query({name: 'microphone'}).then(function(result) {
		godot.ReadAloudStories.update_mic_permission_state(result.state);
	}).catch(function(error) {
		console.log('Permission check failed:', error);
		godot.ReadAloudStories.update_mic_permission_state('prompt');
	});
	"""
	JavaScriptBridge.eval(permission_js)

func update_mic_permission_state(state):
	"""Callback for permission state updates"""
	permission_check_complete = true
	if state == "granted":
		mic_permission_granted = true
		print("ReadAloudStories: Microphone permission granted")
	else:
		mic_permission_granted = false
		print("ReadAloudStories: Microphone permission: ", state)

func _start_speech_recognition():
	"""Start speech recognition"""
	if not mic_permission_granted:
		_request_microphone_permission()
		return false
	
	if OS.get_name() == "Web":
		var result = JavaScriptBridge.eval("startReadAloudSpeechRecognition();")
		if result:
			recognition_active = true
			stt_listening = true
			_update_listen_button()
			print("ReadAloudStories: Speech recognition started")
			return true
		else:
			print("ReadAloudStories: Failed to start speech recognition")
			return false
	
	return false

func _stop_speech_recognition():
	"""Stop speech recognition"""
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("stopReadAloudSpeechRecognition();")
	recognition_active = false

func _request_microphone_permission():
	"""Request microphone permission"""
	var request_js = """
	navigator.mediaDevices.getUserMedia({ audio: true })
		.then(function(stream) {
			stream.getTracks().forEach(track => track.stop());
			godot.ReadAloudStories.update_mic_permission_state('granted');
		})
		.catch(function(error) {
			console.log('Microphone permission denied:', error);
			godot.ReadAloudStories.update_mic_permission_state('denied');
		});
	"""
	JavaScriptBridge.eval(request_js)

func speech_result_callback(text, confidence):
	"""Callback for speech recognition results"""
	if stt_feedback_active:
		_process_speech_result(text, confidence)

func speech_error_callback(error):
	"""Callback for speech recognition errors"""
	print("ReadAloudStories: Speech recognition error: ", error)
	recognition_active = false

func recognition_ended_callback():
	"""Callback when recognition ends"""
	recognition_active = false

func _process_speech_result(recognized_text: String, confidence: float):
	"""Process speech recognition result and compare with target sentence"""
	print("ReadAloudStories: Recognized: '", recognized_text, "' (confidence: ", confidence, ")")
	print("ReadAloudStories: Target: '", current_target_sentence, "'")
	
	# Clean and compare text
	var cleaned_recognized = _clean_text_for_comparison(recognized_text)
	var cleaned_target = _clean_text_for_comparison(current_target_sentence)
	
	var similarity = _calculate_sentence_similarity(cleaned_recognized, cleaned_target)
	print("ReadAloudStories: Similarity score: ", similarity)
	
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
			speak_button.text = "Speak"
			speak_button.disabled = false
		
		_next_sentence_practice()

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
		speak_button.text = "Speak"
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
		speak_button.text = "Speak"
		speak_button.disabled = false

func _load_progress():
	"""Load read aloud progress from Firebase and resume at correct position"""
	if not module_progress or not module_progress.is_authenticated():
		print("ReadAloudStories: Module progress not available")
		return
	
	var read_aloud_data = await module_progress.get_read_aloud_progress()
	if read_aloud_data and read_aloud_data.has("story_reading"):
		var story_data = read_aloud_data["story_reading"]
		completed_stories = story_data.get("activities_completed", [])
		print("ReadAloudStories: Loaded completed stories: ", completed_stories)
		
		# Resume at the first uncompleted story
		var resume_index = 0
		for i in range(stories.size()):
			var story_id = stories[i]["id"]
			if not completed_stories.has(story_id):
				resume_index = i
				break
			elif i == stories.size() - 1: # All stories completed
				resume_index = stories.size() - 1
		
		# Update current position
		current_story_index = resume_index
		print("ReadAloudStories: Resuming at story: ", stories[current_story_index]["id"], " (index: ", current_story_index, ")")
		
		# Update progress display
		_update_progress_display()
	else:
		print("ReadAloudStories: No story reading data found")

func _update_progress_display():
	"""Update progress bar and label"""
	var progress = (float(completed_stories.size()) / float(stories.size())) * 100.0
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	if progress_bar:
		progress_bar.value = progress
	
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	if progress_label:
		progress_label.text = str(completed_stories.size()) + "/" + str(stories.size()) + " Complete"

func _connect_button_events():
	"""Connect all button events with hover sounds"""
	var buttons = [
		$MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton,
		$MainContainer/ControlsContainer/PreviousButton,
		$MainContainer/ControlsContainer/ReadButton,
		$MainContainer/ControlsContainer/SpeakButton,
		$MainContainer/ControlsContainer/NextButton
	]
	
	for button in buttons:
		if button and not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)

func _display_current_story():
	"""Display the current story with dyslexia-friendly formatting"""
	if current_story_index < stories.size():
		var story = stories[current_story_index]
		
		# Update title
		var title_label = $MainContainer/StoryPanel/MarginContainer/StoryContainer/StoryTitleLabel
		if title_label:
			title_label.text = story.title
		
		# Split story into sentences for highlighting
		story_sentences = story.text.split("\\n\\n")
		current_sentence_index = 0
		
		# Display story text with dyslexia-friendly formatting
		var story_text = $MainContainer/StoryPanel/MarginContainer/StoryContainer/StoryText
		if story_text:
			# Apply dyslexia-friendly formatting
			story_text.clear()
			story_text.append_text(story.text)
			
			# Set proper line spacing and margin for dyslexic readers
			story_text.add_theme_constant_override("line_separation", 8)
		
		# Update navigation buttons
		_update_navigation_buttons()
		
		# Update play button text
		var play_button = $MainContainer/ControlsContainer/ReadButton
		if play_button:
			play_button.text = "Read"
			is_playing = false

func _update_navigation_buttons():
	"""Update visibility of navigation buttons"""
	var prev_btn = $MainContainer/ControlsContainer/PreviousButton
	var next_btn = $MainContainer/ControlsContainer/NextButton
	
	if prev_btn:
		prev_btn.visible = current_story_index > 0
	if next_btn:
		next_btn.visible = current_story_index < stories.size() - 1

func _start_sentence_practice():
	"""Start STT practice for current sentence"""
	if current_sentence_index < story_sentences.size():
		current_target_sentence = story_sentences[current_sentence_index].strip_edges()
		print("ReadAloudStories: Starting practice for sentence: ", current_target_sentence)
		
		# Highlight current sentence
		_highlight_current_sentence()
		
		# Set up STT feedback
		stt_feedback_active = true
		
		# Start speech recognition
		if not _start_speech_recognition():
			_show_microphone_error()

func _highlight_current_sentence():
	"""Highlight the current sentence for practice"""
	var story_text = $MainContainer/StoryPanel/MarginContainer/StoryContainer/StoryText
	if story_text and current_sentence_index < story_sentences.size():
		story_text.clear()
		
		# Add sentences before current one (normal color)
		for i in range(current_sentence_index):
			story_text.append_text(story_sentences[i])
			if i < current_sentence_index - 1:
				story_text.append_text("\n\n")
		
		# Add current sentence (highlighted)
		if current_sentence_index > 0:
			story_text.append_text("\n\n")
		story_text.push_color(Color.YELLOW)
		story_text.push_bgcolor(Color(1, 1, 0, 0.3))
		story_text.append_text(story_sentences[current_sentence_index])
		story_text.pop()
		story_text.pop()
		
		# Add sentences after current one (normal color)
		for i in range(current_sentence_index + 1, story_sentences.size()):
			story_text.append_text("\n\n")
			story_text.append_text(story_sentences[i])

func _show_microphone_error():
	"""Show error when microphone is not available"""
	var feedback_panel = get_node_or_null("STTFeedbackPanel")
	if feedback_panel:
		var feedback_label = feedback_panel.get_node("FeedbackLabel")
		if feedback_label:
			feedback_label.text = "Microphone not available.\nPlease check permissions and try again."
			feedback_label.modulate = Color.RED
		feedback_panel.visible = true

func _next_sentence_practice():
	"""Move to next sentence for practice"""
	if current_sentence_index < story_sentences.size() - 1:
		current_sentence_index += 1
		_start_sentence_practice()
	else:
		# All sentences practiced, mark story as read
		_on_story_done_button_pressed()

func _previous_sentence_practice():
	"""Move to previous sentence for practice"""
	if current_sentence_index > 0:
		current_sentence_index -= 1
		_start_sentence_practice()

func _read_sentence_aloud():
	"""Read current sentence using TTS"""
	if current_sentence_index < story_sentences.size() and tts:
		var sentence = story_sentences[current_sentence_index].strip_edges()
		tts.speak(sentence)

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	_stop_reading()
	_fade_out_and_change_scene("res://Scenes/ReadAloudModule.tscn")

func _on_previous_story_button_pressed():
	$ButtonClick.play()
	if current_story_index > 0:
		_stop_reading()
		current_story_index -= 1
		_display_current_story()

func _on_next_story_button_pressed():
	$ButtonClick.play()
	if current_story_index < stories.size() - 1:
		_stop_reading()
		current_story_index += 1
		_display_current_story()

func _on_story_done_button_pressed():
	"""Mark current story as completed and save progress"""
	$ButtonClick.play()
	_stop_reading()
	
	# Mark story as completed
	var story_id = stories[current_story_index]["id"]
	if not completed_stories.has(story_id):
		completed_stories.append(story_id)
		
		# Save progress to Firebase
		if module_progress and module_progress.is_authenticated():
			var success = await module_progress.complete_read_aloud_activity("story_reading", story_id)
			if success:
				print("ReadAloudStories: Story '", story_id, "' marked as completed")
				_update_progress_display()
			else:
				print("ReadAloudStories: Failed to save story completion")
	
	# Move to next story or show completion
	if current_story_index < stories.size() - 1:
		current_story_index += 1
		_display_current_story()
	else:
		_show_all_stories_completed()

func _show_all_stories_completed():
	"""Show completion message when all stories are read"""
	var story_title = $MainContainer/StoryPanel/MarginContainer/StoryContainer/StoryTitleLabel
	var story_text = $MainContainer/StoryPanel/MarginContainer/StoryContainer/StoryText
	
	if story_title:
		story_title.text = "Congratulations!"
	if story_text:
		story_text.clear()
		story_text.append_text("[center][b]You have completed all stories![/b]\n\nGreat job improving your reading skills![/center]")

func _start_reading():
	"""Start reading the current story with sentence highlighting"""
	if current_story_index < stories.size() and tts:
		# var story = stories[current_story_index]  # Not used in this function
		current_sentence_index = 0
		_read_next_sentence()

func _read_next_sentence():
	"""Read the next sentence with visual highlighting"""
	if current_sentence_index < story_sentences.size() and is_playing:
		var sentence = story_sentences[current_sentence_index].strip_edges()
		
		if sentence != "":
			# Highlight current sentence in the display
			_highlight_sentence(current_sentence_index)
			
			# Speak the sentence
			if tts:
				tts.speak(sentence)
				
				# Calculate reading time based on sentence length and reading speed
				var words = sentence.split(" ").size()
				var reading_time = (words / float(reading_speed)) * 60.0 # Convert to seconds
				
				# Wait for the sentence to be read, then move to next
				await get_tree().create_timer(reading_time + 0.5).timeout
				
				current_sentence_index += 1
				if is_playing:
					_read_next_sentence()
		else:
			current_sentence_index += 1
			if is_playing:
				_read_next_sentence()
	else:
		# Story finished
		_finish_story()

func _highlight_sentence(sentence_index: int):
	"""Highlight the current sentence being read with yellow background"""
	var story_text = $MainContainer/StoryPanel/MarginContainer/StoryContainer/StoryText
	if story_text and sentence_index < story_sentences.size():
		# Rebuild the text with the current sentence highlighted
		story_text.clear()
		for i in range(story_sentences.size()):
			var sentence = story_sentences[i].strip_edges()
			if sentence != "":
				if i == sentence_index:
					# Highlight current sentence with yellow background
					story_text.append_text("[bgcolor=yellow]" + sentence + "[/bgcolor]")
				else:
					story_text.append_text(sentence)
				
				# Add spacing between sentences
				if i < story_sentences.size() - 1:
					story_text.append_text("\\n\\n")

func _finish_story():
	"""Handle story completion"""
	_stop_reading()
	
	var story = stories[current_story_index]
	var story_id = story.id
	
	# Save completion if not already completed
	if not story_id in completed_stories:
		if module_progress and module_progress.is_authenticated():
			var success = await module_progress.complete_read_aloud_activity("story_reading", story_id)
			if success:
				completed_stories.append(story_id)
				print("ReadAloudStories: Story completed: ", story_id)
				_update_progress_display()
				_show_completion_message(story.title)
			else:
				print("ReadAloudStories: Failed to save story completion")
		else:
			# Fallback to local tracking
			completed_stories.append(story_id)
			_update_progress_display()
			_show_completion_message(story.title)
	else:
		print("ReadAloudStories: Story already completed: ", story_id)

func _show_completion_message(story_title: String):
	"""Show a completion message for the finished story"""
	# Simple notification - could be enhanced with a popup
	var title_label = $MainContainer/StoryPanel/MarginContainer/StoryContainer/StoryTitleLabel
	if title_label:
		var original_text = title_label.text
		title_label.text = "✓ " + story_title + " Complete!"
		title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2, 1))
		
		# Reset after 3 seconds
		await get_tree().create_timer(3.0).timeout
		title_label.text = original_text
		title_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))

func _stop_reading():
	"""Stop the current reading session"""
	is_playing = false
	current_sentence_index = 0
	
	if tts and tts.has_method("stop"):
		tts.stop()
	
	# Reset text highlighting
	var story_text = $MainContainer/StoryPanel/MarginContainer/StoryContainer/StoryText
	if story_text and current_story_index < stories.size():
		var _story = stories[current_story_index]
		story_text.clear()
		story_text.append_text(_story.text)
	
	var play_button = $MainContainer/ControlsContainer/ReadButton
	if play_button:
		play_button.text = "Read"

func _fade_out_and_change_scene(scene_path: String):
	_stop_reading()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _exit_tree():
	_stop_reading()

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
	print("ReadAloudStories: STT Error: ", error)
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
	print("ReadAloudStories: Processing STT result: ", text)
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
func _on_read_button_pressed():
	"""Read button - TTS reads one sentence at a time"""
	$ButtonClick.play()
	print("ReadAloudStories: Read button pressed")
	
	if current_story_index < stories.size() and current_sentence_index < story_sentences.size():
		var sentence = story_sentences[current_sentence_index].strip_edges()
		
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
				
				print("ReadAloudStories: Finished reading sentence ", current_sentence_index + 1, " of ", story_sentences.size())
		else:
			print("ReadAloudStories: Empty sentence, advancing...")
			current_sentence_index += 1
			_on_read_button_pressed() # Try next sentence

func _on_speak_button_pressed():
	"""Practice Speaking button - STT functionality for current sentence"""
	$ButtonClick.play()
	print("ReadAloudStories: Practice Speaking button pressed")
	
	if current_story_index < stories.size() and current_sentence_index < story_sentences.size():
		var sentence = story_sentences[current_sentence_index].strip_edges()
		current_target_sentence = sentence
		
		if sentence != "":
			print("ReadAloudStories: Target sentence for STT: ", sentence)
			
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
				print("ReadAloudStories: Failed to start speech recognition")
				# Reset button state on failure
				if speak_button:
					speak_button.text = "Speak"
					speak_button.disabled = false
		else:
			print("ReadAloudStories: No sentence to practice")

func _on_guide_button_pressed():
	"""Guide button - Provide TTS guidance for story reading"""
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Story Reading! This activity helps you practice reading with fun, engaging stories. Listen to the story by clicking 'Read' to hear how it sounds. Then, practice reading aloud yourself by clicking 'Speak' and repeat each sentence. Take your time and enjoy the stories!"
		tts.speak(guide_text)

func _on_tts_setting_button_pressed():
	"""TTS Settings button - Open TTS settings popup"""
	$ButtonClick.play()
	print("ReadAloudStories: TTS Settings button pressed")
	
	# Open TTS settings popup
	var tts_popup = load("res://Scenes/TTSSettingsPopup.tscn").instantiate()
	get_tree().current_scene.add_child(tts_popup)
