extends Control

# Core systems
var tts: TextToSpeech = null
var module_progress = null
var current_passage_index: int = 0
var is_reading: bool = false
var current_sentence_index: int = 0
var reading_speed: float = 150.0 # words per minute

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
			{"word": "orange", "definition": "a bright color like a sunset"},
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
			"This story shows how plants grow. Follow along as we read each step.",
			"Notice how Ben takes care of his garden every day.",
			"Watch for the time words: every day, after many weeks.",
			"See how the plants change from seeds to food.",
			"Think about what Ben can do with his tomatoes."
		],
		"vocabulary": [
			{"word": "planted", "definition": "put seeds in the ground to grow"},
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
			"Let's read about Lisa's morning routine. Notice the pattern of what happens each day.",
			"See how Mr. Joe is friendly to the children.",
			"Friends like to sit together and talk.",
			"Books are something Lisa and Emma both enjoy.",
			"Think about how the girls feel about going to school."
		],
		"vocabulary": [
			{"word": "waits", "definition": "stays in one place until something happens"},
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
			"This story shows how to make the best of a rainy day.",
			"Notice how the weather changes the children's plans.",
			"See how Maria and Carlos work together as a team.",
			"Watch for the describing words: dark, softly, cozy.",
			"Think about creative ways to have fun indoors."
		],
		"vocabulary": [
			{"word": "instead", "definition": "in place of something else"},
			{"word": "cozy", "definition": "warm and comfortable"}
		],
		"level": 2
	}
]

func _ready():
	print("ReadAloudGuided: Initializing guided reading interface")
	_init_tts()
	_init_module_progress()
	_setup_initial_display()
	_load_progress()

	# Fade in animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)

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
	if Engine.has_singleton("Firebase") and Firebase.Auth.auth:
		var ModuleProgressScript = load("res://Scripts/ModulesManager/ModuleProgress.gd")
		module_progress = ModuleProgressScript.new()
		print("ReadAloudGuided: ModuleProgress initialized")
	else:
		print("ReadAloudGuided: Firebase not available, using local tracking")

func _load_progress():
	if module_progress and module_progress.is_authenticated():
		print("ReadAloudGuided: Loading guided reading progress")
		var progress_data = await module_progress.get_read_aloud_progress()
		if progress_data:
			_update_progress_display(progress_data.get("guided_reading", {}).get("progress", 0))
		else:
			_update_progress_display(0)
	else:
		_update_progress_display(0)

func _update_progress_display(progress_percentage: float):
	var progress_bar = $MarginContainer/VBoxContainer/HeaderContainer/ProgressBar
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
	var title_label = $MarginContainer/VBoxContainer/HeaderContainer/PassageTitle
	if title_label:
		title_label.text = passage.title
	
	# Display full text initially
	var text_display = $MarginContainer/VBoxContainer/PassagePanel/MarginContainer/PassageText
	if text_display:
		text_display.clear()
		text_display.append_text(passage.text)
	
	# Show initial guide note
	var guide_display = $MarginContainer/VBoxContainer/GuidePanel/MarginContainer/GuideNotes
	if guide_display and passage.guide_notes.size() > 0:
		guide_display.text = passage.guide_notes[0]
	
	# Reset sentence tracking
	current_sentence_index = 0
	_update_play_button_text()

func _update_navigation_buttons():
	var prev_button = $MarginContainer/VBoxContainer/ControlsContainer/PreviousButton
	var next_button = $MarginContainer/VBoxContainer/ControlsContainer/NextButton
	
	if prev_button:
		prev_button.disabled = (current_passage_index <= 0)
	if next_button:
		next_button.disabled = (current_passage_index >= passages.size() - 1)

func _update_play_button_text():
	var play_button = $MarginContainer/VBoxContainer/ControlsContainer/PlayButton
	if play_button:
		if is_reading:
			play_button.text = "Pause"
		else:
			play_button.text = "Start Reading"

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
			var guide_display = $MarginContainer/VBoxContainer/GuidePanel/MarginContainer/GuideNotes
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
	var text_display = $MarginContainer/VBoxContainer/PassagePanel/MarginContainer/PassageText
	
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
			# Update progress display
			var progress_data = await module_progress.get_read_aloud_progress()
			if progress_data:
				_update_progress_display(progress_data.get("guided_reading", {}).get("progress", 0))
			print("ReadAloudGuided: Passage completed and saved!")
		else:
			print("ReadAloudGuided: Failed to save passage completion")

# Button event handlers
func _on_back_button_pressed():
	$ButtonClick.play()
	_fade_out_and_change_scene("res://Scenes/ReadAloudModule.tscn")

func _on_play_button_pressed():
	$ButtonClick.play()
	_start_guided_reading()

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
	$ButtonClick.play()
	await _complete_passage()
	
	# Show completion message
	var guide_display = $MarginContainer/VBoxContainer/GuidePanel/MarginContainer/GuideNotes
	if guide_display:
		guide_display.text = "Great job! You completed this guided reading passage. Try the next one!"

func _fade_out_and_change_scene(scene_path: String):
	_stop_guided_reading()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _exit_tree():
	_stop_guided_reading()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window gains focus
		_load_progress()
