extends Control

var module_progress: ModuleProgress

func _ready():
	module_progress = ModuleProgress.new()
	# Initialize UI elements and load progress
	_load_progress()

func _load_progress():
	if not module_progress.is_authenticated():
		return
	
	var progress = await module_progress.get_chunked_reading_progress()
	if progress:
		_update_progress(progress)

func _update_progress(progress_data: Dictionary):
	var passages = progress_data.get("passages_completed", [])
	var total_progress = progress_data.get("progress", 0)
	# Update UI based on advanced reading passages completed
	# Filter passages based on difficulty level
	_filter_advanced_passages(passages)
	
	# Update UI with total progress
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	if progress_label:
		progress_label.text = "Progress: " + str(total_progress) + "%"

func _filter_advanced_passages(passages: Array):
	# Filter and display only advanced level passages
	# Advanced passages have IDs starting with "advanced_"
	var advanced_passages = passages.filter(func(id): return id.begins_with("advanced_"))
	
	# Update UI to show completed advanced passages
	var passage_grid = $MainContainer/Content/VBoxContainer/PassageGrid
	if passage_grid:
		for passage in advanced_passages:
			var completion_label = Label.new()
			completion_label.text = "✓ " + passage.trim_prefix("advanced_")
			passage_grid.add_child(completion_label)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/ChunkedReadingModule.tscn")
