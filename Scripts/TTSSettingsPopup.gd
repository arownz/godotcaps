extends Control

signal settings_saved(voice_id, rate, volume)
signal settings_closed

# Popup properties
var tts = null
var voices_loaded = false
var voice_options = []
var current_voice_id = "default"
var current_rate = 1.0
var current_volume = 1.0
var current_pitch = 1.0
var test_word = "testing"

func _ready():
	# Set initial values
	var rate_slider = $Panel/VBoxContainer/RateContainer/RateSlider
	rate_slider.value = current_rate
	_update_rate_label(current_rate)
	
	var volume_slider = $Panel/VBoxContainer/VolumeContainer/VolumeSlider
	volume_slider.value = current_volume * 100.0 # Convert 0.0-1.0 to 0-100
	_update_volume_label(current_volume * 100.0)
	
	# Make popup modal
	set_process_input(true)
	
	# Show loading indicator
	$Panel/VBoxContainer/StatusLabel.text = "Loading voices..."
	
	# Connect button hover events
	if $Panel/TestButton:
		$Panel/TestButton.mouse_entered.connect(_on_button_hover)
	if $Panel/CloseButton:
		$Panel/CloseButton.mouse_entered.connect(_on_button_hover)
	
	# Initialize TTS if not already set
	if not tts:
		_initialize_tts()

func _on_button_hover():
	$ButtonHover.play()

func _initialize_tts():
	"""Initialize TTS instance if not provided"""
	if not tts:
		print("TTSSettingsPopup: Creating new TTS instance")
		tts = TextToSpeech.new()
		add_child(tts)
		
		# Connect to voices_loaded signal
		if tts.has_signal("voices_loaded"):
			if not tts.voices_loaded.is_connected(_on_voices_loaded):
				tts.voices_loaded.connect(_on_voices_loaded)
		
		# Wait a frame for TTS to initialize
		await get_tree().process_frame
		
		# Check if voices are already available
		_initialize_voice_options()
	else:
		print("TTSSettingsPopup: Using provided TTS instance")
		# Connect to existing TTS signals
		if tts.has_signal("voices_loaded"):
			if not tts.voices_loaded.is_connected(_on_voices_loaded):
				tts.voices_loaded.connect(_on_voices_loaded)
		
		# Initialize voice options immediately
		_initialize_voice_options()

func set_tts_instance(tts_instance):
	"""Set the TTS instance from external source"""
	tts = tts_instance
	print("TTSSettingsPopup: TTS instance set externally")
	
	# Connect signals if needed
	if tts and tts.has_signal("voices_loaded"):
		if not tts.voices_loaded.is_connected(_on_voices_loaded):
			tts.voices_loaded.connect(_on_voices_loaded)
	
	# Initialize voice options
	_initialize_voice_options()

func _input(event):
	# Close popup on escape key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()
	
	# Close if clicking outside the panel
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		if not $Panel.get_global_rect().has_point(mouse_pos):
			_on_close_button_pressed()
			get_viewport().set_input_as_handled()

# Set the popup with initial values
func setup(tts_instance, voice_id, rate, word_sample):
	tts = tts_instance
	current_voice_id = voice_id if voice_id != null else "default"
	current_rate = rate if rate != null else 1.0
	test_word = word_sample if word_sample != null else "Testing"
	
	# Load current volume from SettingsManager
	if SettingsManager:
		var saved_volume = SettingsManager.get_setting("accessibility", "tts_volume")
		if saved_volume != null:
			current_volume = saved_volume / 100.0 # Convert 0-100 to 0.0-1.0
	
	# Connect signals
	if tts:
		if tts.is_connected("voices_loaded", Callable(self, "_on_voices_loaded")):
			tts.disconnect("voices_loaded", Callable(self, "_on_voices_loaded"))
		tts.connect("voices_loaded", Callable(self, "_on_voices_loaded"))
		
		# Apply settings safely
		if current_voice_id != null and current_voice_id != "":
			tts.set_voice(current_voice_id)
		if current_rate != null:
			tts.set_rate(current_rate)
		# Also apply current volume
		tts.set_volume(current_volume)
		
		# Update UI
		var rate_slider = $Panel/VBoxContainer/RateContainer/RateSlider
		rate_slider.value = current_rate
		_update_rate_label(current_rate)
		
		var volume_slider = $Panel/VBoxContainer/VolumeContainer/VolumeSlider
		volume_slider.value = current_volume * 100.0
		_update_volume_label(current_volume * 100.0)
		
		# Initialize voice options
		_initialize_voice_options()
	else:
		$Panel/VBoxContainer/StatusLabel.text = "ERROR: No TTS instance provided"

func _initialize_voice_options():
	var voice_select = $Panel/VBoxContainer/VoiceContainer/VoiceOptionButton
	voice_select.clear()
	
	if not tts:
		$Panel/VBoxContainer/StatusLabel.text = "No TTS instance available"
		return
	
	# Get available voices
	voice_options = []
	var voice_dict = tts.get_voice_list()
	
	print("TTSSettingsPopup: Available voices count: ", voice_dict.size())
	for voice_id in voice_dict:
		print("TTSSettingsPopup: Voice - ID: ", voice_id, " Name: ", voice_dict[voice_id])
	
	if voice_dict.size() == 0:
		# No voices available yet, show message and try again after delay
		$Panel/VBoxContainer/StatusLabel.text = "Waiting for voices to load..."
		await get_tree().create_timer(1.0).timeout
		_initialize_voice_options()
		return
	
	# Convert to option array
	for voice_id in voice_dict:
		voice_options.append({
			"id": voice_id,
			"name": voice_dict[voice_id]
		})
	
	# Add to dropdown
	for voice in voice_options:
		voice_select.add_item(voice.name)
	
	# Mark as loaded
	voices_loaded = true
	
	# Update status
	$Panel/VBoxContainer/StatusLabel.text = "Voices loaded successfully"
	
	# Select the current voice
	_select_current_voice()

func _select_current_voice():
	var voice_select = $Panel/VBoxContainer/VoiceContainer/VoiceOptionButton
	
	# Find and select the current voice
	for i in range(voice_options.size()):
		if voice_options[i].id == current_voice_id:
			voice_select.select(i)
			break

func _on_voices_loaded():
	# Update voice options when loaded
	_initialize_voice_options()

func _on_voice_option_button_item_selected(index):
	$ButtonClick.play()
	# Update current voice
	if index >= 0 and index < voice_options.size():
		current_voice_id = voice_options[index].id
		if tts:
			tts.set_voice(current_voice_id)

func _on_rate_slider_value_changed(value):
	# Update current rate
	current_rate = value
	if tts:
		tts.set_rate(value)
	
	# Update label
	_update_rate_label(value)

func _update_rate_label(value):
	# Update rate display text
	var rate_label = $Panel/VBoxContainer/RateContainer/RateValueLabel
	var rate_text = "Rate: " + str(value)
	
	if value < 0.8:
		rate_text += " (Slower)"
	elif value > 1.2:
		rate_text += " (Faster)"
	else:
		rate_text += " (Normal)"
	
	rate_label.text = rate_text

func _on_volume_slider_value_changed(value):
	# Update current volume
	current_volume = value / 100.0 # Convert 0-100 to 0.0-1.0
	if tts:
		tts.set_volume(current_volume)
	
	# Update label
	_update_volume_label(value)

func _update_volume_label(value):
	# Update volume display text
	var volume_label = $Panel/VBoxContainer/VolumeContainer/VolumeValueLabel
	volume_label.text = "Volume: " + str(int(value)) + "%"

func _on_test_button_pressed():
	$ButtonClick.play()
	# Test the current voice and rate with improved feedback
	if tts:
		$Panel/VBoxContainer/StatusLabel.text = "Testing voice with: " + test_word + "..."
		
		print("Test button pressed, trying to speak: ", test_word)
		
		# Connect signals temporarily for this test
		if tts.is_connected("speech_started", Callable(self, "_on_test_speech_started")):
			tts.disconnect("speech_started", Callable(self, "_on_test_speech_started"))
		tts.connect("speech_started", Callable(self, "_on_test_speech_started"))
		
		if tts.is_connected("speech_ended", Callable(self, "_on_test_speech_ended")):
			tts.disconnect("speech_ended", Callable(self, "_on_test_speech_ended"))
		tts.connect("speech_ended", Callable(self, "_on_test_speech_ended"))
		
		if tts.is_connected("speech_error", Callable(self, "_on_test_speech_error")):
			tts.disconnect("speech_error", Callable(self, "_on_test_speech_error"))
		tts.connect("speech_error", Callable(self, "_on_test_speech_error"))
		
		# Attempt to speak
		var result = tts.speak(test_word)
		if !result:
			$Panel/VBoxContainer/StatusLabel.text = "Failed to start speech test"
			print("Test speech failed - check if TTS is enabled in Project Settings")
	else:
		$Panel/VBoxContainer/StatusLabel.text = "ERROR: No TTS instance available"

# Feedback handlers for speech test
func _on_test_speech_started():
	$Panel/VBoxContainer/StatusLabel.text = "Speaking..."

func _on_test_speech_ended():
	$Panel/VBoxContainer/StatusLabel.text = "Test complete"
	
	# Disconnect the temporary signals
	if tts and tts.is_connected("speech_started", Callable(self, "_on_test_speech_started")):
		tts.disconnect("speech_started", Callable(self, "_on_test_speech_started"))
	
	if tts and tts.is_connected("speech_ended", Callable(self, "_on_test_speech_ended")):
		tts.disconnect("speech_ended", Callable(self, "_on_test_speech_ended"))
	
	if tts and tts.is_connected("speech_error", Callable(self, "_on_test_speech_error")):
		tts.disconnect("speech_error", Callable(self, "_on_test_speech_error"))

func _on_test_speech_error(error_msg):
	$Panel/VBoxContainer/StatusLabel.text = "Error: " + error_msg
	
	# Disconnect the temporary signals
	if tts and tts.is_connected("speech_started", Callable(self, "_on_test_speech_started")):
		tts.disconnect("speech_started", Callable(self, "_on_test_speech_started"))
	
	if tts and tts.is_connected("speech_ended", Callable(self, "_on_test_speech_ended")):
		tts.disconnect("speech_ended", Callable(self, "_on_test_speech_ended"))
	
	if tts and tts.is_connected("speech_error", Callable(self, "_on_test_speech_error")):
		tts.disconnect("speech_error", Callable(self, "_on_test_speech_error"))

func _on_close_button_pressed():
	$ButtonClick.play()
	# Save settings and close
	emit_signal("settings_saved", current_voice_id, current_rate, current_volume)
	emit_signal("settings_closed")
	queue_free()


func _on_test_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_close_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_voice_option_button_mouse_entered() -> void:
	$ButtonHover.play()
