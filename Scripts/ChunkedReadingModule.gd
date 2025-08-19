extends Control

var module_progress: ModuleProgress
var completion_celebration: CanvasLayer = null
var completion_celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")

# Dyslexia-friendly chunked reading lessons with visual supports
var reading_lessons = [
	{
		"id": "animals_lesson",
		"title": "Animals in the Wild",
		"chunks": [
			{
				"text": "Lions are big cats.",
				"image": "🦁",
				"key_words": ["lions", "big", "cats"]
			},
			{
				"text": "They live in groups.",
				"image": "👥",
				"key_words": ["live", "groups"]
			},
			{
				"text": "Lions hunt for food.",
				"image": "🍖",
				"key_words": ["hunt", "food"]
			}
		],
		"questions": [
			{"type": "multiple_choice", "q": "What are lions?", "options": ["big cats", "small dogs", "birds"], "correct": 0},
			{"type": "fill_blank", "q": "Lions live in ____.", "answer": "groups"}
		]
	},
	{
		"id": "weather_lesson",
		"title": "Weather Changes",
		"chunks": [
			{
				"text": "The sun makes it warm.",
				"image": "☀️",
				"key_words": ["sun", "warm"]
			},
			{
				"text": "Rain makes puddles.",
				"image": "🌧️",
				"key_words": ["rain", "puddles"]
			},
			{
				"text": "Snow is cold and white.",
				"image": "❄️",
				"key_words": ["snow", "cold", "white"]
			}
		],
		"questions": [
			{"type": "multiple_choice", "q": "What makes it warm?", "options": ["rain", "sun", "snow"], "correct": 1},
			{"type": "sequence", "q": "Put in order:", "items": ["sun", "rain", "snow"], "correct": [0, 1, 2]}
		]
	}
]

var current_lesson = null
var current_chunk_index = 0

func _ready():
	print("ChunkedReadingModule: Chunked Reading module loaded")
	module_progress = ModuleProgress.new()
	_connect_signals()

func _connect_signals():
	"""Connect all UI signals"""
	# Header controls
	var back_button = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		back_button.mouse_entered.connect(_on_button_hover)
	
	# Lesson selection buttons
	var start_button1 = $MainContainer/ScrollContainer/ContentContainer/LessonSelectionCard/LessonContainer/LessonGrid/Lesson1Card/Lesson1Container/StartButton1
	if start_button1:
		start_button1.pressed.connect(_on_start_lesson_pressed.bind(1))
		start_button1.mouse_entered.connect(_on_button_hover)
	
	var start_button2 = $MainContainer/ScrollContainer/ContentContainer/LessonSelectionCard/LessonContainer/LessonGrid/Lesson2Card/Lesson2Container/StartButton2
	if start_button2:
		start_button2.pressed.connect(_on_start_lesson_pressed.bind(2))
		start_button2.mouse_entered.connect(_on_button_hover)
	
	# Answer buttons
	var answer1 = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/QuestionArea/QuestionContainer/AnswerContainer/Answer1
	if answer1:
		answer1.pressed.connect(_on_answer_selected.bind(0))
		answer1.mouse_entered.connect(_on_button_hover)
	
	var answer2 = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/QuestionArea/QuestionContainer/AnswerContainer/Answer2
	if answer2:
		answer2.pressed.connect(_on_answer_selected.bind(1))
		answer2.mouse_entered.connect(_on_button_hover)
	
	var answer3 = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/QuestionArea/QuestionContainer/AnswerContainer/Answer3
	if answer3:
		answer3.pressed.connect(_on_answer_selected.bind(2))
		answer3.mouse_entered.connect(_on_button_hover)
	
	# Navigation buttons
	var previous_button = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingButtonsContainer/PreviousButton
	if previous_button:
		previous_button.pressed.connect(_on_previous_chunk_pressed)
		previous_button.mouse_entered.connect(_on_button_hover)
	
	var next_button = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingButtonsContainer/NextButton
	if next_button:
		next_button.pressed.connect(_on_next_chunk_pressed)
		next_button.mouse_entered.connect(_on_button_hover)
	
	var back_to_lessons = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingButtonsContainer/BackToLessonsButton
	if back_to_lessons:
		back_to_lessons.pressed.connect(_on_back_to_lessons_pressed)
		back_to_lessons.mouse_entered.connect(_on_button_hover)

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	print("ChunkedReadingModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_start_lesson_pressed(lesson_number: int = 1):
	print("ChunkedReadingModule: Starting lesson ", lesson_number)
	
	if lesson_number <= reading_lessons.size():
		current_lesson = reading_lessons[lesson_number - 1]
		current_chunk_index = 0
		_show_reading_interface()
	else:
		_show_lesson_placeholder(lesson_number)

func _show_reading_interface():
	"""Switch to reading interface"""
	var lesson_card = $MainContainer/ScrollContainer/ContentContainer/LessonSelectionCard
	var reading_card = $MainContainer/ScrollContainer/ContentContainer/ReadingCard
	
	if lesson_card and reading_card:
		lesson_card.visible = false
		reading_card.visible = true
		_update_chunk_display()

func _show_lesson_selection():
	"""Switch to lesson selection"""
	var lesson_card = $MainContainer/ScrollContainer/ContentContainer/LessonSelectionCard
	var reading_card = $MainContainer/ScrollContainer/ContentContainer/ReadingCard
	
	if lesson_card and reading_card:
		reading_card.visible = false
		lesson_card.visible = true

func _update_chunk_display():
	"""Update the reading interface with current chunk"""
	if not current_lesson or current_chunk_index >= current_lesson.chunks.size():
		return
	
	# Update title
	var title_label = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingTitleLabel
	if title_label:
		title_label.text = "Reading: " + current_lesson.title
	
	# Update progress
	var progress_label = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ProgressLabel
	if progress_label:
		progress_label.text = "Chunk " + str(current_chunk_index + 1) + " of " + str(current_lesson.chunks.size())
	
	# Update chunk text (for demo, show simple text)
	var chunk_text = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ChunkDisplayArea/ChunkText
	if chunk_text:
		chunk_text.text = "Dogs and cats are popular pets. Many families love having them at home. Dogs like to play fetch and go for walks."

func _on_answer_selected(answer_index: int):
	"""Handle answer selection"""
	print("ChunkedReadingModule: Answer selected: ", answer_index)
	# For demo, any answer advances to next chunk
	_on_next_chunk_pressed()

func _on_previous_chunk_pressed():
	"""Go to previous chunk"""
	if current_chunk_index > 0:
		current_chunk_index -= 1
		_update_chunk_display()

func _on_next_chunk_pressed():
	"""Go to next chunk or complete lesson"""
	if current_chunk_index < current_lesson.chunks.size() - 1:
		current_chunk_index += 1
		_update_chunk_display()
	else:
		# Lesson completed
		_simulate_lesson_completion()

func _on_back_to_lessons_pressed():
	"""Return to lesson selection"""
	print("ChunkedReadingModule: Returning to lesson selection")
	_show_lesson_selection()

func _start_chunked_reading():
	"""Start chunked reading with dyslexia-friendly features"""
	var dialog = AcceptDialog.new()
	var lesson_preview = "Chunked Reading: " + current_lesson.title + "\n\n"
	lesson_preview += "📚 Read small chunks at your own pace\n"
	lesson_preview += "🖼️ Visual aids for each chunk\n"
	lesson_preview += "💡 Key words highlighted\n"
	lesson_preview += "❓ Gentle comprehension checks\n\n"
	
	lesson_preview += "Preview chunks:\n"
	for i in range(min(3, current_lesson.chunks.size())):
		var chunk = current_lesson.chunks[i]
		lesson_preview += str(i + 1) + ". " + chunk.text + " " + chunk.image + "\n"
	
	dialog.dialog_text = lesson_preview
	dialog.title = "Chunked Reading - " + current_lesson.title
	dialog.custom_minimum_size = Vector2(500, 400)
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	
	# Simulate lesson completion with comprehension
	await _simulate_lesson_completion()
	dialog.queue_free()

func _simulate_lesson_completion():
	"""Simulate completing a chunked reading lesson"""
	print("ChunkedReadingModule: Simulating lesson completion")
	
	# Simulate comprehension accuracy (75-95% for chunked reading)
	var comprehension_accuracy = randf_range(0.75, 0.95)
	
	# Update progress in Firebase
	var success = await module_progress.set_chunked_reading_lesson_completed(current_lesson.id, comprehension_accuracy)
	
	if success:
		print("ChunkedReadingModule: Lesson completed successfully!")

func _show_completion_celebration():
	"""Show completion celebration for finished lesson"""
	var celebration = completion_celebration_scene.instantiate()
	add_child(celebration)
	
	# Calculate progress for celebration display
	var completed_lessons = 1 # At least this lesson is completed
	var total_lessons = reading_lessons.size()
	var progress_data = {
		"current": completed_lessons,
		"total": total_lessons,
		"percentage": (float(completed_lessons) / float(total_lessons)) * 100.0
	}
	
	celebration.show_completion("chunked_reading", current_lesson.title, progress_data, "chunked_reading")
	
	# Connect celebration signals
	celebration.try_again_pressed.connect(_on_celebration_try_again)
	celebration.next_item_pressed.connect(_on_celebration_next_lesson)

func _on_celebration_try_again():
	"""Try the same lesson again"""
	_start_chunked_reading()

func _on_celebration_next_lesson():
	"""Move to next lesson or show completion"""
	print("ChunkedReadingModule: Moving to next lesson")

func _show_lesson_placeholder(lesson_number: int):
	"""Show placeholder for lessons in development"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Lesson " + str(lesson_number) + " is in development!\n\n" + \
		"Chunked Reading features:\n" + \
		"• Text broken into small, manageable pieces\n" + \
		"• Visual supports (emojis, icons, pictures)\n" + \
		"• Highlighted key vocabulary\n" + \
		"• Gentle comprehension questions\n" + \
		"• No time pressure - read at your pace\n" + \
		"• Multiple choice and fill-in-the-blank activities\n" + \
		"• Progress tracking with encouraging feedback"
	
	dialog.title = "Chunked Reading - Lesson " + str(lesson_number)
	dialog.custom_minimum_size = Vector2(450, 350)
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	dialog.queue_free()
