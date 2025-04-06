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

# Recognition variables
var is_recognizing = false
var recognition_timeout = 10.0 # Timeout in seconds

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
	if is_recognizing:
		return
	
	if strokes.size() == 0:
		# Nothing to recognize
		emit_signal("drawing_submitted", "")
		return
	
	is_recognizing = true
	
	# Create a loading status
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Recognizing..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	status_label.position = Vector2($VBoxContainer/DrawingArea.size.x / 2 - 75, $VBoxContainer/DrawingArea.size.y / 2 - 15)
	status_label.size = Vector2(150, 30)
	$VBoxContainer/DrawingArea.add_child(status_label)
	
	# Capture the drawing as an image
	var drawing_area = $VBoxContainer/DrawingArea
	var image = get_viewport().get_texture().get_image()
	var rect = Rect2(drawing_area.global_position, drawing_area.size)
	var cropped_image = Image.create(int(rect.size.x), int(rect.size.y), false, Image.FORMAT_RGBA8)
	cropped_image.blit_rect(image, rect, Vector2.ZERO)
	
	# Create a timeout timer
	var timeout_timer = Timer.new()
	timeout_timer.one_shot = true
	timeout_timer.wait_time = recognition_timeout
	add_child(timeout_timer)
	timeout_timer.timeout.connect(_on_recognition_timeout.bind(timeout_timer))
	timeout_timer.start()
	
	# Use JavaScript bridge for OCR if we're on web platform
	if OS.get_name() == "Web":
		_recognize_text_with_tesseract(cropped_image, timeout_timer)
	else:
		# For testing in editor, we'll use a simple placeholder function
		_simulate_recognition(timeout_timer)

func _recognize_text_with_tesseract(image, timeout_timer):
	# Convert the Image to base64 encoding
	var img_buffer = image.save_png_to_buffer()
	var base64_string = Marshalls.raw_to_base64(img_buffer)
	
	# Create a callback for receiving the result from JavaScript
	var callback_id = JavaScriptBridge.create_callback(func(text_result):
		# Handle the case where text_result might be null or undefined
		if text_result == null or text_result.size() == 0:
			_on_recognition_completed("", timeout_timer)
		else:
			_on_recognition_completed(text_result[0], timeout_timer)
	)
	
	# Call the JavaScript function to process the image with error handling
	var js_code = """
	try {
		window.recognizeHandwritingFromImage('data:image/png;base64,%s', %s);
	} catch(e) {
		console.error('Error in recognizeHandwritingFromImage:', e);
		%s('');
	}
	""".format([base64_string, str(callback_id), str(callback_id)])
	
	# Wrap in try-catch to handle any JavaScript errors
	JavaScriptBridge.eval("""
	try {
		%s
	} catch(e) {
		console.error('JavaScriptBridge eval error:', e);
	}
	""" % js_code)

func _on_recognition_completed(text_result, timeout_timer):
	# Remove the timeout timer
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()
	
	# Remove loading status
	if $VBoxContainer/DrawingArea.has_node("StatusLabel"):
		$VBoxContainer/DrawingArea.get_node("StatusLabel").queue_free()
	
	is_recognizing = false
	
	# Clean up the text result (remove spaces, newlines, etc.)
	var cleaned_text = ""
	if text_result is String:
		cleaned_text = text_result.strip_edges().to_lower()
		cleaned_text = cleaned_text.replace("\n", "").replace("\r", "")
	else:
		print("Warning: Received non-string result from OCR")
		cleaned_text = ""
	
	# Emit the signal with the recognized text
	emit_signal("drawing_submitted", cleaned_text)

# FIX: Make timer parameter optional with default value of null
func _on_recognition_timeout(timeout_timer = null):
	if timeout_timer:
		timeout_timer.queue_free()
	
	# Remove loading status
	if $VBoxContainer/DrawingArea.has_node("StatusLabel"):
		$VBoxContainer/DrawingArea.get_node("StatusLabel").queue_free()
	
	is_recognizing = false
	
	# Emit signal with empty text to indicate failure
	emit_signal("drawing_submitted", "")

func _simulate_recognition(timeout_timer):
	# For testing in editor
	await get_tree().create_timer(1.5).timeout
	
	# Generate a random result (50% chance of success)
	var parent = get_parent().get_parent().get_parent()
	var random_word = ""
	
	if parent.has_method("get_challenge_word"):
		# Try to get the actual challenge word from the parent
		random_word = parent.get_challenge_word()
		
		# Simulate 75% accuracy for testing
		if randf() < 0.75:
			_on_recognition_completed(random_word, timeout_timer)
		else:
			var incorrect_words = ["cat", "dog", "house", "tree", "book"]
			var random_index = randi() % incorrect_words.size()
			_on_recognition_completed(incorrect_words[random_index], timeout_timer)
	else:
		# Fallback to default list
		var possible_words = ["cat", "dog", "house", "tree", "book"]
		var random_index = randi() % possible_words.size()
		random_word = possible_words[random_index]
		_on_recognition_completed(random_word, timeout_timer)
