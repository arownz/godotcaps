extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null
var whiteboard_instance: Control = null

var current_target: String = "A"
var letter_set := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
var letter_index := 0

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
	
	# Connect hover events
	_connect_hover_events()
	
	# Style panels
	_style_panels()
	
	# Update initial display
	_update_target_display()
	
	# Load whiteboard
	_load_whiteboard()
	
	# Load progress
	call_deferred("_load_progress")

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	# Welcome message for letters
	var intro = "Let's practice letters! Listen to each letter and trace it on the whiteboard."
	var _ok = tts.speak(intro)

func _init_module_progress():
	if Engine.has_singleton("Firebase"):
		module_progress = ModuleProgress.new()
		add_child(module_progress)
	else:
		print("PhonicsLetters: Firebase not available; progress won't sync")

func _connect_hover_events():
	var back_btn = $MainContainer/HeaderPanel/HeaderContainer/BackButton
	if back_btn and not back_btn.mouse_entered.is_connected(_on_button_hover):
		back_btn.mouse_entered.connect(_on_button_hover)

func _style_panels():
	# Style main instruction panel
	var instruction_panel = $MainContainer/ContentContainer/InstructionPanel
	if instruction_panel:
		var style_box = StyleBoxFlat.new()
		style_box.corner_radius_top_left = 15
		style_box.corner_radius_top_right = 15
		style_box.corner_radius_bottom_left = 15
		style_box.corner_radius_bottom_right = 15
		style_box.bg_color = Color(1, 0.814317, 0.74054, 1) # ffd0bd dyslexic color
		style_box.border_width_left = 3
		style_box.border_width_right = 3
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.border_color = Color(0.2, 0.4, 0.8, 0.7)
		instruction_panel.add_theme_stylebox_override("panel", style_box)
	
	# Style whiteboard panel
	var whiteboard_panel = $MainContainer/ContentContainer/WhiteboardPanel
	if whiteboard_panel:
		var wb_style = StyleBoxFlat.new()
		wb_style.corner_radius_top_left = 10
		wb_style.corner_radius_top_right = 10
		wb_style.corner_radius_bottom_left = 10
		wb_style.corner_radius_bottom_right = 10
		wb_style.bg_color = Color(0.9, 0.95, 1.0, 1.0)
		wb_style.border_width_left = 2
		wb_style.border_width_right = 2
		wb_style.border_width_top = 2
		wb_style.border_width_bottom = 2
		wb_style.border_color = Color(0.5, 0.7, 0.9, 1.0)
		whiteboard_panel.add_theme_stylebox_override("panel", wb_style)

func _update_target_display():
	var target_label = $MainContainer/ContentContainer/InstructionPanel/InstructionContainer/TargetLabel
	if target_label:
		target_label.text = "Trace: " + current_target
	
	# Update trace overlay
	var trace_overlay = $MainContainer/ContentContainer/WhiteboardPanel/WhiteboardContainer/TraceOverlay
	if trace_overlay:
		trace_overlay.text = current_target

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
	if not module_progress:
		return
		
	var firebase_modules = await module_progress.fetch_modules()
	
	if firebase_modules.has("phonics_letters"):
		var fm = firebase_modules["phonics_letters"]
		if typeof(fm) == TYPE_DICTIONARY:
			var progress_percent = float(fm.get("progress", 0))
			_update_progress_ui(progress_percent)

func _update_progress_ui(percent: float):
	var progress_label = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressLabel
	var progress_bar = $MainContainer/HeaderPanel/HeaderContainer/ProgressContainer/ProgressBar
	
	if progress_label:
		progress_label.text = str(int(percent)) + "% Complete"
	if progress_bar:
		progress_bar.value = percent

func _on_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("PhonicsLetters: Returning to phonics categories")
	_fade_out_and_change_scene("res://Scenes/PhonicsModule.tscn")

func _fade_out_and_change_scene(scene_path: String):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_HearButton_pressed():
	$ButtonClick.play()
	if tts:
		var _ok = tts.speak("Letter " + current_target)

func _on_NextTargetButton_pressed():
	$ButtonClick.play()
	_advance_target()

func _advance_target():
	letter_index = (letter_index + 1) % letter_set.size()
	current_target = letter_set[letter_index]
	_update_target_display()
	
	# Clear whiteboard for next target
	if whiteboard_instance and whiteboard_instance.has_method("_on_clear_button_pressed"):
		whiteboard_instance._on_clear_button_pressed()

func _on_whiteboard_result(text_result: String):
	print("PhonicsLetters: Whiteboard result -> ", text_result)
	
	# Simple success heuristic 
	var success = text_result.strip_edges() != "" and not text_result.begins_with("recognition_error")
	
	if success and module_progress:
		# Award 4% progress per letter (26 letters = ~100%)
		var delta = 4
		var updated = await module_progress.increment_module_progress("phonics_letters", delta)
		print("PhonicsLetters: Progress updated -> ", updated)
		
		if typeof(updated) == TYPE_DICTIONARY:
			var new_percent = float(updated.get("progress", 0))
			_update_progress_ui(new_percent)
		
		# Success feedback
		var status_label = $MainContainer/CenterContainer/ContentPanel/ContentContainer/ModuleTitle
		if status_label:
			var original_text = status_label.text
			status_label.text = "Great job! +" + str(delta) + "% progress!"
			status_label.modulate = Color.GREEN
			
			# Reset after delay
			await get_tree().create_timer(2.0).timeout
			status_label.text = original_text
			status_label.modulate = Color.BLACK
		
		# Auto-advance to next target
		_advance_target()

func _on_whiteboard_cancelled():
	print("PhonicsLetters: Whiteboard cancelled")
