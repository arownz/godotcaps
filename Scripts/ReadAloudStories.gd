extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null

# Story data - Dyslexia-friendly stories with clear structure
var stories = [
	{
		"title": "The Helpful Cat",
		"text": "Luna is a small cat.\n\nShe lives in a cozy house.\n\nLuna likes to help.\n\nShe helps find lost toys.\n\nShe helps carry light bags.\n\nLuna is a good friend.\n\nEveryone loves Luna.",
		"id": "story_helpful_cat"
	},
	{
		"title": "The Magic Garden",
		"text": "Sam finds a magic garden.\n\nThe flowers are bright colors.\n\nRed roses. Blue bells. Yellow daisies.\n\nSam waters the plants.\n\nThe garden grows bigger.\n\nNow Sam has many friends who visit.\n\nThe magic garden makes everyone happy.",
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
	
	# Load progress and display first story
	await _load_progress()
	_display_current_story()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		call_deferred("_refresh_progress")

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

func _load_progress():
	"""Load read aloud progress from Firebase"""
	if not module_progress or not module_progress.is_authenticated():
		print("ReadAloudStories: Module progress not available")
		return
	
	var read_aloud_data = await module_progress.get_read_aloud_progress()
	if read_aloud_data and read_aloud_data.has("story_reading"):
		var story_data = read_aloud_data["story_reading"]
		completed_stories = story_data.get("activities_completed", [])
		print("ReadAloudStories: Loaded completed stories: ", completed_stories)
		
		# Update progress display
		_update_progress_display()
	else:
		print("ReadAloudStories: No story reading data found")

func _update_progress_display():
	"""Update progress bar and label"""
	var progress = (float(completed_stories.size()) / float(stories.size())) * 100.0
	var progress_bar = $MarginContainer/VBoxContainer/HeaderContainer/ProgressBar
	if progress_bar:
		progress_bar.value = progress
	
	var progress_label = $MarginContainer/VBoxContainer/HeaderContainer/Label
	if progress_label:
		progress_label.text = str(completed_stories.size()) + "/" + str(stories.size()) + " Complete"

func _connect_button_events():
	"""Connect all button events with hover sounds"""
	var buttons = [
		$MarginContainer/VBoxContainer/HeaderContainer/BackButton,
		$MarginContainer/VBoxContainer/ControlsContainer/PreviousButton,
		$MarginContainer/VBoxContainer/ControlsContainer/PlayButton,
		$MarginContainer/VBoxContainer/ControlsContainer/NextButton
	]
	
	for button in buttons:
		if button and not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)

func _display_current_story():
	"""Display the current story with dyslexia-friendly formatting"""
	if current_story_index < stories.size():
		var story = stories[current_story_index]
		
		# Update title
		var title_label = $MarginContainer/VBoxContainer/HeaderContainer/StoryTitle
		if title_label:
			title_label.text = story.title
		
		# Split story into sentences for highlighting
		story_sentences = story.text.split("\\n\\n")
		current_sentence_index = 0
		
		# Display story text with dyslexia-friendly formatting
		var story_text = $MarginContainer/VBoxContainer/StoryPanel/MarginContainer/StoryText
		if story_text:
			# Apply dyslexia-friendly formatting
			story_text.clear()
			story_text.append_text(story.text)
			
			# Set proper line spacing and margin for dyslexic readers
			story_text.add_theme_constant_override("line_separation", 8)
		
		# Update navigation buttons
		_update_navigation_buttons()
		
		# Update play button text
		var play_button = $MarginContainer/VBoxContainer/ControlsContainer/PlayButton
		if play_button:
			play_button.text = "Play Story"
			is_playing = false

func _update_navigation_buttons():
	"""Update visibility of navigation buttons"""
	var prev_btn = $MarginContainer/VBoxContainer/ControlsContainer/PreviousButton
	var next_btn = $MarginContainer/VBoxContainer/ControlsContainer/NextButton
	
	if prev_btn:
		prev_btn.visible = current_story_index > 0
	if next_btn:
		next_btn.visible = current_story_index < stories.size() - 1

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

func _on_play_button_pressed():
	$ButtonClick.play()
	var play_button = $MarginContainer/VBoxContainer/ControlsContainer/PlayButton
	
	if not is_playing:
		# Start reading
		_start_reading()
		if play_button:
			play_button.text = "Stop"
		is_playing = true
	else:
		# Stop reading
		_stop_reading()
		if play_button:
			play_button.text = "Play Story"
		is_playing = false

func _start_reading():
	"""Start reading the current story with sentence highlighting"""
	if current_story_index < stories.size() and tts:
		var story = stories[current_story_index]
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
	"""Highlight the current sentence being read"""
	var story_text = $MarginContainer/VBoxContainer/StoryPanel/MarginContainer/StoryText
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
	var title_label = $MarginContainer/VBoxContainer/HeaderContainer/StoryTitle
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
	var story_text = $MarginContainer/VBoxContainer/StoryPanel/MarginContainer/StoryText
	if story_text and current_story_index < stories.size():
		var _story = stories[current_story_index]
		story_text.clear()
		story_text.append_text(_story.text)
	
	var play_button = $MarginContainer/VBoxContainer/ControlsContainer/PlayButton
	if play_button:
		play_button.text = "Play Story"

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
