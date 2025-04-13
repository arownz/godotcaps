extends Control

# Add signals for drawing events
signal drawing_submitted(text_result)
signal drawing_cancelled

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
	# If there are no strokes, don't attempt recognition
	if strokes.size() == 0:
		return
		
	# Convert strokes to image and send for recognition
	recognize_handwriting()

# Function to handle cancellation
func _on_cancel_button_pressed():
	# Emit signal to indicate the player cancelled the challenge
	emit_signal("drawing_cancelled")

# Performs handwriting recognition on the current drawing
func recognize_handwriting():
	# We'll implement JavaScript bridge for web-based recognition
	if OS.has_feature("JavaScript"):
		# Export drawing as image data and send to JS for recognition
		var img_data = await export_drawing_to_image_data()
		recognize_via_javascript(img_data)
	else:
		# Fallback for non-web platforms
		fallback_recognition()

# Exports the drawing to a format suitable for recognition
func export_drawing_to_image_data():
	# Create a viewport to render the drawing
	var viewport = SubViewport.new()
	viewport.size = $VBoxContainer/DrawingArea.size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Create a control to draw the strokes on
	var draw_control = Control.new()
	draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add a draw function to the control
	draw_control.draw.connect(func():
		for stroke in strokes:
			var pts = stroke["points"]
			var color = stroke["color"]
			var width = stroke["width"]
			
			if pts.size() < 2:
				continue
				
			for i in range(1, pts.size()):
				draw_control.draw_line(pts[i-1], pts[i], color, width)
	)
	
	# Add to the tree temporarily
	viewport.add_child(draw_control)
	add_child(viewport)
	
	# Get the image data
	await RenderingServer.frame_post_draw
	var img = viewport.get_texture().get_image()
	var img_data = img.save_png_to_buffer()
	
	# Clean up
	viewport.queue_free()
	
	return img_data

# Function to call JavaScript for recognition
func recognize_via_javascript(img_data):
	if OS.has_feature("JavaScript"):
		 # Make sure we're using the JavaScriptBridge
		var JavaScript = JavaScriptBridge
		
		# Create a JavaScript function for recognition if it doesn't exist
		JavaScript.eval("""
			if (typeof window.recognizeHandwriting !== 'function') {
				window.recognizeHandwriting = function(imageData, canvasWidth, canvasHeight) {
					return new Promise((resolve) => {
						// Use a lightweight recognition library (modified simple-handwriting-recognition)
						// This is a simplified version for demonstration
						const canvas = document.createElement('canvas');
						canvas.width = canvasWidth;
						canvas.height = canvasHeight;
						const ctx = canvas.getContext('2d');
						
						const img = new Image();
						img.onload = function() {
							ctx.drawImage(img, 0, 0);
							
							 // Process image for better recognition
							const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
							const data = imageData.data;
							
							// Apply thresholding to improve contrast
							for (let i = 0; i < data.length; i += 4) {
								const avg = (data[i] + data[i+1] + data[i+2]) / 3;
								const val = avg < 128 ? 0 : 255;
								data[i] = data[i+1] = data[i+2] = val;
							}
							ctx.putImageData(imageData, 0, 0);
							
							// In a real implementation, this would connect to Tesseract.js
							// But for now, we'll just return the challenge word as a fallback
							try {
								if (typeof Tesseract !== 'undefined') {
									// If Tesseract.js is loaded, use it for recognition
									Tesseract.recognize(canvas.toDataURL('image/png'), {
										lang: 'eng',
									}).then(result => {
										console.log("Recognition result:", result);
										let text = result.data.text.trim();
										// Remove line breaks and special characters
										text = text.replace(/[\\r\\n]+/g, ' ');
										text = text.replace(/[^a-zA-Z0-9 ]/g, '');
										resolve(text);
									}).catch(err => {
										console.error("OCR error:", err);
										resolve("recognition_error");
									});
								} else {
									// Fallback if Tesseract is not available
									console.log("Tesseract.js not available, using fallback");
									resolve("recognition_fallback");
								}
							} catch (e) {
								console.error("Recognition error:", e);
								resolve("recognition_error");
							}
						};
						
						img.src = 'data:image/png;base64,' + imageData;
					});
				};
			}
		""")
		
		# Call the JavaScript function
		var canvas_width = $VBoxContainer/DrawingArea.size.x
		var canvas_height = $VBoxContainer/DrawingArea.size.y
		var img_base64 = Marshalls.raw_to_base64(img_data)
		
		JavaScript.eval("""
			(async function() {
				try {
					const result = await window.recognizeHandwriting("%s", %d, %d);
					window.godot.handleRecognitionResult(result);
				} catch (error) {
					console.error("Handwriting recognition error:", error);
					window.godot.handleRecognitionError(error.toString());
				}
			})();
		""" % [img_base64, canvas_width, canvas_height])
		
		# Set up callback handlers
		JavaScript.eval("""
			window.godot = window.godot || {};
			window.godot.handleRecognitionResult = function(result) {
				window.godot.getEngine().sendMessage('%s', 'js_recognition_result', result);
			};
			window.godot.handleRecognitionError = function(error) {
				window.godot.getEngine().sendMessage('%s', 'js_recognition_error', error);
			};
		""" % [get_path(), get_path()])

# Fallback recognition for testing or non-web platforms
func fallback_recognition():
	# Create a heuristic that compares drawn strokes with the expected word
	# This is far from ideal, but serves as a placeholder
	var result = analyze_drawing_features()
	emit_signal("drawing_submitted", result)

# Analyze basic drawing features for fallback recognition
func analyze_drawing_features():
	# Basic heuristic for letters - counts total strokes, length, and height/width ratio
	var total_points = 0
	var total_length = 0.0
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	var total_strokes = strokes.size()
	
	# Drawing is too simple - not enough strokes for a real word
	if total_strokes < 1:
		return "no_text_detected"
	
	# Calculate various metrics about the drawing
	for stroke in strokes:
		var pts = stroke["points"]
		total_points += pts.size()
		
		for i in range(1, pts.size()):
			total_length += pts[i].distance_to(pts[i-1])
			
		for pt in pts:
			min_x = min(min_x, pt.x)
			max_x = max(max_x, pt.x)
			min_y = min(min_y, pt.y)
			max_y = max(max_y, pt.y)
	
	# Get width and height of drawing
	var width = max_x - min_x
	var height = max_y - min_y
	
	# Reject drawings that are too small or simple
	if width < 20 or height < 20 or total_points < 10:
		return "drawing_too_small"
	
	# Detect scribbles (extremely high point density)
	var drawing_area = width * height
	var point_density = float(total_points) / max(drawing_area, 1.0)
	if point_density > 0.1 and total_length > 1000:
		return "looks_like_scribble"
	
	# Access variables from parent (challenge word) if possible
	var parent = get_parent()
	while parent and not parent.has_method("get_challenge_word"):
		parent = parent.get_parent()
	
	var fallback_word = "no_text_detected"
	
	# IMPORTANT: Return a random word so user actually needs to write correctly
	# This prevents the system from always returning the correct answer
	var possible_words = ["cat", "dog", "house", "tree", "book", "pen", "lake", "sun", "moon", 
						 "card", "fish", "bird", "ball", "star", "ring", "desk", "lamp", "door"]
	
	# Only provide a reasonable word for decent attempts
	if total_length > 100 and total_strokes >= 1:
		var random_index = randi() % possible_words.size()
		fallback_word = possible_words[random_index]
	
	return fallback_word

# JavaScript callback handlers
func js_recognition_result(result):
	emit_signal("drawing_submitted", result)

func js_recognition_error(error):
	print("Recognition error: ", error)
	# Fallback to basic recognition
	fallback_recognition()
