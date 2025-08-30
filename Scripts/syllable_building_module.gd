extends Control

# ModuleProgress for Firebase integration
var module_progress

# Syllable type constants
const SYLLABLE_TYPES = {
	"closed": "A syllable ending in a consonant with a short vowel sound",
	"open": "A syllable ending in a long vowel sound",
	"magic_e": "A syllable with a silent e making the vowel long",
	"r_controlled": "A syllable where r changes the vowel sound",
	"vowel_team": "Two vowels working together to make one sound",
	"consonant_le": "A final syllable with a consonant plus le"
}

# UI References
@onready var progress_bar = $ProgressBar
@onready var progress_label = $ProgressLabel
@onready var syllable_type_container = $SyllableTypeContainer
@onready var word_display = $WordDisplay
@onready var definition_label = $DefinitionLabel
@onready var feedback_label = $FeedbackLabel

# Audio
@onready var button_click = $ButtonClick
@onready var button_hover = $ButtonHover

# TTS for word pronunciation
var tts

func _ready():
	$ButtonClick.play()
	_init_module_progress()
	_init_tts()
	_setup_ui()
	_load_progress()
	
	# Setup initial animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)

func _init_module_progress():
	if Engine.has_singleton("Firebase"):
		module_progress = ModuleProgress.new()
		print("DEBUG: Initialized ModuleProgress for SyllableBuilding")
	else:
		print("WARNING: Firebase not available, progress will not be saved")

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	
func _setup_ui():
	# Create buttons for each syllable type
	for type in SYLLABLE_TYPES.keys():
		var button = Button.new()
		button.text = type.capitalize()
		button.custom_minimum_size = Vector2(200, 50)
		button.pressed.connect(_on_syllable_type_selected.bind(type))
		button.mouse_entered.connect(_on_button_mouse_entered)
		syllable_type_container.add_child(button)
	
	# Initial state
	definition_label.text = "Select a syllable type to begin"
	feedback_label.text = ""
	word_display.text = ""

func _load_progress():
	if module_progress:
		var firebase_modules = await module_progress.fetch_modules()
		if firebase_modules != null and firebase_modules.has("syllable_building"):
			var syllable_data = firebase_modules["syllable_building"]
			_update_progress_ui(syllable_data.get("progress", 0))
			_update_syllable_type_buttons(syllable_data.get("syllable_types", {}))

func _update_progress_ui(percent: float):
	progress_bar.value = percent
	progress_label.text = "Progress: %d%%" % [percent]

func _update_syllable_type_buttons(syllable_types: Dictionary):
	for type in SYLLABLE_TYPES.keys():
		var type_data = syllable_types.get(type, {"completed": false})
		var button = _find_syllable_button(type)
		if button and type_data.get("completed", false):
			button.modulate = Color(0.5, 1.0, 0.5) # Green tint for completed

func _find_syllable_button(type: String) -> Button:
	for child in syllable_type_container.get_children():
		if child is Button and child.text.to_lower() == type:
			return child
	return null

func _on_syllable_type_selected(type: String):
	button_click.play()
	definition_label.text = SYLLABLE_TYPES[type]
	_load_syllable_words(type)

func _load_syllable_words(type: String):
	var words = []
	match type:
		"closed":
			words = ["cat", "sit", "dog", "run", "bed"]
		"open":
			words = ["me", "hi", "go", "she", "we"]
		"magic_e":
			words = ["make", "ride", "cute", "hope", "take"]
		"r_controlled":
			words = ["car", "bird", "turn", "her", "fur"]
		"vowel_team":
			words = ["rain", "meet", "boat", "keep", "slay"]
		"consonant_le":
			words = ["table", "maple", "little", "simple", "middle"]
	
	# Show first word from list
	if words.size() > 0:
		word_display.text = words[0]
		tts.speak(words[0])

func _on_word_completed(type: String, word: String):
	button_click.play()
	if module_progress:
		var success = await module_progress.set_syllable_word_completed(type, word)
		if success:
			feedback_label.text = "Great job!"
			await get_tree().create_timer(1.0).timeout
			feedback_label.text = ""
			
			# Update progress
			var firebase_modules = await module_progress.fetch_modules()
			if firebase_modules != null and firebase_modules.has("syllable_building"):
				_update_progress_ui(firebase_modules["syllable_building"].get("progress", 0))

func _on_back_button_pressed():
	button_click.play()
	print("SyllableBuildingModule: Returning to module selections")
	_fade_out_and_change_scene("res://Scenes/ModuleScene.tscn")

func _fade_out_and_change_scene(scene_path: String):
	# Stop any playing TTS
	if tts:
		tts.stop()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_button_mouse_entered():
	button_hover.play()
