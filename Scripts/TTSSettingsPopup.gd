extends Control

signal settings_saved(voice_id, rate)
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
	
	# Set TTS instance from parent (should be passed during setup)
	# Make popup modal
	set_process_input(true)
	
	# Show loading indicator
	$Panel/VBoxContainer/StatusLabel.text = "Loading voices..."

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
	current_voice_id = voice_id
	current_rate = rate
	test_word = word_sample
	
	# Connect signals
	if tts:
		if tts.is_connected("voices_loaded", Callable(self, "_on_voices_loaded")):
			tts.disconnect("voices_loaded", Callable(self, "_on_voices_loaded"))
		tts.connect("voices_loaded", Callable(self, "_on_voices_loaded"))
		
		# Apply settings
		tts.set_voice(voice_id)
		tts.set_rate(rate)
		
		# Update UI
		var rate_slider = $Panel/VBoxContainer/RateContainer/RateSlider
		rate_slider.value = rate
		_update_rate_label(rate)
		
		# Initialize voice options
		_initialize_voice_options()
	else:
		$Panel/VBoxContainer/StatusLabel.text = "ERROR: No TTS instance provided"

func _initialize_voice_options():
	var voice_select = $Panel/VBoxContainer/VoiceContainer/VoiceOptionButton
	voice_select.clear()
	
	# Get available voices
	voice_options = []
	var voice_dict = tts.get_voice_list()
	
	if voice_dict.size() <= 1:
		# Voices might still be loading, wait for the callback
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

func _on_test_button_pressed():
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
	# Save settings and close
	emit_signal("settings_saved", current_voice_id, current_rate)
	emit_signal("settings_closed")
	queue_free()
