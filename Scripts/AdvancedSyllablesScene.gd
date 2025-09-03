extends Control

# Audio nodes
@onready var button_hover = $ButtonHover
@onready var button_click = $ButtonClick

# UI References for new interactive interface
@onready var category_selection_panel = $MainContainer/ContentContainer/MainContent/CategorySelectionPanel
@onready var practice_panel = $MainContainer/ContentContainer/MainContent/PracticePanel
@onready var completion_panel = $MainContainer/ContentContainer/MainContent/CompletionPanel

# Category selection buttons
@onready var r_controlled_button = $MainContainer/ContentContainer/MainContent/CategorySelectionPanel/CategoryContainer/RControlledButton
@onready var vowel_teams_button = $MainContainer/ContentContainer/MainContent/CategorySelectionPanel/CategoryContainer/VowelTeamsButton
@onready var consonant_le_button = $MainContainer/ContentContainer/MainContent/CategorySelectionPanel/CategoryContainer/ConsonantLEButton

# Practice interface elements
@onready var instruction_label = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/WordDisplaySection/InstructionLabel
@onready var current_word_label = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/WordDisplaySection/CurrentWordLabel
@onready var hear_word_button = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/WordDisplaySection/HearWordButton
@onready var syllable_label1 = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/SyllableBuilderSection/SyllablePartsContainer/SyllablePart1/SyllableLabel1
@onready var syllable_label2 = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/SyllableBuilderSection/SyllablePartsContainer/SyllablePart2/SyllableLabel2
@onready var hear_syllable1_button = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/SyllableBuilderSection/SyllablePartsContainer/SyllablePart1/HearSyllable1
@onready var hear_syllable2_button = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/SyllableBuilderSection/SyllablePartsContainer/SyllablePart2/HearSyllable2
@onready var pattern_label = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/PatternExplanation/PatternLabel
@onready var explanation_text = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/PatternExplanation/ExplanationText
@onready var progress_label = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/ControlsSection/ProgressLabel
@onready var understood_button = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/ControlsSection/UnderstoodButton
@onready var next_word_button = $MainContainer/ContentContainer/MainContent/PracticePanel/PracticeContainer/ControlsSection/NextWordButton

# Completion interface elements
@onready var congratulations_label = $MainContainer/ContentContainer/MainContent/CompletionPanel/CompletionContainer/CongratulationsLabel
@onready var completion_message = $MainContainer/ContentContainer/MainContent/CompletionPanel/CompletionContainer/CompletionMessage
@onready var done_button = $MainContainer/ContentContainer/MainContent/CompletionPanel/CompletionContainer/DoneButtonContainer/DoneButton
@onready var practice_different_button = $MainContainer/ContentContainer/MainContent/CompletionPanel/CompletionContainer/DoneButtonContainer/PracticeDifferentButton

# Syllable practice data for each category
var syllable_data = {
	"r_controlled": [
		{"word": "car", "syllables": ["car"], "pattern": "R-Controlled"},
		{"word": "garden", "syllables": ["gar", "den"], "pattern": "R-Controlled + Closed"},
		{"word": "farmer", "syllables": ["far", "mer"], "pattern": "R-Controlled + R-Controlled"},
		{"word": "market", "syllables": ["mar", "ket"], "pattern": "R-Controlled + Closed"},
		{"word": "turkey", "syllables": ["tur", "key"], "pattern": "R-Controlled + Open"}
	],
	"vowel_teams": [
		{"word": "rain", "syllables": ["rain"], "pattern": "Vowel Team"},
		{"word": "rainbow", "syllables": ["rain", "bow"], "pattern": "Vowel Team + Closed"},
		{"word": "teacher", "syllables": ["teach", "er"], "pattern": "Vowel Team + R-Controlled"},
		{"word": "football", "syllables": ["foot", "ball"], "pattern": "Vowel Team + Closed"},
		{"word": "reading", "syllables": ["read", "ing"], "pattern": "Vowel Team + Closed"}
	],
	"consonant_le": [
		{"word": "table", "syllables": ["ta", "ble"], "pattern": "Open + Consonant-LE"},
		{"word": "simple", "syllables": ["sim", "ple"], "pattern": "Closed + Consonant-LE"},
		{"word": "purple", "syllables": ["pur", "ple"], "pattern": "R-Controlled + Consonant-LE"},
		{"word": "gentle", "syllables": ["gen", "tle"], "pattern": "Closed + Consonant-LE"},
		{"word": "sparkle", "syllables": ["spar", "kle"], "pattern": "R-Controlled + Consonant-LE"}
	]
}

var syllable_progress = {
	"r_controlled": 0,
	"vowel_teams": 0,
	"consonant_le": 0
}

var current_practice_category = ""
var current_practice_index = 0
var current_practice_words = []

# Firebase integration for module progress
var module_progress
var is_firebase_available = false

func _ready():
	await _init_module_progress()
	await _load_saved_progress()
	_connect_button_signals()
	_setup_initial_interface()

func _init_module_progress():
	# Initialize module progress for Firebase integration
	if Engine.has_singleton("Firebase"):
		var ModuleProgressScript = load("res://Scripts/ModulesManager/ModuleProgress.gd")
		if ModuleProgressScript:
			module_progress = ModuleProgressScript.new()
			is_firebase_available = await module_progress.is_authenticated()
			if is_firebase_available:
				print("AdvancedSyllablesScene: Firebase module progress initialized")
			else:
				print("AdvancedSyllablesScene: Firebase not authenticated, using local progress")
		else:
			print("AdvancedSyllablesScene: ModuleProgress script not found")
	else:
		print("AdvancedSyllablesScene: Firebase not available")

func _load_saved_progress():
	# Load any saved progress from Firebase
	if is_firebase_available and module_progress:
		var firebase_syllable_data = await module_progress.get_syllable_building_progress()
		if firebase_syllable_data and firebase_syllable_data.has("advanced_syllables") and firebase_syllable_data["advanced_syllables"].has("activities_completed"):
			var completed_activities = firebase_syllable_data["advanced_syllables"]["activities_completed"]
			# Count activities for each syllable type
			for activity in completed_activities:
				if activity.begins_with("r_controlled"):
					syllable_progress["r_controlled"] += 1
				elif activity.begins_with("vowel_teams"):
					syllable_progress["vowel_teams"] += 1
				elif activity.begins_with("consonant_le"):
					syllable_progress["consonant_le"] += 1
			print("AdvancedSyllablesScene: Loaded syllable progress from Firebase")

func _setup_initial_interface():
	# Show category selection, hide practice and completion panels
	category_selection_panel.visible = true
	practice_panel.visible = false
	completion_panel.visible = false

func _connect_button_signals():
	# Connect hover sounds to the back button
	var back_button = $MainContainer/HeaderPanel/HeaderContainer/BackButton
	if back_button:
		back_button.mouse_entered.connect(_on_button_hover)
		# Note: pressed signal already connected in scene file
	
	# Connect category selection buttons
	if r_controlled_button:
		r_controlled_button.pressed.connect(_on_r_controlled_practice_pressed)
		r_controlled_button.mouse_entered.connect(_on_button_hover)
	
	if vowel_teams_button:
		vowel_teams_button.pressed.connect(_on_vowel_teams_practice_pressed)
		vowel_teams_button.mouse_entered.connect(_on_button_hover)
	
	if consonant_le_button:
		consonant_le_button.pressed.connect(_on_consonant_le_practice_pressed)
		consonant_le_button.mouse_entered.connect(_on_button_hover)
	
	# Connect practice interface buttons
	if hear_word_button:
		hear_word_button.pressed.connect(_on_hear_word_pressed)
		hear_word_button.mouse_entered.connect(_on_button_hover)
	
	if hear_syllable1_button:
		hear_syllable1_button.pressed.connect(_on_hear_syllable1_pressed)
		hear_syllable1_button.mouse_entered.connect(_on_button_hover)
	
	if hear_syllable2_button:
		hear_syllable2_button.pressed.connect(_on_hear_syllable2_pressed)
		hear_syllable2_button.mouse_entered.connect(_on_button_hover)
	
	if understood_button:
		understood_button.pressed.connect(_on_understood_pressed)
		understood_button.mouse_entered.connect(_on_button_hover)
	
	if next_word_button:
		next_word_button.pressed.connect(_on_next_word_pressed)
		next_word_button.mouse_entered.connect(_on_button_hover)
	
	# Connect completion interface buttons
	if done_button:
		done_button.pressed.connect(_on_done_button_pressed)
		done_button.mouse_entered.connect(_on_button_hover)
	
	if practice_different_button:
		practice_different_button.pressed.connect(_on_practice_different_pressed)
		practice_different_button.mouse_entered.connect(_on_button_hover)

func _on_back_button_pressed():
	button_click.play()
	get_tree().change_scene_to_file("res://Scenes/SyllableBuildingModule.tscn")

func _on_button_hover():
	button_hover.play()

# Category selection handlers
func _on_r_controlled_practice_pressed():
	button_click.play()
	print("AdvancedSyllablesScene: R-Controlled practice started")
	_start_syllable_practice("r_controlled")

func _on_vowel_teams_practice_pressed():
	button_click.play()
	print("AdvancedSyllablesScene: Vowel Teams practice started")
	_start_syllable_practice("vowel_teams")

func _on_consonant_le_practice_pressed():
	button_click.play()
	print("AdvancedSyllablesScene: Consonant LE practice started")
	_start_syllable_practice("consonant_le")

# Practice interface handlers
func _on_hear_word_pressed():
	button_click.play()
	if current_practice_words.size() > current_practice_index:
		var word = current_practice_words[current_practice_index]["word"]
		print("AdvancedSyllablesScene: Playing word audio - ", word)
		# TODO: Implement TTS for word

func _on_hear_syllable1_pressed():
	button_click.play()
	if current_practice_words.size() > current_practice_index:
		var syllables = current_practice_words[current_practice_index]["syllables"]
		if syllables.size() > 0:
			print("AdvancedSyllablesScene: Playing syllable 1 audio - ", syllables[0])
			# TODO: Implement TTS for syllable

func _on_hear_syllable2_pressed():
	button_click.play()
	if current_practice_words.size() > current_practice_index:
		var syllables = current_practice_words[current_practice_index]["syllables"]
		if syllables.size() > 1:
			print("AdvancedSyllablesScene: Playing syllable 2 audio - ", syllables[1])
			# TODO: Implement TTS for syllable

func _on_understood_pressed():
	button_click.play()
	print("AdvancedSyllablesScene: Student understood the syllable pattern")
	_advance_to_next_word()

func _on_next_word_pressed():
	button_click.play()
	print("AdvancedSyllablesScene: Moving to next word")
	_advance_to_next_word()

# Completion interface handlers
func _on_done_button_pressed():
	button_click.play()
	await _save_category_completion()
	get_tree().change_scene_to_file("res://Scenes/SyllableBuildingModule.tscn")

func _on_practice_different_pressed():
	button_click.play()
	print("AdvancedSyllablesScene: Returning to category selection")
	_return_to_category_selection()

func _start_syllable_practice(category: String):
	"""Start practicing a specific syllable category"""
	current_practice_category = category
	current_practice_index = 0
	current_practice_words = syllable_data[category]
	
	# Check if already completed
	if syllable_progress[category] >= current_practice_words.size():
		_show_category_completed(category)
		return
	
	# Show practice interface
	category_selection_panel.visible = false
	practice_panel.visible = true
	completion_panel.visible = false
	
	# Load first word
	_display_current_word()

func _display_current_word():
	"""Display the current word and syllable breakdown"""
	if current_practice_index >= current_practice_words.size():
		_show_category_completed(current_practice_category)
		return
	
	var word_data = current_practice_words[current_practice_index]
	var word = word_data["word"]
	var syllables = word_data["syllables"]
	var pattern = word_data["pattern"]
	
	# Update word display
	current_word_label.text = word
	progress_label.text = "Word %d of %d" % [current_practice_index + 1, current_practice_words.size()]
	
	# Update syllable breakdown
	if syllables.size() >= 1:
		syllable_label1.text = syllables[0]
		syllable_label1.get_parent().visible = true
	else:
		syllable_label1.get_parent().visible = false
	
	if syllables.size() >= 2:
		syllable_label2.text = syllables[1]
		syllable_label2.get_parent().visible = true
	else:
		syllable_label2.get_parent().visible = false
	
	# Update pattern explanation
	pattern_label.text = "Pattern: " + pattern
	_update_explanation_text(pattern, syllables)
	
	print("AdvancedSyllablesScene: Displaying word - ", word, " | Syllables: ", syllables, " | Pattern: ", pattern)

func _update_explanation_text(pattern: String, _syllables: Array):
	"""Update the pattern explanation based on syllable types"""
	var explanation = ""
	
	if pattern.contains("R-Controlled"):
		explanation += "R-controlled vowels change the vowel sound\n"
	if pattern.contains("Vowel Team"):
		explanation += "Two vowels work together to make one sound\n"
	if pattern.contains("Consonant-LE"):
		explanation += "Words ending with consonant + LE\n"
	if pattern.contains("Closed"):
		explanation += "Closed syllables end with consonants\n"
	if pattern.contains("Open"):
		explanation += "Open syllables end with vowels\n"
	
	explanation_text.text = "[center]" + explanation + "[/center]"

func _advance_to_next_word():
	"""Move to the next word in the practice sequence"""
	current_practice_index += 1
	
	# Save progress for this word
	await _save_word_progress()
	
	if current_practice_index >= current_practice_words.size():
		# Completed all words in this category
		_show_category_completed(current_practice_category)
	else:
		# Show next word
		_display_current_word()

func _save_word_progress():
	"""Save progress for the current word to Firebase"""
	if is_firebase_available and module_progress:
		var activity_id = current_practice_category + "_word_" + str(current_practice_index + 1)
		var success = await module_progress.complete_syllable_activity("advanced_syllables", activity_id)
		if success:
			print("AdvancedSyllablesScene: Word progress saved to Firebase - ", activity_id)
			syllable_progress[current_practice_category] = current_practice_index + 1
		else:
			print("AdvancedSyllablesScene: Failed to save word progress to Firebase")

func _show_category_completed(category: String):
	"""Show completion interface for a syllable category"""
	var category_name = category.replace("_", " ").capitalize().replace(" Le", "-LE")
	
	# Update completion message
	congratulations_label.text = "Excellent Work!"
	completion_message.text = "[center]You've completed all the " + category_name + " syllable practice words!\nYou're getting better at recognizing syllable patterns.[/center]"
	
	# Show completion interface
	practice_panel.visible = false
	completion_panel.visible = true
	
	print("AdvancedSyllablesScene: ", category_name, " category completed!")

func _save_category_completion():
	"""Save the complete category as finished"""
	if is_firebase_available and module_progress:
		var category_completion_id = current_practice_category + "_completed"
		var success = await module_progress.complete_syllable_activity("advanced_syllables", category_completion_id)
		if success:
			print("AdvancedSyllablesScene: Category completion saved to Firebase - ", category_completion_id)
		else:
			print("AdvancedSyllablesScene: Failed to save category completion to Firebase")

func _return_to_category_selection():
	"""Return to the category selection interface"""
	current_practice_category = ""
	current_practice_index = 0
	current_practice_words = []
	
	# Show category selection interface
	category_selection_panel.visible = true
	practice_panel.visible = false
	completion_panel.visible = false
