extends Control

func _ready():
	print("ChunkedReadingModule: Chunked Reading module loaded")

func _on_back_button_pressed():
	print("ChunkedReadingModule: Returning to module selection")
	get_tree().change_scene_to_file("res://Scenes/ModuleScene.tscn")

func _on_start_lesson_pressed(lesson_number: int):
	print("ChunkedReadingModule: Starting lesson ", lesson_number)
	# Store that we came from chunked reading module
	if GlobalData:
		GlobalData.current_module = "chunked_reading"
		GlobalData.previous_scene = "res://Scenes/ChunkedReadingModule.tscn"
	
	# For now, show a placeholder message
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Lesson " + str(lesson_number) + " is in development!\n\nThis will feature:\n• Text broken into small chunks\n• Guided comprehension questions\n• Progressive difficulty levels\n• Visual reading aids"
	dialog.title = "Chunked Reading - Lesson " + str(lesson_number)
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	dialog.queue_free()
