extends Control

@onready var r_controlled_progress = $MainContainer/ContentContainer/SyllableContainer/RControlledCard/RControlledContainer/ProgressLabel
@onready var vowel_teams_progress = $MainContainer/ContentContainer/SyllableContainer/VowelTeamsCard/VowelTeamsContainer/ProgressLabel
@onready var consonant_le_progress = $MainContainer/ContentContainer/SyllableContainer/ConsonantLECard/ConsonantLEContainer/ProgressLabel
@onready var button_hover = $ButtonHover
@onready var button_click = $ButtonClick

var syllable_progress = {
	"r_controlled": 0,
	"vowel_teams": 0,
	"consonant_le": 0
}

# Firebase integration for module progress
var module_progress
var is_firebase_available = false

func _ready():
	await _init_module_progress()
	await _load_saved_progress()
	_connect_button_signals()
	_update_progress_display()

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
		var syllable_data = await module_progress.get_syllable_building_progress()
		if syllable_data and syllable_data.has("advanced_syllables") and syllable_data["advanced_syllables"].has("activities_completed"):
			var completed_activities = syllable_data["advanced_syllables"]["activities_completed"]
			# Count activities for each syllable type
			for activity in completed_activities:
				if activity.begins_with("r_controlled"):
					syllable_progress["r_controlled"] += 1
				elif activity.begins_with("vowel_teams"):
					syllable_progress["vowel_teams"] += 1
				elif activity.begins_with("consonant_le"):
					syllable_progress["consonant_le"] += 1
			print("AdvancedSyllablesScene: Loaded syllable progress from Firebase")

func _connect_button_signals():
	# Connect hover sounds to the back button
	var back_button = $MainContainer/HeaderPanel/HeaderContainer/BackButton
	if back_button:
		back_button.mouse_entered.connect(_on_button_hover)

func _update_progress_display():
	r_controlled_progress.text = "Progress: %d/5 completed" % syllable_progress.r_controlled
	vowel_teams_progress.text = "Progress: %d/5 completed" % syllable_progress.vowel_teams
	consonant_le_progress.text = "Progress: %d/5 completed" % syllable_progress.consonant_le

func _on_back_button_pressed():
	button_click.play()
	get_tree().change_scene_to_file("res://Scenes/SyllableBuildingModule.tscn")

func _on_button_hover():
	button_hover.play()

# Function to simulate completing syllable types (for testing)
func complete_syllable_type(type: String):
	if type in syllable_progress:
		syllable_progress[type] = min(syllable_progress[type] + 1, 5)
		_update_progress_display()
		
		# Save progress to Firebase
		if is_firebase_available and module_progress:
			var activity_id = type + "_activity_" + str(syllable_progress[type])
			var success = await module_progress.complete_syllable_activity("advanced_syllables", activity_id)
			if success:
				print("AdvancedSyllablesScene: Syllable progress saved to Firebase - ", activity_id)
			else:
				print("AdvancedSyllablesScene: Failed to save syllable progress to Firebase")
