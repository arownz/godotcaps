extends Control

# Core systems
var tts: TextToSpeech = null
var module_progress = null
var current_chunk_index: int = 0
var current_material_index: int = 0
var is_reading: bool = false
var reading_speed: float = 120.0 # words per minute

# Reading Material Structure - dyslexia-friendly chunked reading with comprehension
var reading_materials = [
	{
		"title": "Emma's New Friend",
		"chunks": [
			{
				"text": "Emma started at a new school today. She felt nervous and didn't know anyone. At lunch time, she sat alone at a table.",
				"question": "How did Emma feel at her new school?",
				"answers": ["Happy", "Nervous", "Excited", "Angry"],
				"correct": 1,
				"explanation": "The text says Emma 'felt nervous' because she didn't know anyone."
			},
			{
				"text": "A girl with curly red hair walked over to Emma's table. 'Hi, I'm Sarah,' she said with a big smile. 'Would you like to sit with my friends and me?'",
				"question": "What did Sarah look like?",
				"answers": ["Blonde hair", "Curly red hair", "Black hair", "Short brown hair"],
				"correct": 1,
				"explanation": "Sarah had 'curly red hair' according to the text."
			},
			{
				"text": "Emma smiled back and followed Sarah to another table. There were three other students sitting there. They all introduced themselves and asked Emma about her old school.",
				"question": "How many students were at Sarah's table including Sarah?",
				"answers": ["Two", "Three", "Four", "Five"],
				"correct": 2,
				"explanation": "Sarah plus three other students equals four students total."
			}
		],
		"level": 1
	},
	{
		"title": "The Magic Garden",
		"chunks": [
			{
				"text": "Grandpa Joe had a special garden behind his house. Every morning, he would water the plants and talk to them. He believed that talking helped them grow better.",
				"question": "What did Grandpa Joe do every morning?",
				"answers": ["Read books", "Water plants and talk to them", "Cook breakfast", "Watch TV"],
				"correct": 1,
				"explanation": "The text says he would 'water the plants and talk to them' every morning."
			},
			{
				"text": "One day, his granddaughter Maya came to visit. She laughed when she saw Grandpa talking to a tomato plant. 'Plants can't understand you, Grandpa!' she said.",
				"question": "How did Maya react to seeing Grandpa talk to plants?",
				"answers": ["She cried", "She was scared", "She laughed", "She was angry"],
				"correct": 2,
				"explanation": "Maya 'laughed when she saw Grandpa talking to a tomato plant.'"
			},
			{
				"text": "Grandpa winked at Maya. 'Maybe not,' he said, 'but look how big and healthy they are!' The garden was full of the biggest, most colorful vegetables Maya had ever seen.",
				"question": "What was special about Grandpa's vegetables?",
				"answers": ["They were very small", "They were the biggest and most colorful", "They were all the same color", "They didn't taste good"],
				"correct": 1,
				"explanation": "The vegetables were 'the biggest, most colorful vegetables Maya had ever seen.'"
			}
		],
		"level": 2
	}
]

func _ready():
	print("ChunkedQuestion: Initializing chunked reading interface")
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
		tts.set_rate(0.7) # Slower pace for comprehension

func _init_module_progress():
	if Engine.has_singleton("Firebase") and Firebase.Auth.auth:
		var ModuleProgressScript = load("res://Scripts/ModulesManager/ModuleProgress.gd")
		module_progress = ModuleProgressScript.new()
		print("ChunkedQuestion: ModuleProgress initialized")
	else:
		print("ChunkedQuestion: Firebase not available, using local tracking")

func _load_progress():
	if module_progress and module_progress.is_authenticated():
		print("ChunkedQuestion: Loading chunked reading progress")
		var progress_data = await module_progress.get_chunked_reading_progress()
		if progress_data:
			_update_progress_display(progress_data.get("chunked_question", {}).get("progress", 0))
		else:
			_update_progress_display(0)
	else:
		_update_progress_display(0)

func _update_progress_display(progress_percentage: float):
	var progress_bar = $MarginContainer/VBoxContainer/HeaderContainer/ProgressBar
	if progress_bar:
		progress_bar.value = progress_percentage
		print("ChunkedQuestion: Progress updated to ", progress_percentage, "%")

func _setup_initial_display():
	_display_current_chunk()
	_update_navigation_buttons()

func _display_current_chunk():
	var reading_material = reading_materials[current_material_index]
	var chunk = reading_material.chunks[current_chunk_index]
	
	# Update title
	var title_label = $MarginContainer/VBoxContainer/HeaderContainer/MaterialTitle
	if title_label:
		title_label.text = reading_material.title + " - Part " + str(current_chunk_index + 1)
	
	# Display chunk text
	var text_display = $MarginContainer/VBoxContainer/ChunkPanel/MarginContainer/ChunkText
	if text_display:
		text_display.clear()
		text_display.append_text(chunk.text)
	
	# Display question
	var question_display = $MarginContainer/VBoxContainer/QuestionPanel/MarginContainer/VBoxContainer/QuestionLabel
	if question_display:
		question_display.text = chunk.question
	
	# Setup answer buttons
	_setup_answer_buttons(chunk)
	
	# Reset explanation panel
	_hide_explanation()

func _setup_answer_buttons(chunk):
	var answers_container = $MarginContainer/VBoxContainer/QuestionPanel/MarginContainer/VBoxContainer/AnswersContainer
	if not answers_container:
		print("ChunkedQuestion: Answers container not found")
		return
	
	# Clear previous answer buttons
	for child in answers_container.get_children():
		child.queue_free()
	
	# Add new answer buttons with dyslexia-friendly styling
	for i in range(chunk.answers.size()):
		var button = Button.new()
		button.text = str(i + 1) + ". " + chunk.answers[i]
		button.custom_minimum_size = Vector2(300, 50)
		button.add_theme_font_size_override("font_size", 18)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Connect button signal
		button.pressed.connect(_on_answer_selected.bind(i))
		answers_container.add_child(button)

func _update_navigation_buttons():
	# Navigation buttons not present in current scene structure
	pass
	# var prev_button = $MarginContainer/VBoxContainer/ControlsContainer/PreviousButton
	# var next_button = $MarginContainer/VBoxContainer/ControlsContainer/NextButton
	
	# if prev_button:
	#	prev_button.disabled = (current_material_index == 0 and current_chunk_index == 0)
	# if next_button:
	#	var reading_material = reading_materials[current_material_index]
	#	var is_last_chunk = (current_chunk_index >= reading_material.chunks.size() - 1)
	#	var is_last_material = (current_material_index >= reading_materials.size() - 1)
	#	next_button.disabled = (is_last_chunk and is_last_material)

func _start_reading():
	if is_reading:
		_stop_reading()
		return
		
	is_reading = true
	_update_play_button_text()
	
	var reading_material = reading_materials[current_material_index]
	var chunk = reading_material.chunks[current_chunk_index]
	
	print("ChunkedQuestion: Starting reading of chunk")
	
	# Read the text with highlighting
	if tts:
		tts.speak(chunk.text)
	
	# Highlight the text while reading
	await _highlight_text_while_reading(chunk.text)
	
	_stop_reading()

func _highlight_text_while_reading(text: String):
	var text_display = $MarginContainer/VBoxContainer/ChunkPanel/MarginContainer/ChunkText
	if not text_display:
		return
	
	var sentences = text.split(". ")
	
	for i in range(sentences.size()):
		if not is_reading:
			break
		
		var sentence = sentences[i]
		if i < sentences.size() - 1:
			sentence += "."
		
		# Highlight current sentence
		text_display.clear()
		for j in range(sentences.size()):
			var display_sentence = sentences[j]
			if j < sentences.size() - 1:
				display_sentence += "."
			
			if j == i:
				text_display.append_text("[bgcolor=yellow]" + display_sentence + "[/bgcolor]")
			else:
				text_display.append_text(display_sentence)
			
			if j < sentences.size() - 1:
				text_display.append_text(" ")
		
		# Wait based on sentence length and reading speed
		var wait_time = _calculate_reading_time(sentence)
		await get_tree().create_timer(wait_time).timeout

func _calculate_reading_time(text: String) -> float:
	var word_count = text.split(" ").size()
	var time_in_minutes = word_count / reading_speed
	return time_in_minutes * 60.0

func _stop_reading():
	is_reading = false
	_update_play_button_text()
	
	if tts:
		tts.stop()
	
	# Reset text display
	_display_current_chunk()

func _update_play_button_text():
	var play_button = $MarginContainer/VBoxContainer/ControlsContainer/PlayButton
	if play_button:
		if is_reading:
			play_button.text = "Pause"
		else:
			play_button.text = "Read Aloud"

func _on_answer_selected(answer_index: int):
	$ButtonClick.play()
	var reading_material = reading_materials[current_material_index]
	var chunk = reading_material.chunks[current_chunk_index]
	
	# Show explanation
	_show_explanation(chunk, answer_index)
	
	if answer_index == chunk.correct:
		print("ChunkedQuestion: Correct answer!")
		# Complete this chunk activity
		await _complete_chunk_activity()
	else:
		print("ChunkedQuestion: Incorrect answer, showing explanation")

func _show_explanation(_chunk, _selected_answer: int):
	# ExplanationPanel not present in current scene structure
	pass
	# var explanation_panel = $MarginContainer/VBoxContainer/ExplanationPanel
	# var explanation_text = $MarginContainer/VBoxContainer/ExplanationPanel/MarginContainer/ExplanationText
	
	# if explanation_panel and explanation_text:
	#	explanation_panel.visible = true
		
	#	if selected_answer == chunk.correct:
	#		explanation_text.text = "[color=green][b]Correct![/b][/color]\n\n" + chunk.explanation
	#	else:
	#		explanation_text.text = "[color=red][b]Not quite right.[/b][/color]\n\n" + chunk.explanation
	#		explanation_text.text += "\n\nThe correct answer was: " + chunk.answers[chunk.correct]

func _hide_explanation():
	# ExplanationPanel not present in current scene structure  
	pass
	# var explanation_panel = $MarginContainer/VBoxContainer/ExplanationPanel
	# if explanation_panel:
	#	explanation_panel.visible = false

func _complete_chunk_activity():
	if module_progress and module_progress.is_authenticated():
		var chunk_id = "material_" + str(current_material_index) + "_chunk_" + str(current_chunk_index)
		print("ChunkedQuestion: Completing chunk: ", chunk_id)
		
		var success = await module_progress.complete_chunked_reading_activity("chunked_question", chunk_id)
		
		if success:
			# Update progress display
			var progress_data = await module_progress.get_chunked_reading_progress()
			if progress_data:
				_update_progress_display(progress_data.get("chunked_question", {}).get("progress", 0))
			print("ChunkedQuestion: Chunk completed and saved!")
		else:
			print("ChunkedQuestion: Failed to save chunk completion")

func _advance_to_next():
	var reading_material = reading_materials[current_material_index]
	
	if current_chunk_index < reading_material.chunks.size() - 1:
		current_chunk_index += 1
	elif current_material_index < reading_materials.size() - 1:
		current_material_index += 1
		current_chunk_index = 0
	else:
		print("ChunkedQuestion: All chunks completed!")
		return
	
	_display_current_chunk()
	_update_navigation_buttons()

func _go_to_previous():
	if current_chunk_index > 0:
		current_chunk_index -= 1
	elif current_material_index > 0:
		current_material_index -= 1
		var prev_material = reading_materials[current_material_index]
		current_chunk_index = prev_material.chunks.size() - 1
	
	_display_current_chunk()
	_update_navigation_buttons()

# Button event handlers
func _on_back_button_pressed():
	$ButtonClick.play()
	_fade_out_and_change_scene("res://Scenes/ChunkedReadingModule.tscn")

func _on_play_button_pressed():
	$ButtonClick.play()
	_start_reading()

func _on_previous_button_pressed():
	$ButtonClick.play()
	_stop_reading()
	_go_to_previous()

func _on_next_button_pressed():
	$ButtonClick.play()
	_stop_reading()
	_advance_to_next()

func _fade_out_and_change_scene(scene_path: String):
	_stop_reading()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _exit_tree():
	_stop_reading()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window gains focus
		_load_progress()
