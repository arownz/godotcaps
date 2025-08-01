extends Control

# Add the preload for GoogleCloudVision.gd to resolve the error
const GoogleCloudVision = preload("res://Scripts/GoogleCloudVision.gd")

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
var current_stroke = null

# For Google Cloud Vision Integration
var google_cloud_vision = null
var recognition_in_progress = false

# UI feedback
var status_label = null

# Debugging helper
var debug_mode = true

# Reference to viewport for image export
var export_viewport = null

# Reference to debug label
var debug_label: Label = null

func _ready():
	$VBoxContainer/ButtonsContainer/UndoButton.disabled = true
	$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
	
	# Add status label if it doesn't exist
	if not has_node("StatusLabel"):
		var label = Label.new()
		label.name = "StatusLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		label.anchors_preset = Control.PRESET_CENTER
		label.size = Vector2(600, 80)
		label.position = Vector2(-300, 250)
		label.visible = false
		add_child(label)
		status_label = label
	else:
		status_label = $StatusLabel

	# Add debug label for development
	if OS.is_debug_build() and not has_node("DebugLabel"):
		var debug = Label.new()
		debug.name = "DebugLabel"
		debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		debug.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		debug.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
		debug.add_theme_font_size_override("font_size", 16)
		debug.add_theme_color_override("font_color", Color(0, 0, 0, 1.0))
		debug.anchors_preset = Control.PRESET_TOP_LEFT
		debug.position = Vector2(10, 10)
		debug.visible = true
		debug.text = "Write the random word in this whiteboard!"
		add_child(debug)
		debug_label = debug
	elif has_node("DebugLabel"):
		debug_label = $DebugLabel
		
	# Connect to drawing functions to manage debug label visibility
	if debug_label:
		# Show label when drawing is cleared
		$VBoxContainer/ButtonsContainer/ClearButton.pressed.connect(func(): debug_label.visible = true)
	
	# Initialize drawing system
	setup_drawing()
	debug_log("WhiteboardInterface ready")
	
	# Create the Google Cloud Vision instance
	google_cloud_vision = GoogleCloudVision.new()
	add_child(google_cloud_vision)
	
	# Connect signals
	google_cloud_vision.recognition_completed.connect(_on_recognition_completed)
	google_cloud_vision.recognition_error.connect(_on_recognition_error)
	
	# Debug output log for the whiteboard interface initialization
	print("Whiteboard interface initialized with Google Cloud Vision API integration")
	
	# Test JavaScript bridge if on web platform
	if OS.has_feature("web"):
		print("Testing JavaScript bridge...")
		test_javascript_bridge()

# Handle input events for drawing
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var draw_area_rect = $VBoxContainer/DrawingArea.get_global_rect()
			
			if draw_area_rect.has_point(event.position):
				if event.pressed:
					_start_stroke(event.position - $VBoxContainer/DrawingArea.global_position)
				else:
					_end_stroke()
	
	elif event is InputEventMouseMotion and drawing:
		var draw_area_rect = $VBoxContainer/DrawingArea.get_global_rect()
		
		if draw_area_rect.has_point(event.position):
			_add_point_to_stroke(event.position - $VBoxContainer/DrawingArea.global_position)
			$VBoxContainer/DrawingArea.queue_redraw()

# Start a new stroke
func _start_stroke(pposition):
	drawing = true
	current_stroke = {
		"points": [pposition],
		"color": stroke_color,
		"width": stroke_width
	}
	
	# Hide debug label when drawing starts
	if debug_label:
		debug_label.visible = false

# Add point to current stroke
func _add_point_to_stroke(pposition):
	if current_stroke:
		current_stroke.points.append(pposition)

# End current stroke
func _end_stroke():
	drawing = false
	if current_stroke:
		strokes.append(current_stroke)
		undo_history = []
		$VBoxContainer/ButtonsContainer/UndoButton.disabled = false
		$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
		current_stroke = null

# Draw the strokes
func _on_drawing_area_draw():
	# Draw all completed strokes
	for stroke in strokes:
		_draw_stroke(stroke)
	
	# Draw current stroke
	if current_stroke:
		_draw_stroke(current_stroke)

# Helper function to draw a stroke
func _draw_stroke(stroke):
	if stroke.points.size() < 2:
		return
		
	var points_array = []
	for point in stroke.points:
		points_array.append(point)
	
	for i in range(1, points_array.size()):
		var from = points_array[i - 1]
		var to = points_array[i]
		$VBoxContainer/DrawingArea.draw_line(from, to, stroke.color, stroke.width)

# Undo last stroke
func _on_undo_button_pressed():
	if strokes.size() > 0:
		var last_stroke = strokes.pop_back()
		undo_history.append(last_stroke)
		$VBoxContainer/ButtonsContainer/RedoButton.disabled = false
		$VBoxContainer/ButtonsContainer/UndoButton.disabled = strokes.size() == 0
		$VBoxContainer/DrawingArea.queue_redraw()

# Redo last undone stroke
func _on_redo_button_pressed():
	if undo_history.size() > 0:
		var stroke = undo_history.pop_back()
		strokes.append(stroke)
		$VBoxContainer/ButtonsContainer/RedoButton.disabled = undo_history.size() == 0
		$VBoxContainer/ButtonsContainer/UndoButton.disabled = false
		$VBoxContainer/DrawingArea.queue_redraw()

# Clear drawing
func _on_clear_button_pressed():
	strokes = []
	undo_history = []
	$VBoxContainer/ButtonsContainer/UndoButton.disabled = true
	$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
	$VBoxContainer/DrawingArea.queue_redraw()

# Cancel drawing
func _on_cancel_button_pressed():
	print("Cancel button pressed - cancelling whiteboard challenge")
	emit_signal("drawing_cancelled")

# Submit drawing for recognition
func _on_done_button_pressed():
	print("Done button pressed, starting recognition process")
	
	# Check if there's anything drawn
	if strokes.size() == 0:
		_show_status_message("Please write something first", Color(1, 0.3, 0.3, 1))
		await get_tree().create_timer(2.0).timeout
		_hide_status_message()
		return
	
	# Disable buttons during recognition
	$VBoxContainer/ButtonsContainer/DoneButton.disabled = true
	$VBoxContainer/ButtonsContainer/CancelButton.disabled = true
	$VBoxContainer/ButtonsContainer/ClearButton.disabled = true
	$VBoxContainer/ButtonsContainer/UndoButton.disabled = true
	$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
	
	# Show recognition status
	_show_status_message("Processing...")
	
	# Start recognition process
	export_and_recognize_drawing()

# Consolidated function to export drawing and send it for recognition
func export_and_recognize_drawing():
	if recognition_in_progress:
		print("Recognition already in progress")
		return
		
	recognition_in_progress = true
	_show_status_message("Analyzing your handwriting...")
	
	# Create a viewport to render the drawing
	export_viewport = SubViewport.new()
	export_viewport.size = $VBoxContainer/DrawingArea.size
	export_viewport.transparent_bg = true
	export_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Create a control to draw the strokes on
	var draw_control = Control.new()
	draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Add draw function to the control
	draw_control.draw.connect(func():
		# Clear the background with white
		draw_control.draw_rect(Rect2(Vector2(0, 0), export_viewport.size), Color(1, 1, 1, 1))
		
		# Draw all strokes
		for stroke in strokes:
			if stroke.points.size() < 2:
				continue
			
			for i in range(1, stroke.points.size()):
				var from = stroke.points[i - 1]
				var to = stroke.points[i]
				draw_control.draw_line(from, to, stroke.color, stroke.width * 2) # Thicker for better recognition
	)
	
	# Add the control to the viewport
	export_viewport.add_child(draw_control)
	add_child(export_viewport)
	
	# Wait for rendering to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get the image
	var img = export_viewport.get_texture().get_image()
	
	# Resize if necessary for better OCR
	if img.get_width() > 1000 or img.get_height() > 1000:
		var max_dim = 1000
		var resize_factor = min(max_dim / float(img.get_width()),
							   max_dim / float(img.get_height()))
		var new_width = int(img.get_width() * resize_factor)
		var new_height = int(img.get_height() * resize_factor)
		img.resize(new_width, new_height)
	
	# Save as PNG
	var img_data = img.save_png_to_buffer()
	
	# Convert to base64 for the Vision API
	var base64_img = Marshalls.raw_to_base64(img_data)
	
	# Add extra debug info
	print("Exported drawing image size: " + str(img_data.size()) + " bytes")
	
	# Clean up viewport
	export_viewport.queue_free()
	export_viewport = null
	
	# Process based on platform
	if OS.has_feature("web"):
		print("Web platform detected - using JavaScript bridge")
		process_image_with_javascript(base64_img, img.get_width(), img.get_height())
	else:
		print("Desktop/mobile platform - using native API")
		process_image_with_native_api(base64_img)

# Web platform implementation
func process_image_with_javascript(base64_img, width, height):
	if JavaScriptBridge.has_method("eval"):
		debug_log("Starting OCR process with JavaScript")
		
		# Create a completely different approach using polling for Promise resolution
		# This avoids the issue with direct Promise returns that aren't properly handled
		var unique_callback_id = str(randi())
		
		# Step 1: Create a global variable to store the result
		var setup_js = """
			(function() {
				window.godot_ocr_results = window.godot_ocr_results || {};
				window.godot_ocr_results['%s'] = { status: 'pending', result: null };
				
				// Create function to process the image and store result
				window.processImageAndStore = async function(id, base64data, imgWidth, imgHeight) {
					try {
						console.log('Processing image with ID: ' + id);
						const result = await window.godotProcessImageVision(base64data, imgWidth, imgHeight);
						window.godot_ocr_results[id] = { status: 'completed', result: result };
						console.log('Processing complete for ID: ' + id + ' with result: ' + result);
					} catch(e) {
						console.error('Error in image processing:', e);
						window.godot_ocr_results[id] = { status: 'error', result: 'error:' + e.message };
					}
				};
				
				// Start processing
				window.processImageAndStore('%s', '%s', %d, %d);
				return true;
			})();
		""" % [unique_callback_id, unique_callback_id, base64_img, width, height]
		
		# Execute setup and start processing
		JavaScriptBridge.eval(setup_js)
		
		# Start polling for results
		print("Starting polling for OCR results with ID: " + unique_callback_id)
		
		# Set up max retries and delay between checks
		var max_retries = 30 # 30 x 200ms = 6 seconds max wait time
		var retry_count = 0
		
		while retry_count < max_retries:
			# Wait a bit before checking
			await get_tree().create_timer(0.2).timeout
			retry_count += 1
			
			# Check result status
			var check_js = """
				(function() {
					if (window.godot_ocr_results && window.godot_ocr_results['%s']) {
						return JSON.stringify(window.godot_ocr_results['%s']);
					} else {
						return JSON.stringify({status: 'missing'});
					}
				})();
			""" % [unique_callback_id, unique_callback_id]
			
			var result_json = JavaScriptBridge.eval(check_js)
			var json = JSON.new()
			var error = json.parse(result_json)
			
			if error == OK:
				var result_data = json.data
				
				if result_data.status == "completed":
					print("OCR processing completed with result: " + str(result_data.result))
					
					# Clean up the result entry
					JavaScriptBridge.eval("""
						(function() { 
							delete window.godot_ocr_results['%s']; 
						})();
					""" % unique_callback_id)
					
					if result_data.result:
						_on_recognition_completed(result_data.result)
						return
					else:
						_on_recognition_error("Could not read your handwriting. Please write more clearly.")
						return
				
				elif result_data.status == "error":
					print("OCR processing error: " + str(result_data.result))
					_on_recognition_error("Could not process your handwriting: " + str(result_data.result))
					return
					
				# Otherwise continue polling
				print("Still waiting for OCR result (attempt " + str(retry_count) + ")")
			
		# If we got here, we timed out
		print("Timed out waiting for OCR result")
		_on_recognition_error("Request timed out")
	else:
		print("JavaScriptBridge not available")
		_on_recognition_error("JavaScript bridge unavailable")

# Native platform implementation
func process_image_with_native_api(base64_img):
	print("Using native implementation for OCR")
	
	if google_cloud_vision:
		var result = google_cloud_vision.recognize_handwriting(base64_img)
		if !result:
			print("Failed to start recognition process")
			_on_recognition_error("Failed to start recognition")
	else:
		print("GoogleCloudVision class not available")
		_on_recognition_error("Vision API not available")

# Function to handle successful text recognition
func _on_recognition_completed(text_result: String):
	# Display the recognition result
	print("Recognition completed: ", text_result)
	debug_log("Recognition result: " + text_result)
	
	# Emit signal with recognized text
	emit_signal("drawing_submitted", text_result)
	
	# Update status display
	if status_label:
		status_label.visible = true
		status_label.text = "Processing result..."

# Function to handle recognition errors
func _on_recognition_error(error_msg: String):
	print("Recognition error: " + error_msg)
	debug_log("Recognition error: " + error_msg)
	
	# Humanize error messages for better user experience
	var user_friendly_msg = "recognition_error"
	if "Failed to start recognition" in error_msg:
		user_friendly_msg = "Could not analyze your handwriting. Please try again."
	elif "Vision API not available" in error_msg:
		user_friendly_msg = "Handwriting recognition is temporarily unavailable."
	elif "Request timed out" in error_msg:
		user_friendly_msg = "Analysis is taking too long. Please try again."
	elif "Empty result received" in error_msg:
		user_friendly_msg = "Could not read your handwriting. Please write more clearly."
	elif "JavaScript bridge unavailable" in error_msg:
		user_friendly_msg = "System error. Please refresh the page."
	else:
		user_friendly_msg = "Unable to read your handwriting. Please try writing again."
	
	emit_signal("drawing_submitted", user_friendly_msg)
	
	# Update status display
	if status_label:
		status_label.visible = true
		status_label.text = "Processing result..."

# Helper function to hide UI elements
func hide_ui_elements():
	for child in get_children():
		if child is VBoxContainer:
			child.visible = false
	
	# Keep status label visible
	if status_label:
		status_label.visible = true

# Test JavaScript bridge functions
func test_javascript_bridge():
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("typeof window.testJavaScriptBridge === 'function' ? window.testJavaScriptBridge() : 'function not found'")
		print("JavaScript bridge test result: " + str(result))
		
		# Test debug log
		debug_log("Whiteboard interface initialized")
		
		# Test Vision API
		JavaScriptBridge.eval("window.testVisionAPI()")
	else:
		print("Not running on web platform, skipping JavaScript bridge test")

# Consistent debug logging helper
func debug_log(message):
	print(message)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function() {
				if (typeof window.debugLog === 'function') {
					window.debugLog(""" + JSON.stringify(message) + """);
				} else {
					console.log(""" + JSON.stringify(message) + """);
				}
			})();
		""")

# Setup drawing system
func setup_drawing():
	# Connect drawing area signals
	if $VBoxContainer/DrawingArea:
		$VBoxContainer/DrawingArea.draw.connect(_on_drawing_area_draw)
	
	# Initialize drawing variables
	drawing = false
	points = []
	strokes = []
	undo_history = []
	
	# Set default drawing parameters
	stroke_color = Color(0, 0, 0)
	stroke_width = 2.0
	current_stroke = null
	
	debug_log("Drawing system initialized")

# UI status messages
func _show_status_message(text, color = Color(1, 1, 1, 1)):
	status_label.text = text
	status_label.modulate = color
	
	# Animate in
	var tween = create_tween()
	tween.tween_property(status_label, "modulate:a", 1.0, 0.3)

func _hide_status_message():
	var tween = create_tween()
	tween.tween_property(status_label, "modulate:a", 0.0, 0.3)
