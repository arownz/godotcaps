extends Control

var module_progress: ModuleProgress

func _ready():
	module_progress = ModuleProgress.new()
	# Initialize UI elements and load progress
	_load_progress()

func _load_progress():
	if not module_progress.is_authenticated():
		return
	
	var progress = await module_progress.get_syllable_building_progress()
	if progress:
		_load_syllable_types(progress)

func _load_syllable_types(progress_data: Dictionary):
	var syllable_types = progress_data.get("syllable_types", {})
	# Load advanced syllable types: r_controlled, vowel_team, consonant_le
	for type in ["r_controlled", "vowel_team", "consonant_le"]:
		var type_data = syllable_types.get(type, {"completed": false, "words": []})
		_update_type_progress(type, type_data)

func _update_type_progress(syllable_type: String, data: Dictionary):
	# Update UI to show progress for each syllable type
	var completed_words = data.get("words", [])
	var is_completed = data.get("completed", false)
	
	# Find or create container for this syllable type
	var type_container = $MainContainer/Content/VBoxContainer.get_node_or_null(syllable_type + "Container")
	if not type_container:
		type_container = VBoxContainer.new()
		type_container.name = syllable_type + "Container"
		$MainContainer/Content/VBoxContainer.add_child(type_container)
	
	# Update header and progress
	var header = Label.new()
	header.text = syllable_type.capitalize() + " Syllables:"
	type_container.add_child(header)
	
	# Show completed words
	for word in completed_words:
		var word_label = Label.new()
		word_label.text = "✓ " + word
		type_container.add_child(word_label)
	
	# Show completion status
	var status = Label.new()
	status.text = "Completed!" if is_completed else str(completed_words.size()) + "/5 words"
	type_container.add_child(status)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/SyllableBuildingModule.tscn")
