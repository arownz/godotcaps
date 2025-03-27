extends Control

signal word_submitted(text)

var drawing = false
var stroke_points = []
var strokes = []
var undo_history = []
var line_width = 4.0
var line_color = Color.BLACK

func _ready():
	$VBoxContainer/ButtonsContainer/UndoButton.disabled = true
	$VBoxContainer/ButtonsContainer/RedoButton.disabled = true

func _on_drawing_area_gui_input(event):
	var canvas = $VBoxContainer/DrawingArea
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drawing
				drawing = true
				stroke_points = [event.position]
			else:
				# End stroke
				drawing = false
				if stroke_points.size() > 1:
					strokes.append(stroke_points.duplicate())
					undo_history.clear()
					$VBoxContainer/ButtonsContainer/UndoButton.disabled = false
					$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
				stroke_points.clear()
				canvas.queue_redraw()
	
	elif event is InputEventMouseMotion and drawing:
		# Add point to current stroke
		stroke_points.append(event.position)
		canvas.queue_redraw()

# Connect this function to the draw signal of the DrawingArea
func _on_drawing_area_draw():
	# Draw saved strokes
	for stroke in strokes:
		_draw_stroke(stroke)
	
	# Draw current stroke
	if stroke_points.size() > 1:
		_draw_stroke(stroke_points)

func _draw_stroke(stroke):
	if stroke.size() < 2:
		return
	
	for i in range(1, stroke.size()):
		var line_start = stroke[i-1]
		var line_end = stroke[i]
		$VBoxContainer/DrawingArea.draw_line(line_start, line_end, line_color, line_width, true)

func _on_clear_button_pressed():
	strokes.clear()
	undo_history.clear()
	stroke_points.clear()
	$VBoxContainer/ButtonsContainer/UndoButton.disabled = true
	$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
	$VBoxContainer/DrawingArea.queue_redraw()

func _on_undo_button_pressed():
	if strokes.size() > 0:
		var last_stroke = strokes.pop_back()
		undo_history.append(last_stroke)
		$VBoxContainer/ButtonsContainer/RedoButton.disabled = false
		if strokes.size() == 0:
			$VBoxContainer/ButtonsContainer/UndoButton.disabled = true
		$VBoxContainer/DrawingArea.queue_redraw()

func _on_redo_button_pressed():
	if undo_history.size() > 0:
		var stroke = undo_history.pop_back()
		strokes.append(stroke)
		$VBoxContainer/ButtonsContainer/UndoButton.disabled = false
		if undo_history.size() == 0:
			$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
		$VBoxContainer/DrawingArea.queue_redraw()

func _on_done_button_pressed():
	# In a real application, you would use handwriting recognition here
	# For this demo, we'll simulate recognition by prompting the user
	
	if strokes.size() == 0:
		# No writing detected
		return
	
	# Create a simple dialog for text input
	var dialog = AcceptDialog.new()
	dialog.title = "Handwriting Recognition"
	
	# Create a container for the line edit
	var container = VBoxContainer.new()
	dialog.add_child(container)
	
	# Create the line edit and add it to the container
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "Enter text..."
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(line_edit)
	
	# Add some descriptive text
	var label = Label.new()
	label.text = "What did you write? (Enter the text)"
	container.add_child(label)
	
	# Set the custom minimum size for the dialog
	dialog.dialog_text = "" # Clear default text to use our custom layout
	dialog.min_size = Vector2(300, 150)
	
	# Add the dialog to the scene tree
	add_child(dialog)
	dialog.popup_centered()
	
	# Give focus to the line edit
	line_edit.grab_focus()
	
	# Connect the confirmed signal
	dialog.confirmed.connect(func(): _on_dialog_confirmed(line_edit))

# Handle dialog confirmation
func _on_dialog_confirmed(line_edit):
	if line_edit and line_edit.text.strip_edges() != "":
		word_submitted.emit(line_edit.text)
