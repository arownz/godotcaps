extends Control

var tts: TextToSpeech = null
var module_progress = null
var whiteboard_instance: Control = null
var notification_popup: CanvasLayer = null
var completion_celebration: CanvasLayer = null

var current_target: String = "A"
var letter_set := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
var letter_index := 0
var session_completed_letters: Array = [] # Fallback local tracking when Firebase/module_progress unavailable
var fade_trace_on_success := true
var letter_focus_mode := false # Dims non-essential UI for reduced visual load
var recent_errors: Array = [] # Track recently missed letters for adaptive revisit

# Guided tracing system variables
var guided_arrows: Array = [] # Array of CurvedArrow2D nodes for multi-stroke letters
var guided_labels: Array = [] # Array of Label nodes for step numbers
var guide_animation_tween: Tween = null
var is_guide_playing := false
var guide_container: Control = null # Container for arrow overlays

func _speak_text_simple(text: String):
	"""Simple TTS without captions"""
	if tts:
		tts.speak(text)

func _ready():
	print("PhonicsLetters: Letters practice loaded")
	
	# Enhanced fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Initialize helpers
	_init_tts()
	_init_module_progress()
	
	# Initialize guided tracing system
	_init_guide_container()
	
	# Connect hover events
	_connect_hover_events()
	
	# Update initial display
	_update_target_display()
	
	# Load whiteboard
	_load_whiteboard()
	
	# Load progress
	call_deferred("_load_progress")

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Refresh progress when window gains focus
		call_deferred("_load_progress")

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	
	# Load TTS settings for dyslexia-friendly reading
	var voice_id = SettingsManager.get_setting("accessibility", "tts_voice_id")
	var rate = SettingsManager.get_setting("accessibility", "tts_rate")
	
	if voice_id != null and voice_id != "":
		tts.set_voice(voice_id)
	if rate != null:
		tts.set_rate(rate)
		
func _init_module_progress():
	if Firebase and Firebase.Auth and Firebase.Auth.auth:
		module_progress = ModuleProgress.new()
		print("PhonicsLetters: ModuleProgress initialized")
	else:
		print("PhonicsLetters: Firebase not available, usin	g local tracking")

func _init_guide_container():
	"""Initialize the container for guided tracing arrows"""
	print("PhonicsLetters: Initializing guided tracing system")
	
	# Create a control container for arrows above the TraceOverlay
	guide_container = Control.new()
	guide_container.name = "GuideContainer"
	guide_container.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block input
	
	# Add to whiteboard container, above TraceOverlay
	var whiteboard_container = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer
	if whiteboard_container:
		whiteboard_container.add_child(guide_container)
		# Move to top of z-order
		whiteboard_container.move_child(guide_container, whiteboard_container.get_child_count() - 1)
		
		# Set to fill parent
		guide_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		print("PhonicsLetters: Guide container created and positioned")
	else:
		print("PhonicsLetters: ERROR - Whiteboard container not found")

func _connect_hover_events():
	var back_btn = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton
	if back_btn and not back_btn.mouse_entered.is_connected(_on_button_hover):
		back_btn.mouse_entered.connect(_on_button_hover)
	
	# Connect guide button
	var guide_btn = $MainContainer/ContentContainer/InstructionPanel/GuideButton
	if guide_btn:
		if not guide_btn.mouse_entered.is_connected(_on_button_hover):
			guide_btn.mouse_entered.connect(_on_button_hover)
		if not guide_btn.pressed.is_connected(_on_guide_button_pressed):
			guide_btn.pressed.connect(_on_guide_button_pressed)
	
	# Connect TTS settings button
	var tts_btn = $MainContainer/ContentContainer/InstructionPanel/TTSSettingButton
	if tts_btn:
		if not tts_btn.mouse_entered.is_connected(_on_button_hover):
			tts_btn.mouse_entered.connect(_on_button_hover)
		if not tts_btn.pressed.is_connected(_on_tts_setting_button_pressed):
			tts_btn.pressed.connect(_on_tts_setting_button_pressed)
	
	# Connect Previous button
	var previous_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton
	if previous_btn:
		if not previous_btn.mouse_entered.is_connected(_on_button_hover):
			previous_btn.mouse_entered.connect(_on_button_hover)
		if not previous_btn.pressed.is_connected(_on_previous_button_pressed):
			previous_btn.pressed.connect(_on_previous_button_pressed)
	
	# Connect Next button
	var next_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	if next_btn:
		if not next_btn.mouse_entered.is_connected(_on_button_hover):
			next_btn.mouse_entered.connect(_on_button_hover)
		if not next_btn.pressed.is_connected(_on_NextButton_pressed):
			next_btn.pressed.connect(_on_NextButton_pressed)

func _update_target_display():
	var target_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
	if target_label:
		target_label.text = "Trace: " + current_target
	
	# Update trace overlay
	var trace_overlay = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay:
		trace_overlay.text = current_target
	
	# Update button visibility
	_update_button_visibility()

	# Reset trace overlay opacity when showing new target (unless already completed)
	var trace_overlay_node = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay_node:
		# Check if current letter is completed and adjust opacity
		if current_target in session_completed_letters:
			trace_overlay_node.modulate.a = 0.3 # Semi-transparent for completed
		else:
			trace_overlay_node.modulate.a = 1.0 # Full opacity for uncompleted

func _update_button_visibility():
	var previous_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/PreviousButton
	var next_btn = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/NextButton
	
	if previous_btn:
		previous_btn.visible = (letter_index > 0)
	if next_btn:
		next_btn.visible = (letter_index < letter_set.size() - 1)

# ============================================================================
# GUIDED TRACING SYSTEM
# ============================================================================

func play_guided_trace(letter: String):
	"""
	Play animated stroke guidance for the specified letter.
	Strokes are animated with looping arrows showing proper letter formation.
	Accessible for dyslexic users with smooth, clear motion.
	"""
	print("PhonicsLetters: Starting guided trace for letter: ", letter)
	
	# Stop any existing animation
	stop_guided_trace()
	
	if not guide_container:
		print("PhonicsLetters: ERROR - Guide container not initialized")
		return
	
	# Get stroke paths for the letter
	var strokes = _get_letter_strokes(letter)
	if strokes.is_empty():
		print("PhonicsLetters: No stroke data for letter: ", letter)
		return
	
	is_guide_playing = true
	
	# Create arrow for each stroke with numbered labels
	for i in range(strokes.size()):
		var stroke = strokes[i]
		var arrow = CurvedArrow2D.new()
		arrow.name = "GuideArrow_" + str(i)
		
		# Position arrow at stroke start
		arrow.position = stroke.start
		arrow.global_end_position = guide_container.global_position + stroke.end
		
		# Dyslexia-friendly styling
		arrow.color = Color(1.0, 0.9, 0.2, 0.85) # Yellow (dyslexia-friendly)
		arrow.transparency = 0.85
		arrow.width = 8.0 # Visible but not overwhelming
		arrow.arrowhead_height = 20.0
		arrow.arrowhead_width = 24.0
		arrow.curve_height_factor = stroke.get("curve", 0.3) # Slight curve for natural feel
		arrow.outline_thickness = 2
		arrow.outline_color = Color(1.0, 1.0, 1.0, 0.9)
		
		# Set initial animation progress to 0
		arrow.animation_progress = 0.0
		
		guide_container.add_child(arrow)
		guided_arrows.append(arrow)
		
		# Add numbered step label at stroke start
		var step_label = Label.new()
		step_label.name = "StepLabel_" + str(i)
		step_label.text = str(i + 1) # 1-indexed for user
		step_label.add_theme_font_size_override("font_size", 24)
		step_label.add_theme_color_override("font_color", Color(0, 0, 0, 1)) # Black text
		step_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1)) # White outline
		step_label.add_theme_constant_override("outline_size", 3)
		
		# Position label slightly offset from stroke start (top-left)
		step_label.position = stroke.start - Vector2(20, 25)
		step_label.z_index = 10 # Above arrows
		
		guide_container.add_child(step_label)
		guided_labels.append(step_label) # Track separately from arrows
	
	# Start looping animation
	_animate_guide_strokes()

func stop_guided_trace():
	"""
	Stop and clear all guided tracing animations.
	"""
	print("PhonicsLetters: Stopping guided trace")
	
	is_guide_playing = false
	
	# Kill existing tween
	if guide_animation_tween:
		guide_animation_tween.kill()
		guide_animation_tween = null
	
	# Remove all arrow nodes
	for arrow in guided_arrows:
		if is_instance_valid(arrow):
			arrow.queue_free()
	guided_arrows.clear()
	
	# Remove all label nodes
	for label in guided_labels:
		if is_instance_valid(label):
			label.queue_free()
	guided_labels.clear()

func _animate_guide_strokes():
	"""
	Animate all stroke arrows in sequence with looping.
	Uses dyslexia-friendly pacing: smooth, predictable, not too fast.
	Clear arrows between loops for visual clarity.
	"""
	if not is_guide_playing or guided_arrows.is_empty():
		return
	
	# Create tween for animation
	guide_animation_tween = create_tween()
	
	# Animate each stroke in sequence (only arrows, not labels)
	for i in range(guided_arrows.size()):
		var arrow = guided_arrows[i]
		if not is_instance_valid(arrow):
			continue
		
		# Dyslexia-friendly timing: 1.2 seconds per stroke (not too fast)
		var stroke_duration = 1.2
		
		# Animate from 0 to 1 (full stroke)
		guide_animation_tween.tween_property(arrow, "animation_progress", 1.0, stroke_duration).from(0.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		
		# Small pause at end of stroke (0.3s) for clarity
		guide_animation_tween.tween_property(arrow, "animation_progress", 1.0, 0.3)
	
	# Brief pause before fade-out (0.5s)
	guide_animation_tween.tween_callback(func(): pass ).set_delay(0.5)
	
	# Fade out all arrows and labels for visual clarity
	for arrow in guided_arrows:
		if is_instance_valid(arrow):
			guide_animation_tween.tween_property(arrow, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT)
	
	for label in guided_labels:
		if is_instance_valid(label):
			guide_animation_tween.tween_property(label, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT)
	
	# Clear arrows and prepare for next loop
	guide_animation_tween.tween_callback(func():
		# Clean up current arrows and labels
		for arrow in guided_arrows:
			if is_instance_valid(arrow):
				arrow.queue_free()
		guided_arrows.clear()
		
		for label in guided_labels:
			if is_instance_valid(label):
				label.queue_free()
		guided_labels.clear()
		
		# Brief pause before recreating (0.3s)
		await get_tree().create_timer(0.3).timeout
		
		# Check if guide is still active
		if not is_guide_playing:
			return
		
		# Recreate arrows for next loop
		var current_letter = letter_set[letter_index].to_upper()
		var strokes = _get_letter_strokes(current_letter)
		if strokes.is_empty():
			return
		
		# Recreate arrows using the transformed stroke data
		for i in range(strokes.size()):
			var stroke = strokes[i]
			var arrow = CurvedArrow2D.new()
			arrow.name = "GuideArrow_" + str(i)
			
			# Position arrow using transformed coordinates from _get_letter_strokes
			arrow.position = stroke.start
			arrow.global_end_position = guide_container.global_position + stroke.end
			
			# Dyslexia-friendly styling
			arrow.color = Color(1.0, 0.9, 0.2, 0.85) # Yellow (dyslexia-friendly)
			arrow.transparency = 0.85
			arrow.width = 8.0
			arrow.arrowhead_height = 20.0
			arrow.arrowhead_width = 24.0
			arrow.curve_height_factor = stroke.get("curve", 0.3)
			arrow.outline_thickness = 2
			arrow.outline_color = Color(1.0, 1.0, 1.0, 0.9)
			arrow.animation_progress = 0.0
			arrow.modulate.a = 0.0 # Start invisible for fade-in
			
			guide_container.add_child(arrow)
			guided_arrows.append(arrow)
			
			# Recreate numbered step label
			var step_label = Label.new()
			step_label.name = "StepLabel_" + str(i)
			step_label.text = str(i + 1) # 1-indexed for user
			step_label.add_theme_font_size_override("font_size", 24)
			step_label.add_theme_color_override("font_color", Color(0, 0, 0, 1)) # Black text
			step_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1)) # White outline
			step_label.add_theme_constant_override("outline_size", 3)
			
			# Position label slightly offset from stroke start
			step_label.position = stroke.start - Vector2(20, 25)
			step_label.z_index = 10 # Above arrows
			step_label.modulate.a = 0.0 # Start invisible for fade-in
			
			guide_container.add_child(step_label)
			guided_labels.append(step_label) # Track separately
		
		# Fade in new arrows and labels
		var fade_tween = create_tween()
		for arrow in guided_arrows:
			if is_instance_valid(arrow):
				fade_tween.tween_property(arrow, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)
		
		for label in guided_labels:
			if is_instance_valid(label):
				fade_tween.tween_property(label, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)
		
		# Wait for fade-in to complete, then start next loop
		await fade_tween.finished
		if is_guide_playing:
			_animate_guide_strokes()
	)
	
	print("PhonicsLetters: Guide animation started with ", guided_arrows.size(), " strokes")

func _get_letter_strokes(letter: String) -> Array:
	"""
	Returns an array of stroke definitions for the given letter.
	Each stroke is a Dictionary with: {start: Vector2, end: Vector2, curve: float}
	
	Strokes are designed for clarity and match common handwriting order.
	Coordinates are relative to the whiteboard container center.
	Scale matches the TraceOverlay label (font size 90 * scale 1.3210202 ≈ 119px)
	"""
	
	# Get whiteboard container size for relative positioning
	var container = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer
	if not container:
		return []
	
	var center = container.size / 2
	# Match TraceOverlay: font_size=90, scale=1.3210202
	# Effective height ≈ 119px, use 60px as half-height for vertical range
	var scale_factor = 60.0 # Adjusted to match TraceOverlay visual size
	
	# Letter stroke definitions (normalized then scaled)
	var stroke_data = {
		"A": [
			{"start": Vector2(-0.5, 0.8), "end": Vector2(0, -0.8), "curve": 0.0}, # Left diagonal up
			{"start": Vector2(0, -0.8), "end": Vector2(0.5, 0.8), "curve": 0.0}, # Right diagonal down
			{"start": Vector2(-0.25, 0.1), "end": Vector2(0.25, 0.1), "curve": 0.0} # Horizontal bar
		],
		"B": [
			{"start": Vector2(-0.3, -0.8), "end": Vector2(-0.3, 0.8), "curve": 0.0}, # Vertical line
			{"start": Vector2(-0.3, -0.8), "end": Vector2(0.3, -0.4), "curve": 0.8}, # Top curve (increased)
			{"start": Vector2(0.3, -0.4), "end": Vector2(-0.3, 0.0), "curve": 0.8}, # Middle (increased)
			{"start": Vector2(-0.3, 0.0), "end": Vector2(0.4, 0.4), "curve": 0.9}, # Bottom curve (increased)
			{"start": Vector2(0.4, 0.4), "end": Vector2(-0.3, 0.8), "curve": 0.9} # Close bottom (increased)
		],
		"C": [
			{"start": Vector2(0.6, -0.3), "end": Vector2(-0.5, 0.0), "curve": 1.5}, # Top arc (clockwise from right)
			{"start": Vector2(-0.5, 0.0), "end": Vector2(0.6, 0.3), "curve": 1.5} # Bottom arc (complete the C)
		],
		"D": [
			{"start": Vector2(-0.3, -0.8), "end": Vector2(-0.3, 0.8), "curve": 0.0}, # Vertical line
			{"start": Vector2(-0.3, -0.8), "end": Vector2(0.3, 0.0), "curve": 1.0}, # Top curve (increased)
			{"start": Vector2(0.3, 0.0), "end": Vector2(-0.3, 0.8), "curve": 1.0} # Bottom curve (increased)
		],
		"E": [
			{"start": Vector2(0.4, -0.8), "end": Vector2(-0.4, -0.8), "curve": 0.0}, # Top horizontal
			{"start": Vector2(-0.4, -0.8), "end": Vector2(-0.4, 0.8), "curve": 0.0}, # Vertical line
			{"start": Vector2(-0.4, 0.0), "end": Vector2(0.3, 0.0), "curve": 0.0}, # Middle horizontal
			{"start": Vector2(-0.4, 0.8), "end": Vector2(0.4, 0.8), "curve": 0.0} # Bottom horizontal
		],
		"F": [
			{"start": Vector2(-0.4, -0.8), "end": Vector2(-0.4, 0.8), "curve": 0.0}, # Vertical line
			{"start": Vector2(-0.4, -0.8), "end": Vector2(0.4, -0.8), "curve": 0.0}, # Top horizontal
			{"start": Vector2(-0.4, 0.0), "end": Vector2(0.3, 0.0), "curve": 0.0} # Middle horizontal
		],
		"G": [
			{"start": Vector2(0.5, -0.6), "end": Vector2(-0.4, -0.6), "curve": 1.2}, # Top curve
			{"start": Vector2(-0.4, -0.6), "end": Vector2(-0.4, 0.6), "curve": 0.0}, # Left side
			{"start": Vector2(-0.4, 0.6), "end": Vector2(0.5, 0.6), "curve": 1.2}, # Bottom curve
			{"start": Vector2(0.5, 0.6), "end": Vector2(0.5, 0.0), "curve": 0.0}, # Right side up
			{"start": Vector2(0.5, 0.0), "end": Vector2(0.0, 0.0), "curve": 0.0} # Horizontal bar
		],
		"H": [
			{"start": Vector2(-0.4, -0.8), "end": Vector2(-0.4, 0.8), "curve": 0.0}, # Left vertical
			{"start": Vector2(-0.4, 0.0), "end": Vector2(0.4, 0.0), "curve": 0.0}, # Horizontal bar
			{"start": Vector2(0.4, -0.8), "end": Vector2(0.4, 0.8), "curve": 0.0} # Right vertical
		],
		"I": [
			{"start": Vector2(0, -0.8), "end": Vector2(0, 0.8), "curve": 0.0} # Vertical line
		],
		"J": [
			{"start": Vector2(0.3, -0.8), "end": Vector2(0.3, 0.5), "curve": 0.0}, # Vertical line
			{"start": Vector2(0.3, 0.5), "end": Vector2(-0.3, 0.7), "curve": 1.0} # Bottom curve/hook (increased)
		],
		"K": [
			{"start": Vector2(-0.4, -0.8), "end": Vector2(-0.4, 0.8), "curve": 0.0}, # Vertical line
			{"start": Vector2(0.5, -0.8), "end": Vector2(-0.4, 0.0), "curve": 0.0}, # Top diagonal
			{"start": Vector2(-0.4, 0.0), "end": Vector2(0.5, 0.8), "curve": 0.0} # Bottom diagonal
		],
		"L": [
			{"start": Vector2(-0.3, -0.8), "end": Vector2(-0.3, 0.8), "curve": 0.0}, # Vertical line
			{"start": Vector2(-0.3, 0.8), "end": Vector2(0.4, 0.8), "curve": 0.0} # Bottom horizontal
		],
		"M": [
			{"start": Vector2(-0.5, 0.8), "end": Vector2(-0.5, -0.8), "curve": 0.0}, # Left vertical
			{"start": Vector2(-0.5, -0.8), "end": Vector2(0.0, 0.0), "curve": 0.0}, # Left diagonal down
			{"start": Vector2(0.0, 0.0), "end": Vector2(0.5, -0.8), "curve": 0.0}, # Right diagonal up
			{"start": Vector2(0.5, -0.8), "end": Vector2(0.5, 0.8), "curve": 0.0} # Right vertical
		],
		"N": [
			{"start": Vector2(-0.4, 0.8), "end": Vector2(-0.4, -0.8), "curve": 0.0}, # Left vertical
			{"start": Vector2(-0.4, -0.8), "end": Vector2(0.4, 0.8), "curve": 0.0}, # Diagonal
			{"start": Vector2(0.4, 0.8), "end": Vector2(0.4, -0.8), "curve": 0.0} # Right vertical
		],
		"O": [
			{"start": Vector2(0, -0.7), "end": Vector2(-0.55, 0), "curve": 1.8}, # Top-left quarter
			{"start": Vector2(-0.55, 0), "end": Vector2(0, 0.7), "curve": 1.8}, # Bottom-left quarter
			{"start": Vector2(0, 0.7), "end": Vector2(0.55, 0), "curve": 1.8}, # Bottom-right quarter
			{"start": Vector2(0.55, 0), "end": Vector2(0, -0.7), "curve": 1.8} # Top-right quarter (close circle)
		],
		"P": [
			{"start": Vector2(-0.3, 0.8), "end": Vector2(-0.3, -0.8), "curve": 0.0}, # Vertical line
			{"start": Vector2(-0.3, -0.8), "end": Vector2(0.4, -0.4), "curve": 0.9}, # Top curve (increased)
			{"start": Vector2(0.4, -0.4), "end": Vector2(-0.3, 0.0), "curve": 0.9} # Close top loop (increased)
		],
		"Q": [
			{"start": Vector2(0, -0.7), "end": Vector2(-0.55, 0), "curve": 1.8}, # Top-left quarter
			{"start": Vector2(-0.55, 0), "end": Vector2(0, 0.7), "curve": 1.8}, # Bottom-left quarter
			{"start": Vector2(0, 0.7), "end": Vector2(0.55, 0), "curve": 1.8}, # Bottom-right quarter
			{"start": Vector2(0.55, 0), "end": Vector2(0, -0.7), "curve": 1.8}, # Top-right quarter (close circle)
			{"start": Vector2(0.2, 0.4), "end": Vector2(0.65, 0.85), "curve": 0.0} # Tail diagonal
		],
		"R": [
			{"start": Vector2(-0.3, 0.8), "end": Vector2(-0.3, -0.8), "curve": 0.0}, # Vertical line
			{"start": Vector2(-0.3, -0.8), "end": Vector2(0.4, -0.4), "curve": 0.9}, # Top curve (increased)
			{"start": Vector2(0.4, -0.4), "end": Vector2(-0.3, 0.0), "curve": 0.9}, # Close top loop (increased)
			{"start": Vector2(-0.3, 0.0), "end": Vector2(0.4, 0.8), "curve": 0.0} # Leg diagonal
		],
		"S": [
			{"start": Vector2(0.5, -0.5), "end": Vector2(-0.3, -0.2), "curve": 1.6}, # Top curve (right to left-center)
			{"start": Vector2(-0.3, -0.2), "end": Vector2(0.3, 0.2), "curve": 1.4}, # Middle S-curve (left to right)
			{"start": Vector2(0.3, 0.2), "end": Vector2(-0.5, 0.5), "curve": 1.6} # Bottom curve (right to left)
		],
		"T": [
			{"start": Vector2(-0.5, -0.8), "end": Vector2(0.5, -0.8), "curve": 0.0}, # Top horizontal
			{"start": Vector2(0, -0.8), "end": Vector2(0, 0.8), "curve": 0.0} # Vertical line
		],
		"U": [
			{"start": Vector2(-0.45, -0.7), "end": Vector2(-0.45, 0.3), "curve": 0.0}, # Left side down
			{"start": Vector2(-0.45, 0.3), "end": Vector2(0.0, 0.65), "curve": 1.5}, # Bottom-left curve
			{"start": Vector2(0.0, 0.65), "end": Vector2(0.45, 0.3), "curve": 1.5}, # Bottom-right curve
			{"start": Vector2(0.45, 0.3), "end": Vector2(0.45, -0.7), "curve": 0.0} # Right side up
		],
		"V": [
			{"start": Vector2(-0.5, -0.8), "end": Vector2(0.0, 0.8), "curve": 0.0}, # Left diagonal down
			{"start": Vector2(0.0, 0.8), "end": Vector2(0.5, -0.8), "curve": 0.0} # Right diagonal up
		],
		"W": [
			{"start": Vector2(-0.6, -0.8), "end": Vector2(-0.3, 0.8), "curve": 0.0}, # Left diagonal down
			{"start": Vector2(-0.3, 0.8), "end": Vector2(0.0, 0.0), "curve": 0.0}, # Up to middle
			{"start": Vector2(0.0, 0.0), "end": Vector2(0.3, 0.8), "curve": 0.0}, # Down to middle-right
			{"start": Vector2(0.3, 0.8), "end": Vector2(0.6, -0.8), "curve": 0.0} # Right diagonal up
		],
		"X": [
			{"start": Vector2(-0.5, -0.8), "end": Vector2(0.5, 0.8), "curve": 0.0}, # Diagonal top-left to bottom-right
			{"start": Vector2(0.5, -0.8), "end": Vector2(-0.5, 0.8), "curve": 0.0} # Diagonal top-right to bottom-left
		],
		"Y": [
			{"start": Vector2(-0.5, -0.8), "end": Vector2(0.0, 0.0), "curve": 0.0}, # Left diagonal to center
			{"start": Vector2(0.5, -0.8), "end": Vector2(0.0, 0.0), "curve": 0.0}, # Right diagonal to center
			{"start": Vector2(0.0, 0.0), "end": Vector2(0.0, 0.8), "curve": 0.0} # Vertical line down
		],
		"Z": [
			{"start": Vector2(-0.5, -0.8), "end": Vector2(0.5, -0.8), "curve": 0.0}, # Top horizontal
			{"start": Vector2(0.5, -0.8), "end": Vector2(-0.5, 0.8), "curve": 0.0}, # Diagonal
			{"start": Vector2(-0.5, 0.8), "end": Vector2(0.5, 0.8), "curve": 0.0} # Bottom horizontal
		],
	}
	
	var letter_upper = letter.to_upper()
	if not stroke_data.has(letter_upper):
		print("PhonicsLetters: No stroke definition for letter: ", letter_upper)
		return [] # Return empty if letter not defined yet
	
	# Scale and position strokes
	var scaled_strokes = []
	for stroke in stroke_data[letter_upper]:
		var scaled_stroke = {
			"start": center + (stroke.start * scale_factor),
			"end": center + (stroke.end * scale_factor),
			"curve": stroke.get("curve", 0.3)
		}
		scaled_strokes.append(scaled_stroke)
	
	return scaled_strokes

# ============================================================================
# END GUIDED TRACING SYSTEM
# ============================================================================

func _load_whiteboard():
	var whiteboard_interface = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/WhiteboardInterface
	if whiteboard_interface:
		# Connect signals
		if whiteboard_interface.has_signal("drawing_submitted"):
			whiteboard_interface.connect("drawing_submitted", Callable(self, "_on_whiteboard_result"))
		if whiteboard_interface.has_signal("drawing_cancelled"):
			whiteboard_interface.connect("drawing_cancelled", Callable(self, "_on_whiteboard_cancelled"))
		whiteboard_instance = whiteboard_interface
	else:
		print("PhonicsLetters: WhiteboardInterface not found")

func _load_progress():
	if module_progress and module_progress.is_authenticated():
		print("PhonicsLetters: Loading phonics progress via ModuleProgress")
		var phonics_progress = await module_progress.get_phonics_progress()
		if phonics_progress:
			var letters_completed = phonics_progress.get("letters_completed", [])
			var progress_percent = phonics_progress.get("progress", 0)
			var saved_index = phonics_progress.get("current_letter_index", 0)
			
			# Update session tracking
			session_completed_letters = letters_completed.duplicate()
			
			# Resume at saved position OR find first uncompleted letter
			var resume_index = saved_index
			
			# Validate saved index is within bounds
			if saved_index >= letter_set.size():
				resume_index = letter_set.size() - 1
			
			# If saved position letter is already completed, find next uncompleted
			var saved_letter = letter_set[resume_index]
			if letters_completed.has(saved_letter):
				print("PhonicsLetters: Saved letter '", saved_letter, "' already completed, finding next uncompleted")
				for i in range(letter_set.size()):
					var letter = letter_set[i]
					if not letters_completed.has(letter):
						resume_index = i
						break
					elif i == letter_set.size() - 1: # All letters completed
						resume_index = letter_set.size() - 1
			
			# Update current position
			letter_index = resume_index
			current_target = letter_set[letter_index]
			print("PhonicsLetters: Resuming at letter: ", current_target, " (index: ", letter_index, ", saved index was: ", saved_index, ")")
			
			# Auto-stop guide if it's playing (prevents showing wrong letter)
			if is_guide_playing:
				print("PhonicsLetters: Auto-stopping guide due to progress load")
				stop_guided_trace()
				var guide_button = $MainContainer/ContentContainer/InstructionPanel/GuideButton
				if guide_button:
					guide_button.text = "Guide"
			
			# Update UI with loaded progress and current position
			_update_progress_ui(progress_percent)
			_update_target_display()
			
			# Update trace overlay for current letter if completed
			_update_completed_letters_display(letters_completed)
			
			print("PhonicsLetters: Loaded progress - ", letters_completed.size(), "/26 letters completed (", progress_percent, "%)")
		else:
			print("PhonicsLetters: No phonics progress found")
	else:
		print("PhonicsLetters: ModuleProgress not available, using local session progress")

func _update_progress_ui(_percent: float):
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	
	# Calculate letters-specific progress
	var completed_count = session_completed_letters.size()
	var total_letters = letter_set.size()
	var letters_percent = (completed_count / float(total_letters)) * 100.0
	
	if progress_label:
		progress_label.text = str(completed_count) + "/" + str(total_letters) + " Letters"
	if progress_bar:
		progress_bar.value = letters_percent
		print("PhonicsLetters: Progress updated to ", letters_percent, "% (", completed_count, "/", total_letters, ")")
		progress_bar.value = letters_percent

func _update_completed_letters_display(completed_letters: Array):
	"""Update trace overlay opacity to show completed letters as transparent"""
	var trace_overlay = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay and completed_letters.has(current_target):
		# Make completed letters semi-transparent but still visible
		trace_overlay.modulate.a = 0.3
		print("PhonicsLetters: Letter ", current_target, " already completed - showing as transparent")

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("PhonicsLetters: Returning to phonics categories")
	_fade_out_and_change_scene("res://Scenes/PhonicsModule.tscn")

func _fade_out_and_change_scene(scene_path: String):
	# Stop any playing TTS before changing scenes
	_stop_tts()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

# Clean up TTS when leaving scene
func _stop_tts():
	if tts and tts.has_method("stop"):
		tts.stop()
		print("PhonicsLetters: TTS stopped before scene change")

# Ensure TTS cleanup on scene exit
func _exit_tree():
	_stop_tts()
	stop_guided_trace() # Clean up animated arrows

func _on_HearButton_pressed():
	$ButtonClick.play()
	var hear_button = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/HearButton
	
	if hear_button and hear_button.text == "Stop":
		# Stop TTS
		if tts:
			tts.stop()
		# Immediately reset button text
		hear_button.text = "Hear"
		print("PhonicsLetters: TTS stopped by user - button reset")
		return
	
	if tts:
		# Start TTS and change button to Stop
		if hear_button:
			hear_button.text = "Stop"
		
		# Enhanced TTS guide with instructions
		var guide_text = "Listen carefully: Letter " + current_target + ". Now trace this letter on the whiteboard. " + current_target + " sounds like " + _get_letter_sound(current_target) + "."
		_speak_text_simple(guide_text)
		
		# Connect to TTS finished signal to reset button
		if tts.has_signal("utterance_finished"):
			if not tts.utterance_finished.is_connected(_on_hear_tts_finished):
				tts.utterance_finished.connect(_on_hear_tts_finished)
		elif tts.has_signal("finished"):
			if not tts.finished.is_connected(_on_hear_tts_finished):
				tts.finished.connect(_on_hear_tts_finished)

func _on_hear_tts_finished():
	"""Reset hear button when TTS finishes"""
	print("PhonicsLetters: _on_hear_tts_finished called - resetting button")
	var hear_button = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/ControlsContainer/HearButton
	if hear_button:
		hear_button.text = "Hear"
		print("PhonicsLetters: Button text reset to 'Hear'")

func _on_guide_button_pressed():
	$ButtonClick.play()
	var guide_button = $MainContainer/ContentContainer/InstructionPanel/GuideButton
	
	# Toggle between showing/hiding animated guide
	if is_guide_playing:
		# Stop the animated guide
		stop_guided_trace()
		if guide_button:
			guide_button.text = "Guide"
		print("PhonicsLetters: Animated guide stopped by user")
	else:
		# Start the animated guide for current letter
		play_guided_trace(current_target)
		if guide_button:
			guide_button.text = "Stop"
		print("PhonicsLetters: Animated guide started for letter: ", current_target)

func _on_guide_tts_finished():
	"""Reset guide button when TTS finishes (kept for compatibility)"""
	print("PhonicsLetters: _on_guide_tts_finished called - resetting button")
	var guide_button = $MainContainer/ContentContainer/InstructionPanel/GuideButton
	if guide_button:
		guide_button.text = "Guide"
		print("PhonicsLetters: Button text reset to 'Guide'")

func _on_tts_setting_button_pressed():
	"""TTS Settings button - Open settings as popup overlay"""
	$ButtonClick.play()
	print("PhonicsLetters: Settings button pressed")
	
	# Open settings as popup instead of changing scene
	var settings_popup_scene = load("res://Scenes/SettingScene.tscn")
	if settings_popup_scene:
		var popup = settings_popup_scene.instantiate()
		add_child(popup)
		if popup.has_method("set_context"):
			popup.set_context(false) # normal settings; hide battle buttons

# Helper function to provide letter sound guidance
func _get_letter_sound(letter: String) -> String:
	var sounds = {
		"A": "ah", "B": "buh", "C": "kuh", "D": "duh", "E": "eh",
		"F": "fuh", "G": "guh", "H": "huh", "I": "ih", "J": "juh",
		"K": "kuh", "L": "luh", "M": "muh", "N": "nuh", "O": "oh",
		"P": "puh", "Q": "kwuh", "R": "ruh", "S": "sss", "T": "tuh",
		"U": "uh", "V": "vuh", "W": "wuh", "X": "ks", "Y": "yuh", "Z": "zzz"
	}
	return sounds.get(letter, letter.to_lower())

func _on_NextButton_pressed():
	$ButtonClick.play()
	_advance_target()

func _on_previous_button_pressed():
	$ButtonClick.play()
	_previous_target()

func _on_letter_done_button_pressed():
	"""Mark current letter as completed and advance"""
	$ButtonClick.play()
	
	# Mark current letter as completed using ModuleProgress
	if module_progress and module_progress.is_authenticated():
		var success = await module_progress.set_phonics_letter_completed(current_target)
		if success:
			print("PhonicsLetters: Letter ", current_target, " marked as completed in Firebase")
			session_completed_letters.append(current_target)
			_advance_target()
		else:
			print("PhonicsLetters: Failed to save letter completion to Firebase")
	else:
		print("PhonicsLetters: ModuleProgress not available, using local session tracking")
		session_completed_letters.append(current_target)
		_advance_target()

func _advance_target():
	letter_index = (letter_index + 1) % letter_set.size()
	current_target = letter_set[letter_index]
	
	# Stop guided trace when changing letters
	if is_guide_playing:
		stop_guided_trace()
		var guide_button = $MainContainer/ContentContainer/InstructionPanel/GuideButton
		if guide_button:
			guide_button.text = "Guide"
	
	_update_target_display()
	
	# Clear whiteboard for next target
	if whiteboard_instance and whiteboard_instance.has_method("_on_clear_button_pressed"):
		whiteboard_instance._on_clear_button_pressed()
	
	# Re-enable whiteboard buttons after clearing
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

func _previous_target():
	letter_index = (letter_index - 1 + letter_set.size()) % letter_set.size()
	current_target = letter_set[letter_index]
	
	# Stop guided trace when changing letters
	if is_guide_playing:
		stop_guided_trace()
		var guide_button = $MainContainer/ContentContainer/InstructionPanel/GuideButton
		if guide_button:
			guide_button.text = "Guide"
	
	_update_target_display()
	
	# Clear whiteboard for previous target
	if whiteboard_instance and whiteboard_instance.has_method("_on_clear_button_pressed"):
		whiteboard_instance._on_clear_button_pressed()
	
	# Re-enable whiteboard buttons after clearing
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

func _on_whiteboard_result(text_result: String):
	print("PhonicsLetters: Whiteboard result -> ", text_result)
	
	# Enhanced recognition with letter-specific OCR correction and dyslexia-friendly matching
	var recognized_text = text_result.strip_edges().to_upper()
	var target_letter = current_target.to_upper()
	
	# Apply OCR correction for common letter/digit confusions
	recognized_text = _apply_letter_ocr_correction(recognized_text, target_letter)
	print("PhonicsLetters: After OCR correction -> ", recognized_text)
	
	# Check if recognition matches current target letter
	var is_correct = false
	var confidence_score = 0.0
	
	# CRITICAL FIX: Check for orientation-ambiguous letters FIRST
	# This handles cases where Google Cloud Vision detects rotated/flipped letters
	if _is_orientation_pair(recognized_text, target_letter):
		print("PhonicsLetters: Orientation-ambiguous pair detected (", recognized_text, " vs ", target_letter, ") -> ACCEPTING as CORRECT")
		is_correct = true
		confidence_score = 1.0
	
	# Direct match gets highest confidence
	if recognized_text == target_letter:
		is_correct = true
		confidence_score = 1.0
	# Letter similarity analysis for single characters
	elif recognized_text.length() == 1 and target_letter.length() == 1:
		confidence_score = _calculate_letter_similarity(recognized_text, target_letter)
		is_correct = confidence_score >= 0.7 # Accept with 70% confidence or higher
	# Multi-character results - extract potential letter
	elif recognized_text.length() > 1:
		var extracted_letter = _extract_target_letter(recognized_text, target_letter)
		if extracted_letter == target_letter:
			is_correct = true
			confidence_score = 0.8
		# Also check if extracted letter is an orientation pair
		elif _is_orientation_pair(extracted_letter, target_letter):
			print("PhonicsLetters: Extracted orientation pair from multi-char (", extracted_letter, " vs ", target_letter, ") -> ACCEPTING")
			is_correct = true
			confidence_score = 1.0
	
	print("PhonicsLetters: Confidence score: ", confidence_score, " | Is correct: ", is_correct)
	
	if is_correct:
		print("PhonicsLetters: Correct letter recognized - ", target_letter)
		# Fade out trace overlay gradually to promote independence
		if fade_trace_on_success:
			var trace_overlay_node2 = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
			if trace_overlay_node2:
				var tween = create_tween()
				tween.tween_property(trace_overlay_node2, "modulate:a", 0.15, 0.6)
		# Track locally for this session
		if not session_completed_letters.has(target_letter):
			session_completed_letters.append(target_letter)
		
		var progress_data: Dictionary = {"letters_completed": session_completed_letters, "percentage": float(session_completed_letters.size()) / 26.0 * 100.0}
		
		# Track whiteboard success for leaderboard analytics
		if module_progress and module_progress.is_authenticated():
			var whiteboard_track_success = await module_progress.track_phonics_whiteboard_attempt(target_letter, true)
			if not whiteboard_track_success:
				print("PhonicsLetters: Failed to track whiteboard success")
		
		# Try to persist progress using ModuleProgress
		if module_progress and module_progress.is_authenticated():
			var save_success = await module_progress.set_phonics_letter_completed(target_letter)
			if save_success:
				print("PhonicsLetters: ModuleProgress update successful")
				# Update progress display
				var phonics_progress = await module_progress.get_phonics_progress()
				if phonics_progress:
					var letters_progress = phonics_progress.get("phonics_letters", {}).get("progress", 0)
					_update_progress_ui(letters_progress)
			else:
				print("PhonicsLetters: ModuleProgress update failed, using session progress fallback")
		else:
			print("PhonicsLetters: ModuleProgress not available, using local session progress")
		
		_show_completion_celebration(target_letter, progress_data)
	elif not text_result.begins_with("recognition_error"):
		print("PhonicsLetters: Letter not recognized correctly. Expected: ", target_letter, ", Got: ", recognized_text)
		
		# Track whiteboard failure for leaderboard analytics
		if module_progress and module_progress.is_authenticated():
			var whiteboard_track_success = await module_progress.track_phonics_whiteboard_attempt(target_letter, false)
			if not whiteboard_track_success:
				print("PhonicsLetters: Failed to track whiteboard failure")
		
		_show_encouragement_message(recognized_text, target_letter)
		if not recent_errors.has(target_letter):
			recent_errors.append(target_letter)
			if recent_errors.size() > 5:
				recent_errors.pop_front()

func _on_whiteboard_cancelled():
	print("PhonicsLetters: Whiteboard cancelled")

func _show_completion_celebration(letter: String, progress_data: Dictionary):
	"""Show completion celebration popup for dyslexic users"""
	print("PhonicsLetters: Showing completion celebration for letter: ", letter)
	
	# Load and instantiate completion celebration if not already done
	if not completion_celebration:
		var celebration_scene = load("res://Scenes/CompletionCelebration.tscn")
		if celebration_scene:
			completion_celebration = celebration_scene.instantiate()
			add_child(completion_celebration)
			
			# Connect signals
			if completion_celebration.has_signal("try_again_pressed"):
				completion_celebration.connect("try_again_pressed", Callable(self, "_on_celebration_try_again"))
			if completion_celebration.has_signal("next_item_pressed"):
				completion_celebration.connect("next_item_pressed", Callable(self, "_on_celebration_next"))
			if completion_celebration.has_signal("closed"):
				completion_celebration.connect("closed", Callable(self, "_on_celebration_closed"))
		else:
			print("PhonicsLetters: Failed to load CompletionCelebration scene")
			return
	
	# Show celebration with letter completion type
	if completion_celebration and completion_celebration.has_method("show_completion"):
		completion_celebration.show_completion(0, letter, progress_data, "phonics") # 0 = CompletionType.LETTER, "phonics" = module_key

func _show_encouragement_message(recognized: String, expected: String):
	"""Show encouraging message when letter isn't quite right"""
	if not notification_popup:
		var popup_scene = load("res://Scenes/NotificationPopUp.tscn")
		if popup_scene:
			notification_popup = popup_scene.instantiate()
			add_child(notification_popup)
	
	# Disconnect any existing connections and connect for encouragement
	if notification_popup.has_signal("button_pressed"):
		# Disconnect all existing connections
		var connections = notification_popup.get_signal_connection_list("button_pressed")
		for connection in connections:
			notification_popup.disconnect("button_pressed", connection["callable"])
		# Connect encouragement handler
		notification_popup.connect("button_pressed", Callable(self, "_on_encouragement_continue"))
	
	if notification_popup and notification_popup.has_method("show_notification"):
		var message = "Great try! I see you wrote '" + recognized + "'.\n\nLet's practice the letter '" + expected + "' again.\nTrace it carefully."
		notification_popup.show_notification("Keep Practicing!", message, "Again")

func _on_encouragement_continue():
	print("PhonicsLetters: Encouragement popup button pressed - stay on current letter for more practice")
	# Ensure whiteboard is ready for another attempt
	if whiteboard_instance:
		if whiteboard_instance.has_method("_on_clear_button_pressed"):
			whiteboard_instance._on_clear_button_pressed()
		if whiteboard_instance.has_method("_re_enable_buttons"):
			whiteboard_instance._re_enable_buttons()

func _on_celebration_try_again():
	"""Handle try again button from celebration popup"""
	print("PhonicsLetters: User chose to try again")
	# Stay on current letter for more practice
	if whiteboard_instance and whiteboard_instance.has_method("reset_for_retry"):
		whiteboard_instance.reset_for_retry()
		print("PhonicsLetters: Whiteboard reset after Try Again")
	
	# Ensure buttons are enabled after celebration popup closes
	if whiteboard_instance and whiteboard_instance.has_method("_re_enable_buttons"):
		whiteboard_instance._re_enable_buttons()

func _on_celebration_next():
	"""Handle next button from celebration popup"""
	print("PhonicsLetters: User chose to move to next letter")
	# Adaptive: if user struggled with a recent letter, occasionally revisit it before moving on
	if recent_errors.size() > 0 and randi() % 4 == 0:
		var revisit = recent_errors[randi() % recent_errors.size()]
		letter_index = letter_set.find(revisit)
		current_target = revisit
		_update_target_display()
		print("PhonicsLetters: Adaptive revisit of letter ", revisit)
	else:
		_advance_target()

func _on_celebration_closed():
	"""Handle celebration popup closed"""
	print("PhonicsLetters: Celebration popup closed")
	# No automatic actions when popup is simply closed - wait for user input
	# Only "Try Again" and "Next" buttons should trigger specific actions

func _toggle_focus_mode():
	letter_focus_mode = !letter_focus_mode
	var dim_targets = [
		$MainContainer/ContentContainer/InstructionPanel,
		$MainContainer/HeaderPanel
	]
	for node in dim_targets:
		if node:
			var tween = create_tween()
			var target_alpha = 0.35 if letter_focus_mode else 1.0
			tween.tween_property(node, "modulate:a", target_alpha, 0.4)
	print("PhonicsLetters: Focus mode = ", letter_focus_mode)

func _on_tts_settings_saved(voice_id: String, rate: float):
	"""Handle TTS settings save to update local TTS instance"""
	print("PhonicsLetters: Saving TTS preferences - Voice: ", voice_id, " Rate: ", rate)
	
	# Update current TTS instance
	if tts:
		if voice_id != null and voice_id != "":
			tts.set_voice(voice_id)
		if rate != null:
			tts.set_rate(rate)
	
	# Store in SettingsManager for persistence
	SettingsManager.set_setting("accessibility", "tts_voice_id", voice_id)
	SettingsManager.set_setting("accessibility", "tts_rate", rate)

# OCR correction specifically for letter recognition (fixes I→1, O→0 confusion)
func _apply_letter_ocr_correction(recognized: String, target: String) -> String:
	var corrected = recognized
	
	# Common OCR letter/digit confusions
	var digit_to_letter_map = {
		"0": "O",
		"1": "I",
		"5": "S",
		"6": "G",
		"2": "Z",
		"8": "B",
		"3": "E",
		"4": "A",
		"7": {"T": "F"},
		"9": "P"
		# Add more as needed
	}
	
	# Apply corrections for single character results
	if corrected.length() == 1 and digit_to_letter_map.has(corrected):
		var potential_letter = digit_to_letter_map[corrected]
		# Only correct if it matches our target or is a reasonable substitute
		if potential_letter == target:
			corrected = potential_letter
			print("PhonicsLetters: OCR corrected ", recognized, " → ", corrected)
	
	# Handle multi-character strings by checking each character
	elif corrected.length() > 1:
		var new_text = ""
		for i in range(corrected.length()):
			var character = corrected[i]
			if digit_to_letter_map.has(character):
				new_text += digit_to_letter_map[character]
			else:
				new_text += character
		corrected = new_text
	
	return corrected

# Helper: Check if two letters form an orientation-ambiguous pair
# Returns true if the letters can be confused due to rotation/flipping
func _is_orientation_pair(letter1: String, letter2: String) -> bool:
	if letter1 == letter2:
		return false
	
	# Comprehensive orientation-ambiguous pairs
	# These letters look identical when rotated or flipped
	var orientation_pairs = [
		["N", "Z"], # N rotated 90° clockwise or flipped horizontally → Z
		["M", "W"], # M flipped upside down → W
		["U", "N"], # U rotated 180° → N (less common but possible)
		["S", "2"] # S can look like 2 when rotated (OCR confusion)
	]
	
	# Check if the pair exists in either order
	for pair in orientation_pairs:
		if (letter1 == pair[0] and letter2 == pair[1]) or (letter1 == pair[1] and letter2 == pair[0]):
			return true
	
	return false

# Calculate similarity between letters (considers visual and phonetic similarity)
func _calculate_letter_similarity(letter1: String, letter2: String) -> float:
	if letter1 == letter2:
		return 1.0
	
	# CRITICAL: Orientation-ambiguous pairs (letters confused due to rotation/flip)
	# These should be accepted as CORRECT since OCR can't determine orientation reliably
	var orientation_pairs = [
		["N", "Z"], # N rotated 90° or flipped looks like Z
		["M", "W"], # M flipped upside down is W
		["U", "N"], # U rotated can look like N
	]
	
	# Check orientation-ambiguous pairs FIRST with highest confidence
	for pair in orientation_pairs:
		if (letter1 == pair[0] and letter2 == pair[1]) or (letter1 == pair[1] and letter2 == pair[0]):
			print("PhonicsLetters: Orientation pair detected - ", letter1, " vs ", letter2, " -> ACCEPTING as correct")
			return 1.0 # FULL acceptance for orientation confusion
	
	# Visual similarity groups (letters that look similar)
	var visual_groups = [
		["B", "D", "P", "R"], # Similar shapes with loops
		["C", "G", "O", "Q"], # Circular letters
		["I", "L", "1"], # Straight lines
		["M", "N", "W"], # Multiple peaks (also in orientation pairs)
		["U", "V"], # Similar curves
		["F", "E"], # Similar horizontal lines
		["H", "N"], # Similar verticals
		["K", "X"], # Similar crosses
		["S", "5"], # Similar curves
		["Z", "2"], # Similar diagonals
		["A", "V"] # Similar triangular shapes
	]
	
	# Dyslexic confusion pairs (common reversals - accept with high confidence)
	var dyslexic_pairs = [
		["B", "D"], ["P", "Q"], ["E", "F"], ["M", "W"], ["N", "Z"]
	]
	
	# Check visual similarity
	for group in visual_groups:
		if letter1 in group and letter2 in group:
			return 0.8 # High similarity within visual groups
	
	# Check dyslexic reversal patterns (should be accepted)
	for pair in dyslexic_pairs:
		if (letter1 == pair[0] and letter2 == pair[1]) or (letter1 == pair[1] and letter2 == pair[0]):
			return 0.9 # Very high acceptance for dyslexic patterns
	
	# Levenshtein-based similarity for everything else
	return 1.0 - (float(_levenshtein_distance(letter1, letter2)) / float(max(letter1.length(), letter2.length())))

# Extract most likely target letter from multi-character OCR result
func _extract_target_letter(text: String, target: String) -> String:
	# If the target letter appears in the text, return it
	if target in text:
		return target
	
	# Check for corrected digits that might be letters
	var corrected_text = _apply_letter_ocr_correction(text, target)
	if target in corrected_text:
		return target
	
	# CRITICAL: Check for orientation-ambiguous pairs in multi-char results
	# Example: target is "N", text is "Z123" → extract "Z" and recognize as orientation pair
	for character in text:
		var char_upper = character.to_upper()
		if _is_orientation_pair(char_upper, target):
			print("PhonicsLetters: Found orientation pair in multi-char: ", char_upper, " matches target ", target)
			return char_upper
	
	# Look for the most letter-like character in the string
	for character in text:
		if character.to_upper() >= "A" and character.to_upper() <= "Z":
			return character.to_upper()
	
	# If no letters found, return the first character
	return text[0] if text.length() > 0 else ""

# Helper: Calculate Levenshtein distance for fuzzy matching
func _levenshtein_distance(s1: String, s2: String) -> int:
	var len1 = s1.length()
	var len2 = s2.length()
	
	if len1 == 0:
		return len2
	if len2 == 0:
		return len1
	
	var matrix = []
	for i in range(len1 + 1):
		matrix.append([])
		for j in range(len2 + 1):
			matrix[i].append(0)
	
	for i in range(len1 + 1):
		matrix[i][0] = i
	for j in range(len2 + 1):
		matrix[0][j] = j
	
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost = 0 if s1[i - 1] == s2[j - 1] else 1
			matrix[i][j] = min(
				matrix[i - 1][j] + 1, # deletion
				matrix[i][j - 1] + 1, # insertion
				matrix[i - 1][j - 1] + cost # substitution
			)
	
	return matrix[len1][len2]
