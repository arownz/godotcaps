extends Control

signal challenge_completed(bonus_damage)
signal challenge_failed

# References to child nodes
var random_word_label
var whiteboard_interface
var tts_settings_panel
var api_status_label

# Word challenge properties
var challenge_word = ""
var bonus_damage = 20
var random_word_api = null
var tts = null
var voice_options = []

func _ready():
	# Get node references
	random_word_label = $ChallengePanel/VBoxContainer/WordContainer/RandomWordLabel
	whiteboard_interface = $ChallengePanel/VBoxContainer/WhiteboardContainer/WhiteboardInterface
	tts_settings_panel = $ChallengePanel/VBoxContainer/TTSSettingsPanel
	api_status_label = $ChallengePanel/VBoxContainer/APIStatusLabel
	
	# Create TTS instance
	tts = TextToSpeech.new()
	add_child(tts)
	
	# Initialize TTS settings
	_initialize_tts_settings()
	
	# Create and initialize the random word API
	random_word_api = RandomWordAPI.new()
	add_child(random_word_api)
	random_word_api.word_fetched.connect(_on_word_fetched)
	
	# Fetch a random word
	random_word_api.fetch_random_word()
	
	# Connect whiteboard signal for submission only (no cancel)
	whiteboard_interface.drawing_submitted.connect(_on_drawing_submitted)
	
	# Remove the Cancel button from the WhiteboardInterface
	# First, find the cancel button
	for child in whiteboard_interface.get_node("VBoxContainer/ButtonsContainer").get_children():
		if child is Button and child.text == "Cancel":
			child.queue_free()
			break

func _initialize_tts_settings():
	# Get all available voices
	var voice_select = $ChallengePanel/VBoxContainer/TTSSettingsPanel/VBoxContainer/VoiceContainer/VoiceOptionButton
	voice_select.clear()
	
	# Use the correct function to get available voices
	voice_options = []
	var voice_dict = tts.get_voice_list()
	for voice_id in voice_dict:
		voice_options.append({
			"id": voice_id,
			"name": voice_dict[voice_id]
		})
	
	for voice in voice_options:
		voice_select.add_item(voice.name)
	
	# Set default voice
	if voice_options.size() > 0:
		voice_select.select(0)
		tts.set_voice(voice_options[0].id)

func _on_word_fetched():
	# Update the random word label
	challenge_word = random_word_api.get_random_word()
	random_word_label.text = challenge_word
	
	# Clear API status if successful, or show error
	if random_word_api.last_error == "":
		api_status_label.text = ""
	else:
		api_status_label.text = "API Error: " + random_word_api.last_error
	
	# Log the word for debugging
	print("Challenge word: ", challenge_word)

func _on_drawing_submitted(text_result):
	# Compare the recognized text with the challenge word
	if text_result.to_lower().strip_edges() == challenge_word.to_lower().strip_edges():
		# Success - bonus damage!
		emit_signal("challenge_completed", bonus_damage)
	else:
		# Failure
		emit_signal("challenge_failed")
	
	# Remove the challenge panel
	queue_free()

func _on_tts_button_pressed():
	# Speak the challenge word
	tts.speak(challenge_word)

func _on_tts_settings_button_pressed():
	# Toggle the TTS settings panel
	tts_settings_panel.visible = !tts_settings_panel.visible

func _on_voice_option_button_item_selected(index):
	# Set the selected voice
	if index >= 0 and index < voice_options.size():
		tts.set_voice(voice_options[index].id)

func _on_rate_slider_value_changed(value):
	# Update rate label text
	var rate_label = $ChallengePanel/VBoxContainer/TTSSettingsPanel/VBoxContainer/RateContainer/RateValueLabel
	var rate_text = "Rate: " + str(value)
	
	if value < 0.8:
		rate_text += " (Slower)"
	elif value > 1.2:
		rate_text += " (Faster)"
	else:
		rate_text += " (Normal)"
	
	rate_label.text = rate_text
	
	# Set speech rate
	tts.set_rate(value)

func _on_test_button_pressed():
	# Test the current TTS settings with the challenge word
	tts.speak(challenge_word)

func _on_close_button_pressed():
	# Close the TTS settings panel
	tts_settings_panel.visible = false
