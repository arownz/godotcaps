extends Control

# TTS and Progress Management
var tts: TextToSpeech = null
var module_progress: Dictionary = {}
var current_story_index: int = 0
var is_highlighting: bool = false
var highlight_speed: float = 1.0

# Story Structure
var stories = [
	{
		"title": "The Happy Dog",
		"text": "Max is a happy dog.\nHe loves to play in the park.\nHe runs and jumps with joy.",
		"level": 1,
		"words_per_chunk": 3
	},
	{
		"title": "The Garden",
		"text": "In my garden, flowers grow.\nBees buzz around the roses.\nButterflies dance in the air.",
		"level": 1,
		"words_per_chunk": 4
	}
]

func _ready():
	print("ReadAloudStories: Initializing interface")
	
	# Initialize TTS
	tts = TextToSpeech.new()
	add_child(tts)
	
	# Load saved TTS settings
	var voice_id = SettingsManager.get_setting("accessibility", "tts_voice_id")
	var rate = SettingsManager.get_setting("accessibility", "tts_rate")
	
	if voice_id and voice_id != "":
		tts.set_voice(voice_id)
	if rate != null:
		tts.set_rate(rate)
	
	_init_module_progress()
	_setup_story_display()
	_load_progress()

	# Fade in animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)

func _init_module_progress():
	if not Firebase.Auth.auth:
		print("ReadAloudStories: Firebase not available")
		return
		
	# Initialize progress tracking
	_load_progress()

func _load_progress():
	if not Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("ReadAloudStories: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY:
			if "read_aloud" in modules:
				module_progress = modules["read_aloud"]
				_update_progress_display()

func _update_progress_display():
	var progress_bar = $ProgressBar
	if progress_bar:
		var completed_stories = module_progress.get("completed_stories", [])
		var progress = (float(completed_stories.size()) / stories.size()) * 100.0
		progress_bar.value = progress

func _setup_story_display():
	var story = stories[current_story_index]
	var title_label = $StoryTitle
	var text_label = $StoryText
	
	if title_label:
		title_label.text = story.title
	if text_label:
		text_label.text = story.text

func start_highlighting():
	if is_highlighting:
		return
		
	is_highlighting = true
	var story = stories[current_story_index]
	var words = story.text.split(" ")
	
	for i in range(0, words.size(), story.words_per_chunk):
		if not is_highlighting:
			break
			
		var chunk = words.slice(i, min(i + story.words_per_chunk, words.size()))
		var chunk_text = " ".join(chunk)
		
		# Highlight current chunk
		if tts:
			tts.speak(chunk_text)
			
		# Wait for chunk duration based on length and speed
		await get_tree().create_timer(chunk_text.length() * 0.1 * highlight_speed).timeout

func stop_highlighting():
	is_highlighting = false
	if tts:
		tts.stop()

func _on_play_button_pressed():
	$ButtonClick.play()
	if not is_highlighting:
		start_highlighting()
	else:
		stop_highlighting()

func _on_next_story_button_pressed():
	$ButtonClick.play()
	if current_story_index < stories.size() - 1:
		current_story_index += 1
		_setup_story_display()

func _on_previous_story_button_pressed():
	$ButtonClick.play()
	if current_story_index > 0:
		current_story_index -= 1
		_setup_story_display()

func _on_back_button_pressed():
	$ButtonClick.play()
	_fade_out_and_change_scene("res://Scenes/ReadAloudModule.tscn")

func _fade_out_and_change_scene(scene_path: String):
	stop_highlighting()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _exit_tree():
	stop_highlighting()
