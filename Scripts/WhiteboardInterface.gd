extends Control

# Add signals for drawing events
signal drawing_submitted(text_result)

# Drawing variables
var drawing = false
var points = []
var strokes = []
var undo_history = []
var stroke_color = Color(0, 0, 0)
var stroke_width = 2.0

func _ready():
	$VBoxContainer/ButtonsContainer/UndoButton.disabled = true
	$VBoxContainer/ButtonsContainer/RedoButton.disabled = true

func _on_drawing_area_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start new stroke
				drawing = true
				points = [event.position]
				strokes.append({"points": points.duplicate(), "color": stroke_color, "width": stroke_width})
				# Enable undo button once there's something to undo
				$VBoxContainer/ButtonsContainer/UndoButton.disabled = false
			else:
				# End stroke
				drawing = false
				# Add a duplicate of points to ensure the stroke keeps its data
				strokes[strokes.size()-1]["points"] = points.duplicate()
				# Save for undo
				undo_history = []
				# Disable redo button since we've added a new stroke
				$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
				
	elif event is InputEventMouseMotion and drawing:
		# Add point to current stroke
		points.append(event.position)
		strokes[strokes.size()-1]["points"] = points.duplicate()
		# Redraw
		$VBoxContainer/DrawingArea.queue_redraw()

func _on_drawing_area_draw():
	var canvas = $VBoxContainer/DrawingArea
	
	# Draw all strokes
	for stroke in strokes:
		var pts = stroke["points"]
		var color = stroke["color"]
		var width = stroke["width"]
		
		if pts.size() < 2:
			continue
			
		for i in range(1, pts.size()):
			canvas.draw_line(pts[i-1], pts[i], color, width)

func _on_clear_button_pressed():
	strokes = []
	undo_history = []
	$VBoxContainer/DrawingArea.queue_redraw()
	$VBoxContainer/ButtonsContainer/UndoButton.disabled = true
	$VBoxContainer/ButtonsContainer/RedoButton.disabled = true

func _on_undo_button_pressed():
	if strokes.size() > 0:
		undo_history.append(strokes.pop_back())
		$VBoxContainer/DrawingArea.queue_redraw()
		$VBoxContainer/ButtonsContainer/RedoButton.disabled = false
		
		# Disable undo button if no more strokes
		if strokes.size() == 0:
			$VBoxContainer/ButtonsContainer/UndoButton.disabled = true

func _on_redo_button_pressed():
	if undo_history.size() > 0:
		strokes.append(undo_history.pop_back())
		$VBoxContainer/DrawingArea.queue_redraw()
		$VBoxContainer/ButtonsContainer/UndoButton.disabled = false
		
		# Disable redo button if no more history
		if undo_history.size() == 0:
			$VBoxContainer/ButtonsContainer/RedoButton.disabled = true

# Function to handle drawing submission
func _on_done_button_pressed():
	# Simulate text recognition from drawing
	# In a real app, you would use OCR or other recognition APIs
	var recognized_text = "example"
	
	# For testing, we'll use a simple random word selection
	var possible_words = ["cat", "dog", "house", "tree", "book", "pen", "lake", "sun", "moon"]
	var random_index = randi() % possible_words.size()
	recognized_text = possible_words[random_index]
	
	# Emit signal with the recognized text
	emit_signal("drawing_submitted", recognized_text)
