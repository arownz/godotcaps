extends Control

var tts: TextToSpeech = null
var module_progress: ModuleProgress = null
var whiteboard_instance: Control = null
var notification_popup: CanvasLayer = null

var current_target: String = "A"
var letter_set := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
var letter_index := 0

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
	
	# Connect hover events
	_connect_hover_events()
	
	# Update initial display
	_update_target_display()
	
	# Load whiteboard
	_load_whiteboard()
	
	# Load progress
	call_deferred("_load_progress")
	
	# Initialize notification popup
	_init_notification_popup()

func _init_notification_popup():
	notification_popup = $NotificationPopup
	if notification_popup:
		print("PhonicsLetters: Notification popup initialized")
	else:
		print("PhonicsLetters: Warning - NotificationPopup not found")

func _init_tts():
	tts = TextToSpeech.new()
	add_child(tts)
	print("PhonicsLetters: TTS initialized")

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

func _on_HearButton_pressed():
	$ButtonClick.play()
	if tts:
		# Enhanced TTS guide with instructions
		var guide_text = "Listen carefully: Letter " + current_target + ". Now trace this letter on the whiteboard. " + current_target + " sounds like " + _get_letter_sound(current_target) + "."
		_speak_text_simple(guide_text)

func _on_guide_button_pressed():
	$ButtonClick.play()
	if tts:
		var guide_text = "Welcome to Letters Practice! Here you will learn to trace letters from A to Z. Look at the letter shown above, then use your finger or mouse to trace it carefully on the whiteboard below. Listen to the letter sound by pressing 'Hear Letter', and when you're ready to move on, press 'Next Letter'. Take your time and practice until you feel confident with each letter!"
		_speak_text_simple(guide_text)

func _on_tts_setting_button_pressed():
	$ButtonClick.play()
	print("PhonicsLetters: Looking for TTSSettingsPopup (robust lookup)...")
	var tts_popup = get_node_or_null("TTSSettingsPopup")
	if not tts_popup:
		tts_popup = find_child("TTSSettingsPopup", true, false)
	if not tts_popup:
		print("PhonicsLetters: TTSSettingsPopup not found - instantiating dynamically")
		var popup_scene: PackedScene = load("res://Scenes/TTSSettingsPopup.tscn")
		if popup_scene:
			tts_popup = popup_scene.instantiate()
			tts_popup.name = "TTSSettingsPopup"
			add_child(tts_popup)
	print("PhonicsLetters: TTSSettingsPopup final status:", tts_popup != null)
	if tts_popup:
		# Setup popup with current settings
		var current_voice = SettingsManager.get_setting("accessibility", "tts_voice_id")
		var current_rate = SettingsManager.get_setting("accessibility", "tts_rate")
		
		# Provide safe defaults
		if current_voice == null or current_voice == "":
			current_voice = "default"
		if current_rate == null:
			current_rate = 1.0
		
		# Pass current TTS instance to popup for voice testing
		if tts_popup.has_method("set_tts_instance"):
			tts_popup.set_tts_instance(tts)
		
		if tts_popup.has_method("setup"):
			tts_popup.setup(tts, current_voice, current_rate, "Testing Text to Speech")
		
		# Connect to save signal if not already connected
		if not tts_popup.settings_saved.is_connected(_on_tts_settings_saved):
			tts_popup.settings_saved.connect(_on_tts_settings_saved)
		
		tts_popup.visible = true
		print("PhonicsLetters: TTS Settings popup opened")
	else:
		print("PhonicsLetters: Warning - TTSSettingsPopup still not found after dynamic attempt")

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
		module_progress.increment_progress("phonics_letters", 3)

func _on_whiteboard_cancelled():
	print("PhonicsLetters: Whiteboard cancelled")

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
