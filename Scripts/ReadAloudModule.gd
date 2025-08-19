extends Control

var module_progress: ModuleProgress
var completion_celebration: CanvasLayer = null
var completion_celebration_scene = preload("res://Scenes/CompletionCelebration.tscn")

# Dyslexia-friendly reading passages with adjustable speed and highlighting
var reading_passages = [
	{
		"id": "simple_story_1",
		"title": "The Kind Cat",
		"text": "There was a cat. The cat was kind. The cat helped a bird. The bird was happy.",
		"level": "easy",
		"questions": [
			{"q": "What was the cat like?", "a": "kind"},
			{"q": "Who did the cat help?", "a": "bird"}
		]
	},
	{
		"id": "simple_story_2",
		"title": "The Red Ball",
		"text": "Sam had a red ball. The ball was big. Sam played with the ball. The ball rolled away.",
		"level": "easy",
		"questions": [
			{"q": "What color was the ball?", "a": "red"},
			{"q": "What did Sam do with the ball?", "a": "played"}
		]
	}
]

var current_passage = null
var current_word_index = 0
var reading_speed = 150 # WPM, adjustable for dyslexic users
var is_reading = false
var reading_timer: Timer
var words: PackedStringArray = []
var reading_finished = false

func _ready():
	print("ReadAloudModule: Interactive Read-Aloud module loaded")
	module_progress = ModuleProgress.new()
	_setup_passages()
	_connect_signals()
	# Timer for word highlighting
	reading_timer = Timer.new()
	reading_timer.one_shot = true
	add_child(reading_timer)
	reading_timer.timeout.connect(_on_reading_tick)

func _connect_signals():
	"""Connect all UI signals"""
	# Header controls
	var back_button = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		back_button.mouse_entered.connect(_on_button_hover)
	
	# Passage selection buttons
	var start_button1 = $MainContainer/ScrollContainer/ContentContainer/PassageSelectionCard/PassageContainer/PassageGrid/Passage1Card/Passage1Container/StartButton1
	if start_button1:
		start_button1.pressed.connect(_on_start_passage.bind(0))
		start_button1.mouse_entered.connect(_on_button_hover)
	
	var start_button2 = $MainContainer/ScrollContainer/ContentContainer/PassageSelectionCard/PassageContainer/PassageGrid/Passage2Card/Passage2Container/StartButton2
	if start_button2:
		start_button2.pressed.connect(_on_start_passage.bind(1))
		start_button2.mouse_entered.connect(_on_button_hover)
	
	# Reading controls
	var play_button = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingButtonsContainer/PlayButton
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
		play_button.mouse_entered.connect(_on_button_hover)

	var pause_button = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingButtonsContainer/PauseButton
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
		pause_button.mouse_entered.connect(_on_button_hover)
	
	var back_to_menu = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingButtonsContainer/BackToMenuButton
	if back_to_menu:
		back_to_menu.pressed.connect(_on_back_to_menu_pressed)
		back_to_menu.mouse_entered.connect(_on_button_hover)
	# Speed slider
	var speed_slider = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ControlsContainer/SpeedSlider
	if speed_slider:
		speed_slider.value_changed.connect(_on_speed_changed)

func _setup_passages():
	"""Setup reading passage selection for dyslexic learners"""
	print("ReadAloudModule: Setting up dyslexia-friendly reading passages")

func _on_button_hover():
	$ButtonHover.play()
func _on_back_button_pressed():
	print("ReadAloudModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_start_passage(passage_index: int):
	"""Start reading a specific passage"""
	print("ReadAloudModule: Starting passage ", passage_index)
	if passage_index < reading_passages.size():
		current_passage = reading_passages[passage_index]
		_show_reading_interface()

func _on_play_button_pressed():
	"""Start or resume reading"""
	print("ReadAloudModule: Play button pressed")
	if not is_reading:
		_start_reading_animation()

func _on_pause_button_pressed():
	"""Pause reading"""
	print("ReadAloudModule: Pause button pressed")
	if is_reading:
		_pause_reading_animation()

func _on_back_to_menu_pressed():
	"""Return to passage selection"""
	print("ReadAloudModule: Returning to passage menu")
	_show_passage_selection()

func _on_speed_changed(value: float):
	"""Update reading speed"""
	reading_speed = int(value)
	var speed_label = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ControlsContainer/SpeedValueLabel
	if speed_label:
		speed_label.text = str(reading_speed) + " WPM"

func _show_reading_interface():
	"""Switch to reading view"""
	var passage_card = $MainContainer/ScrollContainer/ContentContainer/PassageSelectionCard
	var reading_card = $MainContainer/ScrollContainer/ContentContainer/ReadingCard
	
	if passage_card and reading_card:
		passage_card.visible = false
		reading_card.visible = true
		
		# Update reading title
		var title_label = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingTitleLabel
		if title_label and current_passage:
			title_label.text = "Reading: " + current_passage.title
		
		# Update reading text
		var reading_text = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingArea/ReadingText
		if reading_text and current_passage:
			reading_text.text = current_passage.text

func _show_passage_selection():
	"""Switch to passage selection view"""
	var passage_card = $MainContainer/ScrollContainer/ContentContainer/PassageSelectionCard
	var reading_card = $MainContainer/ScrollContainer/ContentContainer/ReadingCard
	
	if passage_card and reading_card:
		reading_card.visible = false
		passage_card.visible = true
		is_reading = false

func _start_reading_animation():
	"""Start highlighting words during reading"""
	is_reading = true
	current_word_index = 0
	print("ReadAloudModule: Starting reading animation at ", reading_speed, " WPM")
	reading_finished = false
	words = []
	var reading_text = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingArea/ReadingText
	if reading_text and current_passage:
		words = current_passage.text.split(" ")
		_update_highlight(reading_text)
		_schedule_next_tick()

func _schedule_next_tick():
	if not is_reading:
		return
	var wpm = max(reading_speed, 60)
	var seconds_per_word = 60.0 / float(wpm)
	reading_timer.start(seconds_per_word)

func _on_reading_tick():
	if not is_reading:
		return
	current_word_index += 1
	var reading_text = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingArea/ReadingText
	if not reading_text:
		return
	if current_word_index < words.size():
		_update_highlight(reading_text)
		_schedule_next_tick()
	else:
		is_reading = false
		reading_finished = true
		await _simulate_passage_completion()
		_show_completion_celebration()

func _update_highlight(reading_text: RichTextLabel):
	var builder: Array[String] = []
	for i in range(words.size()):
		if i == current_word_index:
			builder.append("[color=blue]" + words[i] + "[/color]")
		else:
			builder.append(words[i])
	reading_text.text = " ".join(builder)

func _pause_reading_animation():
	"""Pause the reading animation"""
	is_reading = false
	print("ReadAloudModule: Reading paused")
	
	# Reset text color
	var reading_text = $MainContainer/ScrollContainer/ContentContainer/ReadingCard/ReadingContainer/ReadingArea/ReadingText
	if reading_text and current_passage:
		reading_text.text = current_passage.text

func _simulate_passage_completion():
	"""Simulate completing a reading passage with comprehension"""
	print("ReadAloudModule: Simulating passage completion")
	
	# Simulate comprehension score (70-100% for dyslexic learners)
	var comprehension_score = randi_range(70, 100)
	
	# Update progress in Firebase
	var success = await module_progress.set_read_aloud_passage_completed(current_passage.id, comprehension_score)
	
	if success:
		print("ReadAloudModule: Passage completed successfully!")
	return success

func _show_completion_celebration():
	"""Show completion celebration for finished passage"""
	var celebration = completion_celebration_scene.instantiate()
	add_child(celebration)
	
	# Calculate progress for celebration display
	var completed_passages = 1 # At least this passage is completed
	var total_passages = reading_passages.size()
	var progress_data = {
		"current": completed_passages,
		"total": total_passages,
		"percentage": (float(completed_passages) / float(total_passages)) * 100.0
	}
	
	celebration.show_completion("read_aloud", current_passage.title, progress_data, "read_aloud")
	
	# Connect celebration signals
	celebration.try_again_pressed.connect(_on_celebration_try_again)
	celebration.next_item_pressed.connect(_on_celebration_next_passage)

func _on_celebration_try_again():
	"""Read the same passage again"""
	print("ReadAloudModule: Trying passage again")

func _on_celebration_next_passage():
	"""Move to next passage or show completion"""
	# For now, just return to main module view
	print("ReadAloudModule: Moving to next passage or completing module")
