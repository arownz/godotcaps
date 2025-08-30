extends Control

# TTS and Progress Management
var tts: TextToSpeech = null
var module_progress: Dictionary = {}
var current_passage_index: int = 0
var is_highlighting: bool = false
var highlight_speed: float = 1.0

# Guided Reading Passages
var passages = [
	{
		"title": "The Rainbow",
		"text": "After the rain,\na beautiful rainbow appeared.\nIt had seven colors.",
		"guide_notes": [
			"Let's read slowly and clearly.",
			"Notice how we pause at each line.",
			"Can you name the colors you see?"
		],
		"expression_points": [
			{"text": "beautiful", "note": "Say this with wonder in your voice"},
			{"text": "seven", "note": "Emphasize this number"}
		],
		"level": 1
	},
	{
		"title": "The Brave Mouse",
		"text": "A tiny mouse lived in a house.\nOne day, she heard a loud noise.\nShe was scared but went to look.",
		"guide_notes": [
			"Read with a quiet voice for the tiny mouse.",
			"Make the loud noise sound scary!",
			"Show how the mouse feels brave at the end."
		],
		"expression_points": [
			{"text": "tiny", "note": "Use a small, quiet voice"},
			{"text": "loud noise", "note": "Say this with emphasis"},
			{"text": "scared", "note": "Show the feeling in your voice"}
		],
		"level": 1
	}
]

func _ready():
	print("ReadAloudGuided: Initializing interface")
	_init_tts()
	_init_module_progress()
	_setup_passage_display()
	_load_progress()

	# Fade in animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	
	# Load TTS settings
	var voice_id = SettingsManager.get_setting("accessibility", "tts_voice_id")
	var rate = SettingsManager.get_setting("accessibility", "tts_rate")
	
	if voice_id != null and voice_id != "":
		tts.set_voice(voice_id)
	if rate != null:
		tts.set_rate(rate)

func _init_module_progress():
	if not Firebase.Auth.auth:
		print("ReadAloudGuided: Firebase not available")
		return
		
	# Initialize progress tracking
	_load_progress()

func _load_progress():
	if not Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("ReadAloudGuided: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY:
			if "read_aloud_guided" in modules:
				module_progress = modules["read_aloud_guided"]
				_update_progress_display()

func _update_progress_display():
	var progress_bar = $ProgressBar
	if progress_bar:
		var completed_passages = module_progress.get("completed_passages", [])
		var progress = (float(completed_passages.size()) / passages.size()) * 100.0
		progress_bar.value = progress

func _setup_passage_display():
	var passage = passages[current_passage_index]
	var title_label = $PassageTitle
	var text_label = $PassageText
	var guide_label = $GuideNotes
	
	if title_label:
		title_label.text = passage.title
	if text_label:
		text_label.text = passage.text
	if guide_label:
		guide_label.text = passage.guide_notes[0] # Show first guide note

func highlight_expression_point(point_index: int):
	var passage = passages[current_passage_index]
	var text_label = $PassageText
	var guide_label = $GuideNotes
	
	if point_index < passage.expression_points.size():
		var point = passage.expression_points[point_index]
		var text = passage.text
		var highlighted_text = text.replace(
			point.text,
			"[color=yellow]" + point.text + "[/color]"
		)
		text_label.text = highlighted_text
		guide_label.text = point.note
		
		# TTS reads the highlighted word with expression
		if tts:
			tts.speak(point.text)

func start_guided_reading():
	if is_highlighting:
		return
		
	is_highlighting = true
	var passage = passages[current_passage_index]
	var lines = passage.text.split("\n")
	var guide_notes = passage.guide_notes
	
	for i in range(lines.size()):
		if not is_highlighting:
			break
			
		var line = lines[i]
		if tts:
			tts.speak(line)
			
		# Highlight current line and show guide note
		var text_label = $PassageText
		var guide_label = $GuideNotes
		
		if text_label:
			text_label.text = ""
			for j in range(lines.size()):
				if j == i:
					text_label.text += "[color=yellow]" + line + "[/color]\n"
				else:
					text_label.text += lines[j] + "\n"
					
		if guide_label and i < guide_notes.size():
			guide_label.text = guide_notes[i]
		
		# Wait for line duration based on length and speed
		await get_tree().create_timer(line.length() * 0.15 * highlight_speed).timeout

func stop_guided_reading():
	is_highlighting = false
	if tts:
		tts.stop()

func _on_play_button_pressed():
	$ButtonClick.play()
	if not is_highlighting:
		start_guided_reading()
	else:
		stop_guided_reading()

func _on_next_passage_button_pressed():
	$ButtonClick.play()
	if current_passage_index < passages.size() - 1:
		current_passage_index += 1
		_setup_passage_display()

func _on_previous_passage_button_pressed():
	$ButtonClick.play()
	if current_passage_index > 0:
		current_passage_index -= 1
		_setup_passage_display()

func _on_practice_complete_button_pressed():
	$ButtonClick.play()
	# Save progress
	if not "completed_passages" in module_progress:
		module_progress.completed_passages = []
		
	if not current_passage_index in module_progress.completed_passages:
		module_progress.completed_passages.append(current_passage_index)
		_save_progress()

func _save_progress():
	if not Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("ReadAloudGuided: Saving progress for user: ", user_id)
	var doc = await collection.get_doc(user_id)
	
	if doc and !("error" in doc.keys()):
		var modules = doc.get_value("modules")
		if modules == null:
			modules = {}
			
		modules.read_aloud_guided = module_progress
		doc.add_or_update_field("modules", modules)
		await collection.update(doc)
		_update_progress_display()

func _on_back_button_pressed():
	$ButtonClick.play()
	_fade_out_and_change_scene("res://Scenes/ReadAloudModule.tscn")

func _fade_out_and_change_scene(scene_path: String):
	stop_guided_reading()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _exit_tree():
	stop_guided_reading()
