extends Control

@onready var current_word_label = $MainContainer/ContentContainer/WordPanel/WordContainer/CurrentWordLabel
@onready var definition_label = $MainContainer/ContentContainer/WordPanel/WordContainer/DefinitionLabel
@onready var context_label = $MainContainer/ContentContainer/WordPanel/WordContainer/ContextLabel
@onready var progress_label = $MainContainer/ContentContainer/ProgressPanel/ProgressContainer/ProgressInfo/ProgressLabel
@onready var category_label = $MainContainer/ContentContainer/ProgressPanel/ProgressContainer/ProgressInfo/CategoryLabel
@onready var button_hover = $ButtonHover
@onready var button_click = $ButtonClick

var vocabulary_data = [
	{
		"word": "elephant",
		"definition": "A very large animal with a long nose called a trunk",
		"context": "The elephant used its trunk to grab leaves from the tall tree.",
		"category": "Animal Words"
	},
	{
		"word": "ocean",
		"definition": "A very large body of salty water that covers most of Earth",
		"context": "The waves in the ocean were calm and peaceful today.",
		"category": "Nature Words"
	},
	{
		"word": "butterfly",
		"definition": "A colorful flying insect with large wings",
		"context": "The butterfly landed gently on the bright yellow flower.",
		"category": "Animal Words"
	},
	{
		"word": "mountain",
		"definition": "A very tall piece of land that reaches high into the sky",
		"context": "Snow covered the top of the tall mountain.",
		"category": "Nature Words"
	},
	{
		"word": "dinosaur",
		"definition": "A large animal that lived on Earth millions of years ago",
		"context": "The dinosaur bones were found buried deep in the ground.",
		"category": "Animal Words"
	},
	{
		"word": "rainbow",
		"definition": "A colorful arc in the sky that appears after rain",
		"context": "A beautiful rainbow appeared in the sky after the storm.",
		"category": "Nature Words"
	},
	{
		"word": "telescope",
		"definition": "A tool used to look at things that are very far away",
		"context": "She used the telescope to see the stars clearly at night.",
		"category": "Science Words"
	},
	{
		"word": "adventure",
		"definition": "An exciting journey or experience",
		"context": "Their camping trip turned into an amazing adventure.",
		"category": "Action Words"
	},
	{
		"word": "library",
		"definition": "A place where many books are kept for people to read",
		"context": "We found the perfect book at the library yesterday.",
		"category": "Place Words"
	},
	{
		"word": "friendship",
		"definition": "A close and caring relationship between people",
		"context": "Their friendship grew stronger through the years.",
		"category": "Feeling Words"
	}
]

var current_word_index = 0
var completed_words = []

# Firebase integration for module progress
var module_progress
var is_firebase_available = false

func _ready():
	await _init_module_progress()
	await _load_saved_progress()
	_display_current_word()
	_update_progress()
	_connect_button_signals()

func _init_module_progress():
	# Initialize module progress for Firebase integration
	if Engine.has_singleton("Firebase"):
		var ModuleProgressScript = load("res://Scripts/ModulesManager/ModuleProgress.gd")
		if ModuleProgressScript:
			module_progress = ModuleProgressScript.new()
			is_firebase_available = await module_progress.is_authenticated()
			if is_firebase_available:
				print("ChunkedVocabulary: Firebase module progress initialized")
			else:
				print("ChunkedVocabulary: Firebase not authenticated, using local progress")
		else:
			print("ChunkedVocabulary: ModuleProgress script not found")
	else:
		print("ChunkedVocabulary: Firebase not available")

func _load_saved_progress():
	# Load any saved progress from Firebase
	if is_firebase_available and module_progress:
		var chunked_progress = await module_progress.get_chunked_reading_progress()
		if chunked_progress and chunked_progress.has("vocabulary_words_completed") and chunked_progress["vocabulary_words_completed"] is Array:
			completed_words = chunked_progress["vocabulary_words_completed"].duplicate()
			# Set current word index based on progress
			current_word_index = completed_words.size()
			print("ChunkedVocabulary: Loaded progress - ", completed_words.size(), " words completed")

func _connect_button_signals():
	# Connect hover sounds to all buttons
	var buttons = [
		$MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton,
		$MainContainer/ContentContainer/WordPanel/WordContainer/ButtonContainer/HearWordButton,
		$MainContainer/ContentContainer/WordPanel/WordContainer/ButtonContainer/NextWordButton
	]
	
	for button in buttons:
		if button:
			button.mouse_entered.connect(_on_button_hover)

func _display_current_word():
	if current_word_index >= vocabulary_data.size():
		_show_completion()
		return
	
	var word_data = vocabulary_data[current_word_index]
	current_word_label.text = word_data.word
	definition_label.text = "[center]" + word_data.definition + "[/center]"
	context_label.text = "[center][i]" + word_data.context + "[/i][/center]"
	category_label.text = word_data.category

func _update_progress():
	progress_label.text = "Word " + str(current_word_index + 1) + " of " + str(vocabulary_data.size())

func _show_completion():
	current_word_label.text = "Great Job!"
	definition_label.text = "[center]You have learned all the vocabulary words![/center]"
	context_label.text = "[center][i]You can practice again or return to modules.[/i][/center]"
	category_label.text = "Complete"
	progress_label.text = "All words learned!"
	
	# Mark vocabulary as completed in Firebase
	if is_firebase_available and module_progress:
		var success = await module_progress.complete_chunked_reading_activity("vocabulary", "all_words_completed")
		if success:
			print("ChunkedVocabulary: Vocabulary completion saved to Firebase")
		else:
			print("ChunkedVocabulary: Failed to save completion to Firebase")

func _on_back_button_pressed():
	button_click.play()
	get_tree().change_scene_to_file("res://Scenes/ChunkedReadingModule.tscn")

func _on_hear_word_button_pressed():
	button_click.play()
	# Check bounds before accessing the array
	if current_word_index < vocabulary_data.size():
		var word_to_speak = vocabulary_data[current_word_index].word
		_speak_text(word_to_speak)
	else:
		print("ChunkedVocabulary: Warning - current_word_index out of bounds: ", current_word_index)

func _on_next_word_button_pressed():
	button_click.play()
	
	# Mark current word as completed
	if current_word_index < vocabulary_data.size():
		var completed_word = vocabulary_data[current_word_index].word
		completed_words.append(completed_word)
		
		# Save progress to Firebase
		if is_firebase_available and module_progress:
			var success = await module_progress.save_chunked_vocabulary_progress(completed_words)
			if success:
				print("ChunkedVocabulary: Word '", completed_word, "' progress saved to Firebase")
			else:
				print("ChunkedVocabulary: Failed to save word progress to Firebase")
	
	# Move to next word
	current_word_index += 1
	_display_current_word()
	_update_progress()

func _on_button_hover():
	button_hover.play()

func _on_vocabulary_done_button_pressed():
	"""Mark current vocabulary word as completed and advance"""
	button_click.play()
	
	# Mark current word as completed
	if current_word_index < vocabulary_data.size():
		var completed_word = vocabulary_data[current_word_index].word
		if not completed_word in completed_words:
			completed_words.append(completed_word)
			
			# Save progress to Firebase
			if is_firebase_available and module_progress:
				var success = await module_progress.save_chunked_vocabulary_progress(completed_words)
				if success:
					print("ChunkedVocabulary: Word '", completed_word, "' marked as completed in Firebase")
				else:
					print("ChunkedVocabulary: Failed to save word completion to Firebase")
			else:
				print("ChunkedVocabulary: Module progress not available, using local tracking")
			
			# Move to next word
			current_word_index += 1
			_display_current_word()
			_update_progress()
		else:
			print("ChunkedVocabulary: Word '", completed_word, "' already completed")
	else:
		print("ChunkedVocabulary: All words completed!")

func _speak_text(text: String):
	# Use Godot's built-in TTS if available
	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	
	# Use TTS with proper parameters: text and voice_id
	DisplayServer.tts_speak(text, "") # Empty string for default voice
