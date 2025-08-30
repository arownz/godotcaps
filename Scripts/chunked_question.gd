extends Control

# TTS and Progress Management
var tts: TextToSpeech = null
var module_progress: Dictionary = {}
var current_chunk_index: int = 0
var is_highlighting: bool = false
var highlight_speed: float = 1.0

# Reading Material Structure
var reading_materials = [
	{
		"title": "The Lost Cat",
		"chunks": [
			{
				"text": "Lisa had a small black cat.\nHer name was Midnight.\nOne day, Midnight didn't come home for dinner.",
				"question": "What was the cat's name?",
				"answers": ["Midnight", "Lisa", "Morning", "Shadow"],
				"correct": 0
			},
			{
				"text": "Lisa looked in the garden.\nShe looked under the trees.\nNo Midnight anywhere.",
				"question": "Where did Lisa look first?",
				"answers": ["Garden", "House", "Street", "Park"],
				"correct": 0
			}
		],
		"level": 1
	}
]

var current_material_index: int = 0

func _ready():
	print("ReadAloudChunked: Initializing interface")
	_init_tts()
	_init_module_progress()
	_setup_chunk_display()
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
		print("ReadAloudChunked: Firebase not available")
		return
		
	# Initialize progress tracking
	_load_progress()

func _load_progress():
	if not Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("ReadAloudChunked: Loading progress for user: ", user_id)
	var document = await collection.get_doc(user_id)
	
	if document and !("error" in document.keys()):
		var modules = document.get_value("modules")
		if modules != null and typeof(modules) == TYPE_DICTIONARY:
			if "read_aloud_chunked" in modules:
				module_progress = modules["read_aloud_chunked"]
				_update_progress_display()

func _update_progress_display():
	var progress_bar = $ProgressBar
	if progress_bar:
		var total_chunks = 0
		var completed_chunks = 0
		
		for reading_material in reading_materials:
			total_chunks += reading_material.chunks.size()
			
		if "completed_chunks" in module_progress:
			completed_chunks = module_progress.completed_chunks.size()
			
		var progress = (float(completed_chunks) / total_chunks) * 100.0
		progress_bar.value = progress

func _setup_chunk_display():
	var current_material = reading_materials[current_material_index]
	var chunk = current_material.chunks[current_chunk_index]
	
	var title_label = $MaterialTitle
	var chunk_label = $ChunkText
	var question_label = $QuestionLabel
	var answers_container = $AnswersContainer
	
	if title_label:
		title_label.text = material.title
	if chunk_label:
		chunk_label.text = chunk.text
	if question_label:
		question_label.text = chunk.question
		
	# Setup answer buttons
	if answers_container:
		# Clear previous answers
		for child in answers_container.get_children():
			child.queue_free()
			
		# Add new answer buttons
		for i in range(chunk.answers.size()):
			var button = Button.new()
			button.text = chunk.answers[i]
			button.pressed.connect(_on_answer_selected.bind(i))
			answers_container.add_child(button)

func start_highlighting():
	if is_highlighting:
		return
		
	is_highlighting = true
	var current_material = reading_materials[current_material_index]
	var chunk = current_material.chunks[current_chunk_index]
	var lines = chunk.text.split("\n")
	
	for line in lines:
		if not is_highlighting:
			break
			
		if tts:
			tts.speak(line)
			
		# Highlight current line
		var chunk_label = $ChunkText
		if chunk_label:
			chunk_label.text = ""
			for i in range(lines.size()):
				if i == lines.find(line):
					chunk_label.text += "[color=yellow]" + line + "[/color]\n"
				else:
					chunk_label.text += lines[i] + "\n"
		
		# Wait for line duration based on length and speed
		await get_tree().create_timer(line.length() * 0.1 * highlight_speed).timeout

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

func _on_answer_selected(answer_index: int):
	$ButtonClick.play()
	var current_material = reading_materials[current_material_index]
	var chunk = current_material.chunks[current_chunk_index]
	
	if answer_index == chunk.correct:
		print("Correct answer!")
		# Save progress
		if not "completed_chunks" in module_progress:
			module_progress.completed_chunks = []
			
		var chunk_id = str(current_material_index) + "_" + str(current_chunk_index)
		if not chunk_id in module_progress.completed_chunks:
			module_progress.completed_chunks.append(chunk_id)
			_save_progress()
		
		# Move to next chunk or material
		_advance_chunk()
	else:
		print("Incorrect answer. Try again!")

func _advance_chunk():
	var current_material = reading_materials[current_material_index]
	
	if current_chunk_index < current_material.chunks.size() - 1:
		current_chunk_index += 1
		_setup_chunk_display()
	elif current_material_index < reading_materials.size() - 1:
		current_material_index += 1
		current_chunk_index = 0
		_setup_chunk_display()
	else:
		print("All chunks completed!")

func _save_progress():
	if not Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("ReadAloudChunked: Saving progress for user: ", user_id)
	var doc = await collection.get_doc(user_id)
	
	if doc and !("error" in doc.keys()):
		var modules = doc.get_value("modules")
		if modules == null:
			modules = {}
			
		modules.read_aloud_chunked = module_progress
		doc.add_or_update_field("modules", modules)
		await collection.update(doc)
		_update_progress_display()

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
