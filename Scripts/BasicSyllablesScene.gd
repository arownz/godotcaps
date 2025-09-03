extends Control

@onready var current_word_label = $MainContainer/ContentContainer/WordPanel/WordContainer/CurrentWordLabel
@onready var syllable_label1 = $MainContainer/ContentContainer/WordPanel/WordContainer/SyllableContainer/SyllablePanel1/SyllableLabel1
@onready var syllable_label2 = $MainContainer/ContentContainer/WordPanel/WordContainer/SyllableContainer/SyllablePanel2/SyllableLabel2
@onready var type_label = $MainContainer/ContentContainer/WordPanel/WordContainer/TypeLabel
@onready var progress_label = $MainContainer/ContentContainer/ProgressPanel/ProgressContainer/ProgressInfo/ProgressLabel
@onready var type_progress_label = $MainContainer/ContentContainer/ProgressPanel/ProgressContainer/ProgressInfo/TypeProgressLabel
@onready var button_hover = $ButtonHover
@onready var button_click = $ButtonClick

# Firebase integration for module progress
var module_progress
var is_firebase_available = false

var syllable_words = [
	# Closed syllables (consonant-vowel-consonant)
	{
		"word": "sunset",
		"syllables": ["sun", "set"],
		"type": "Closed + Closed"
	},
	{
		"word": "rabbit",
		"syllables": ["rab", "bit"],
		"type": "Closed + Closed"
	},
	{
		"word": "kitten",
		"syllables": ["kit", "ten"],
		"type": "Closed + Closed"
	},
	# Open syllables (consonant-vowel)
	{
		"word": "music",
		"syllables": ["mu", "sic"],
		"type": "Open + Closed"
	},
	{
		"word": "tiger",
		"syllables": ["ti", "ger"],
		"type": "Open + Closed"
	},
	{
		"word": "spider",
		"syllables": ["spi", "der"],
		"type": "Open + Closed"
	},
	# Magic-E syllables (consonant-vowel-consonant-e)
	{
		"word": "sunshine",
		"syllables": ["sun", "shine"],
		"type": "Closed + Magic-E"
	},
	{
		"word": "pancake",
		"syllables": ["pan", "cake"],
		"type": "Closed + Magic-E"
	},
	{
		"word": "cupcake",
		"syllables": ["cup", "cake"],
		"type": "Closed + Magic-E"
	},
	# Mixed syllable types
	{
		"word": "inside",
		"syllables": ["in", "side"],
		"type": "Closed + Magic-E"
	},
	{
		"word": "compete",
		"syllables": ["com", "pete"],
		"type": "Closed + Magic-E"
	},
	{
		"word": "reptile",
		"syllables": ["rep", "tile"],
		"type": "Closed + Magic-E"
	}
]

var current_word_index = 0
var completed_words = []

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
				print("BasicSyllablesScene: Firebase module progress initialized")
			else:
				print("BasicSyllablesScene: Firebase not authenticated, using local progress")
		else:
			print("BasicSyllablesScene: ModuleProgress script not found")
	else:
		print("BasicSyllablesScene: Firebase not available")

func _load_saved_progress():
	# Load any saved progress from Firebase
	if is_firebase_available and module_progress:
		var syllable_progress = await module_progress.get_syllable_building_progress()
		if syllable_progress.has("basic_completed_words") and syllable_progress["basic_completed_words"] is Array:
			completed_words = syllable_progress["basic_completed_words"].duplicate()
			# Set current word index based on progress
			current_word_index = completed_words.size()
			print("BasicSyllablesScene: Loaded progress - ", completed_words.size(), " words completed")

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
	if current_word_index >= syllable_words.size():
		_show_completion()
		return
	
	var word_data = syllable_words[current_word_index]
	current_word_label.text = word_data.word
	
	# Display syllables
	syllable_label1.text = word_data.syllables[0]
	if word_data.syllables.size() > 1:
		syllable_label2.text = word_data.syllables[1]
		syllable_label2.get_parent().visible = true
	else:
		syllable_label2.get_parent().visible = false
	
	type_label.text = word_data.type

func _update_progress():
	progress_label.text = "Word " + str(current_word_index + 1) + " of " + str(syllable_words.size())
	type_progress_label.text = "Closed + Open + Magic-E"

func _show_completion():
	current_word_label.text = "Excellent Work!"
	syllable_label1.text = "All"
	syllable_label2.text = "Done!"
	type_label.text = "You have mastered basic syllables!"
	progress_label.text = "Complete!"
	type_progress_label.text = "Ready for advanced syllables"
	
	# Mark basic syllables as completed in Firebase
	if is_firebase_available and module_progress:
		var success = await module_progress.set_syllable_building_basic_completed(true)
		if success:
			print("BasicSyllablesScene: Basic syllables completion saved to Firebase")
		else:
			print("BasicSyllablesScene: Failed to save completion to Firebase")

func _on_back_button_pressed():
	button_click.play()
	get_tree().change_scene_to_file("res://Scenes/SyllableBuildingModule.tscn")

func _on_hear_word_button_pressed():
	button_click.play()
	if current_word_index < syllable_words.size():
		var word_to_speak = syllable_words[current_word_index].word
		_speak_text(word_to_speak)

func _on_next_word_button_pressed():
	button_click.play()
	
	# Mark current word as completed
	if current_word_index < syllable_words.size():
		var completed_word = syllable_words[current_word_index].word
		completed_words.append(completed_word)
		
		# Save progress to Firebase
		if is_firebase_available and module_progress:
			var success = await module_progress.save_syllable_basic_word_progress(completed_words)
			if success:
				print("BasicSyllablesScene: Word '", completed_word, "' progress saved to Firebase")
			else:
				print("BasicSyllablesScene: Failed to save word progress to Firebase")
	
	# Move to next word
	current_word_index += 1
	_display_current_word()
	_update_progress()

func _on_button_hover():
	button_hover.play()

func _speak_text(text: String):
	# Use Godot's built-in TTS if available
	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	
	# Use TTS with proper parameters: text and voice_id
	DisplayServer.tts_speak(text, "") # Empty string for default voice
