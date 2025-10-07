extends Control

# Add the preload for GoogleCloudVision.gd to resolve the error
const GoogleCloudVision = preload("res://Scripts/GoogleCloudVision.gd")

# Add signals for drawing events
signal drawing_submitted(text_result)
signal drawing_cancelled

# Module mode property to hide cancel button in module learning
@export var module_mode: bool = false

# Drawing variables
var drawing = false
var points = []
var strokes = []
var undo_history = []
var stroke_color = Color(0, 0, 0)
var stroke_width = 5.0 # Default for battle mode
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
	
	# Hide cancel button in module mode (not journey/battle mode)
	if module_mode:
		$VBoxContainer/ButtonsContainer/CancelButton.visible = false
	
	# Set DrawingArea z_index to render strokes on top of TraceOverlay and guide arrows
	# This allows handwritten strokes to appear above the letter guide without moving nodes
	# $VBoxContainer/DrawingArea.z_index = 100
	
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

	# Add debug label for development - FIXED: Prevent duplicate creation
	if OS.is_debug_build():
		if not has_node("DebugLabel"):
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
			debug.text = "Write in this whiteboard!"
			add_child(debug)
			debug_label = debug
		else:
			debug_label = $DebugLabel
	else:
		# Not in debug build, ensure debug_label is null
		debug_label = null
		
	# Connect to drawing functions to manage debug label visibility
	if debug_label:
		# Show label when drawing is cleared
		$VBoxContainer/ButtonsContainer/ClearButton.pressed.connect(func(): debug_label.visible = true)
	
	# Initialize drawing system
	setup_drawing()
	debug_log("WhiteboardInterface ready")
	
	# Add mouse exit handler to drawing area for better state management
	if $VBoxContainer/DrawingArea.has_signal("mouse_exited"):
		$VBoxContainer/DrawingArea.mouse_exited.connect(_on_drawing_area_mouse_exited)
	
	# Set adaptive stroke width based on module mode
	_setup_stroke_width()
	
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
					# Ensure dot strokes render right after click release
					$VBoxContainer/DrawingArea.queue_redraw()
			else:
				# If mouse is released outside drawing area, end stroke to prevent corruption
				if not event.pressed and drawing:
					_end_stroke()
	
	elif event is InputEventMouseMotion:
		if drawing:
			var draw_area_rect = $VBoxContainer/DrawingArea.get_global_rect()
			
			if draw_area_rect.has_point(event.position):
				_add_point_to_stroke(event.position - $VBoxContainer/DrawingArea.global_position)
				$VBoxContainer/DrawingArea.queue_redraw()
			else:
				# If mouse leaves drawing area while drawing, end stroke to prevent corruption
				_end_stroke()

# Start a new stroke
func _start_stroke(pposition):
	drawing = true
	current_stroke = {
		"points": [pposition],
		"color": stroke_color,
		"width": stroke_width
	}
	
	# Play a short clip of whiteboard swiping sound (0.5 seconds from the 2-minute file)
	var swiping_audio = $WhiteboardSwiping
	if swiping_audio and swiping_audio.stream:
		# Stop any currently playing audio
		swiping_audio.stop()
		# Play for a short duration - will be stopped after 0.5 seconds
		swiping_audio.play()
		# Create a timer to stop the audio after 0.5 seconds for a short swiping effect
		get_tree().create_timer(0.5).timeout.connect(func():
			if swiping_audio.playing:
				swiping_audio.stop()
		)
	
	# Hide debug label when drawing starts
	if debug_label:
		debug_label.visible = false

# Add point to current stroke with smoothing
func _add_point_to_stroke(pposition):
	if current_stroke:
		# Add distance-based filtering to reduce noise and improve performance
		var stroke_points = current_stroke.points
		if stroke_points.size() == 0:
			stroke_points.append(pposition)
		else:
			var last_point = stroke_points[stroke_points.size() - 1]
			var distance = last_point.distance_to(pposition)
			
			# Only add point if it's far enough from the last point (reduces jitter)
			var min_distance = 3.0 if module_mode else 2.0 # Slightly more filtering for tracing
			if distance >= min_distance:
				stroke_points.append(pposition)

# End current stroke
func _end_stroke():
	drawing = false
	if current_stroke:
		strokes.append(current_stroke)
		undo_history = []
		$VBoxContainer/ButtonsContainer/UndoButton.disabled = false
		$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
		current_stroke = null
		# Force redraw so single-point (dot) strokes appear immediately
		$VBoxContainer/DrawingArea.queue_redraw()

# Handle mouse exiting drawing area to prevent drawing state corruption
func _on_drawing_area_mouse_exited():
	if drawing:
		debug_log("Mouse exited drawing area while drawing - ending stroke to prevent corruption")
		_end_stroke()

# Draw the strokes
func _on_drawing_area_draw():
	# Draw all completed strokes
	for stroke in strokes:
		_draw_stroke(stroke)
	
	# Draw current stroke
	if current_stroke:
		_draw_stroke(current_stroke)

# Helper function to draw a stroke with improved smoothness
func _draw_stroke(stroke):
	if stroke.points.size() == 0:
		return
	
	# Handle single-point strokes as dots/circles
	if stroke.points.size() == 1:
		var point = stroke.points[0]
		$VBoxContainer/DrawingArea.draw_circle(point, stroke.width / 2.0, stroke.color)
		return
		
	var points_array = []
	for point in stroke.points:
		points_array.append(point)
	
	# Enhanced smooth drawing with anti-aliasing and better stroke rendering
	for i in range(1, points_array.size()):
		var from = points_array[i - 1]
		var to = points_array[i]
		
		# Use anti-aliased lines with rounded caps for smoother appearance
		$VBoxContainer/DrawingArea.draw_line(from, to, stroke.color, stroke.width, true)
		
		# Add smooth overlapping circles for better stroke continuity
		var circle_radius = stroke.width / 2.0
		$VBoxContainer/DrawingArea.draw_circle(from, circle_radius, stroke.color)
		if i == points_array.size() - 1: # Last point
			$VBoxContainer/DrawingArea.draw_circle(to, circle_radius, stroke.color)
		
		# Add intermediate circles for very smooth strokes on longer segments
		var distance = from.distance_to(to)
		if distance > stroke.width * 0.5:
			var steps = int(distance / (stroke.width * 0.3))
			for step in range(1, steps):
				var t = float(step) / float(steps)
				var intermediate_point = from.lerp(to, t)
				$VBoxContainer/DrawingArea.draw_circle(intermediate_point, circle_radius * 0.8, stroke.color)

# Undo last stroke
func _on_undo_button_pressed():
	$ButtonClick.play()
	if strokes.size() > 0:
		var last_stroke = strokes.pop_back()
		undo_history.append(last_stroke)
		$VBoxContainer/ButtonsContainer/RedoButton.disabled = false
		$VBoxContainer/ButtonsContainer/UndoButton.disabled = strokes.size() == 0
		$VBoxContainer/DrawingArea.queue_redraw()
		
		# Show debug label when whiteboard is completely cleared through undo
		if strokes.size() == 0 and debug_label:
			debug_label.visible = true
			debug_label.text = "Write in this whiteboard!"

# Redo last undone stroke
func _on_redo_button_pressed():
	$ButtonClick.play()
	if undo_history.size() > 0:
		var stroke = undo_history.pop_back()
		strokes.append(stroke)
		$VBoxContainer/ButtonsContainer/RedoButton.disabled = undo_history.size() == 0
		$VBoxContainer/ButtonsContainer/UndoButton.disabled = false
		$VBoxContainer/DrawingArea.queue_redraw()
		
		# Hide debug label when redoing (adding content back)
		if debug_label:
			debug_label.visible = false
	else:
		# No redo available; ensure redraw reflects current state (e.g., after sequence of undos)
		$VBoxContainer/DrawingArea.queue_redraw()

# Clear drawing
func _on_clear_button_pressed():
	$ButtonClick.play()
	strokes = []
	undo_history = []
	$VBoxContainer/ButtonsContainer/UndoButton.disabled = true
	$VBoxContainer/ButtonsContainer/RedoButton.disabled = true
	$VBoxContainer/DrawingArea.queue_redraw()
	
	# Show debug label again when cleared
	if debug_label:
		debug_label.visible = true
		debug_label.text = "Write in this whiteboard!"

# Re-enable buttons (helper function for when user starts drawing again)
func _re_enable_buttons():
	$VBoxContainer/ButtonsContainer/DoneButton.disabled = false
	$VBoxContainer/ButtonsContainer/CancelButton.disabled = false
	$VBoxContainer/ButtonsContainer/ClearButton.disabled = false
	# Undo/Redo buttons are handled by their respective logic

# Cancel drawing
func _on_cancel_button_pressed():
	$ButtonClick.play()
	print("Cancel button pressed - cancelling whiteboard challenge")
	emit_signal("drawing_cancelled")

# Submit drawing for recognition
func _on_done_button_pressed():
	$ButtonClick.play()
	print("Done button pressed, checking if anything is drawn")
	
	# Check if there's anything drawn - improved detection
	if strokes.size() == 0:
		print("No strokes detected - whiteboard is empty")
		
		# Show user-friendly message and bring back debug label
		_show_status_message("Please write the word first!", Color(1, 0.3, 0.3, 1))
		
		# Show debug label again to guide user
		if debug_label:
			debug_label.visible = true
			debug_label.text = "You haven't written anything yet..."
		
		# Hide status message after some time but don't proceed with challenge
		await get_tree().create_timer(3.0).timeout
		_hide_status_message()
		
		# Do NOT emit any signal or proceed with challenge - just return
		return
	
	print("Strokes detected: " + str(strokes.size()) + " - starting recognition process")
	
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
						_on_recognition_error("Could not read.")
						return
				
				elif result_data.status == "error":
					print("OCR processing error: " + str(result_data.result))
					_on_recognition_error("Could not process: " + str(result_data.result))
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
	
	# Reset recognition state
	recognition_in_progress = false
	
	# Re-enable buttons after recognition
	_re_enable_buttons()
	
	# Emit signal with recognized text
	emit_signal("drawing_submitted", text_result)

# Function to handle recognition errors
func _on_recognition_error(error_msg: String):
	print("Recognition error: " + error_msg)
	debug_log("Recognition error: " + error_msg)
	
	# Reset recognition state
	recognition_in_progress = false
	
	# Re-enable buttons so user can try again
	_re_enable_buttons()
	
	# Humanize error messages for better user experience
	var user_friendly_msg = "recognition_error"
	if "Failed to start recognition" in error_msg:
		user_friendly_msg = "Not Recognized"
		_show_status_message("Could not analyze your writing. Please try again.", Color(1, 0.3, 0.3, 1))
	elif "Vision API not available" in error_msg:
		user_friendly_msg = "Unavailable"
		_show_status_message("Recognition service unavailable. Please try again later.", Color(1, 0.3, 0.3, 1))
	elif "Request timed out" in error_msg:
		user_friendly_msg = "Too long"
		_show_status_message("Analysis timed out. Please try again.", Color(1, 0.3, 0.3, 1))
	elif "Empty result received" in error_msg:
		user_friendly_msg = "Couldn't read"
		_show_status_message("Could not read your writing. Please try writing more clearly.", Color(1, 0.3, 0.3, 1))
	elif "JavaScript bridge unavailable" in error_msg:
		user_friendly_msg = "System error"
		_show_status_message("System error. Please try again.", Color(1, 0.3, 0.3, 1))
	else:
		user_friendly_msg = "Unable"
		_show_status_message("Unable to read your writing. Please try again.", Color(1, 0.3, 0.3, 1))

	# Hide status message after some time
	await get_tree().create_timer(3.0).timeout
	_hide_status_message()
	
	# Emit the error signal (this will be handled by the challenge system)
	emit_signal("drawing_submitted", user_friendly_msg)

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
# Setup drawing system
func setup_drawing():
	# Connect drawing area signals only if not already connected
	if $VBoxContainer/DrawingArea and not $VBoxContainer/DrawingArea.draw.is_connected(_on_drawing_area_draw):
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

# Setup adaptive stroke width based on module mode
func _setup_stroke_width():
	if module_mode:
		# In module mode (letter/word tracing), use thicker stroke for better visibility and smoother rendering
		stroke_width = 8.0 # Reduced for smoother curves while maintaining visibility
		debug_log("Module mode: Using optimized stroke width for letter tracing")
	else:
		# In battle mode, use moderate stroke width for general word writing
		stroke_width = 4.0 # Slightly reduced for smoother rendering
		debug_log("Battle mode: Using optimized stroke width for word challenges")

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


func _on_undo_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_redo_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_clear_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_cancel_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_done_button_mouse_entered() -> void:
	$ButtonHover.play()

# Public helper: prepare the board for another attempt (called after celebration Try Again)
func reset_for_retry():
	print("[Whiteboard] reset_for_retry called")
	strokes.clear()
	undo_history.clear()
	current_stroke = null
	recognition_in_progress = false
	$VBoxContainer/DrawingArea.queue_redraw()
	_re_enable_buttons()
	if debug_label:
		debug_label.visible = true
		debug_label.text = "Write in this whiteboard!"
	# Hide any transient status
	if status_label:
		status_label.visible = false
