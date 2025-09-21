extends Node
class_name TextToSpeech

# https://docs.godotengine.org/en/stable/tutorials/audio/text_to_speech.html

signal voices_loaded
signal speech_started
signal speech_finished
# Add these compatibility signals
signal speech_ended
signal speech_error # Fixed: Properly declared signal

# Add this compatibility property
var current_voice = ""

var tts_available = false
var voices = []
var selected_voice_id = ""
var speech_rate = 1.0 # Default to normal reading speed (Range: 0.1 to 2.0)
var speech_volume = 1.0 # Volume (Range: 0.0 to 1.0)
var speech_pitch = 1.0 # Pitch (Range: 0.5 to 2.0)

func _ready():
	# Add to TTS instances group for volume control
	add_to_group("tts_instances")
	
	print("DEBUG: Checking TTS availability...")
	print("DEBUG: DisplayServer.has_feature(FEATURE_TEXT_TO_SPEECH): ", DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH))
	
	# Check if TTS is available on this platform
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		tts_available = true
		print("DEBUG: TTS feature is available, initializing...")
		_initialize_tts()
	else:
		print("ERROR: Text-to-speech is not available on this platform")
		print("Make sure TTS is enabled in Project Settings > Audio > General > Text to Speech")
	
	# Apply all saved TTS settings from SettingsManager
	update_settings()

func _apply_saved_volume():
	"""Apply saved TTS volume from SettingsManager"""
	if SettingsManager:
		var saved_volume = SettingsManager.get_setting("accessibility", "tts_volume")
		if saved_volume != null:
			set_volume(saved_volume / 100.0)
			print("TextToSpeech: Applied saved volume: ", saved_volume, "%")

func update_settings():
	"""Update all TTS settings from SettingsManager - called when settings change"""
	if not SettingsManager:
		print("TextToSpeech: SettingsManager not available")
		return
		
	# Update volume
	var saved_volume = SettingsManager.get_setting("accessibility", "tts_volume")
	print("TextToSpeech: Retrieved volume from SettingsManager: ", saved_volume)
	if saved_volume != null:
		var converted_volume = saved_volume / 100.0
		set_volume(converted_volume)
		print("TextToSpeech: Updated volume: ", saved_volume, "% -> ", converted_volume)
	
	# Update speech rate 
	var saved_rate = SettingsManager.get_setting("accessibility", "tts_rate")
	print("TextToSpeech: Retrieved rate from SettingsManager: ", saved_rate)
	if saved_rate != null:
		set_rate(saved_rate)
		print("TextToSpeech: Updated rate: ", saved_rate, "x")
	
	# Update voice if available
	var saved_voice = SettingsManager.get_setting("accessibility", "tts_voice_id")
	print("TextToSpeech: Retrieved voice from SettingsManager: ", saved_voice)
	if saved_voice != null and saved_voice != "default" and saved_voice != "":
		set_voice(saved_voice)
		print("TextToSpeech: Updated voice: ", saved_voice)
	
	print("TextToSpeech: Final settings - Volume: ", speech_volume, ", Rate: ", speech_rate, ", Voice: ", selected_voice_id)

func _initialize_tts():
	if !tts_available:
		return
		
	# Get available voices
	voices = DisplayServer.tts_get_voices()
	print("DEBUG: Total voices found: ", voices.size())
	
	if voices.size() > 0:
		# Select the first voice by default
		selected_voice_id = voices[0]["id"]
		current_voice = selected_voice_id # Set compatibility property
		print("TTS initialized with voice: ", voices[0]["name"])
		
		# Print all available voices for debugging
		print("Available TTS voices:")
		for voice in voices:
			print("- ", voice["name"], " (", voice["id"], ")")
	else:
		print("ERROR: No TTS voices available! Check if TTS is enabled in Project Settings")
		print("Go to Project > Project Settings > Audio > General > Enable Text to Speech")
		return
		
	# Try to get English voices if available
	var english_voices = DisplayServer.tts_get_voices_for_language("en")
	print("DEBUG: English voices found: ", english_voices.size())
	if english_voices.size() > 0:
		selected_voice_id = english_voices[0]
		current_voice = selected_voice_id # Set compatibility property
		print("Using English voice: ", selected_voice_id)
	
	# Signal that voices are loaded and ready
	voices_loaded.emit()

func speak(text):
	if !tts_available:
		print("TTS not available")
		speech_error.emit("TTS not available on this platform")
		return false
		
	if selected_voice_id == "":
		print("No TTS voice selected")
		speech_error.emit("No voice selected")
		return false
		
	if text.strip_edges() == "":
		print("Cannot speak empty text")
		speech_error.emit("Cannot speak empty text")
		return false
	
	print("Speaking text: ", text, " with voice: ", selected_voice_id, " volume: ", speech_volume, " rate: ", speech_rate)
	print("DEBUG: Internal TTS settings before speaking - speech_volume: ", speech_volume, ", speech_rate: ", speech_rate, ", speech_pitch: ", speech_pitch)
	
	# For web platforms, use JavaScript TTS with volume support
	if OS.has_feature("web"):
		if JavaScriptBridge.has_method("eval"):
			var js_code = "if (window.speakText) { window.speakText('" + text.replace("'", "\\'") + "', '" + selected_voice_id + "', " + str(speech_rate) + ", " + str(speech_volume) + "); }"
			JavaScriptBridge.eval(js_code)
		else:
			print("JavaScriptBridge not available for web TTS")
			return false
	else:
		# For desktop platforms, use extended TTS call with volume, pitch, and rate
		print("DEBUG: Using extended TTS call with parameters")
		var volume_int = int(speech_volume * 100) # Convert 0.0-1.0 to 0-100
		print("DEBUG: Extended params - volume_int: ", volume_int, ", pitch: ", speech_pitch, ", rate: ", speech_rate)
		DisplayServer.tts_speak(text, selected_voice_id, volume_int, speech_pitch, speech_rate)
	
	print("Speaking text with rate ", speech_rate, " and volume ", speech_volume, ": ", text)
	speech_started.emit()
	
	# Create a more accurate timer based on speech rate and text complexity
	var timer = Timer.new()
	add_child(timer)
	
	# Improved duration calculation
	var word_count = text.split(" ").size()
	var base_duration = word_count * 0.6 # Base: 0.6 seconds per word
	var rate_adjusted_duration = base_duration / speech_rate # Adjust for speech rate
	
	# Add extra time for punctuation pauses
	var punctuation_count = 0
	for character in text:
		if character in [".", "!", "?"]:
			punctuation_count += 1
		elif character in [",", ";"]:
			punctuation_count += 0.5
	
	var total_duration = rate_adjusted_duration + (punctuation_count * 0.3)
	
	# Ensure minimum and maximum bounds
	timer.wait_time = clamp(total_duration, 1.0, 15.0)
	
	print("TTS estimated duration: ", timer.wait_time, " seconds for ", word_count, " words")
	
	timer.one_shot = true
	timer.timeout.connect(func():
		# FIXED: Emit signals in logical order and add comment about redundancy
		speech_finished.emit()
		speech_ended.emit() # Compatibility signal - same event as speech_finished
		timer.queue_free()
	)
	timer.start()
	
	return true

func stop_speaking():
	if !tts_available:
		speech_error.emit("TTS not available")
		return
		
	# Stop all speech - but don't try to capture return value
	DisplayServer.tts_stop()
	
	speech_finished.emit()
	speech_ended.emit() # Also emit compatibility signal

# Add stop method for compatibility
func stop():
	stop_speaking()

# Get the list of available voices as a Dictionary for UI display
func get_voice_list():
	var voice_dict = {}
	for voice in voices:
		voice_dict[voice["id"]] = voice["name"]
	return voice_dict

# Set the voice by ID
func set_voice(voice_id):
	if voice_id == null or voice_id == "":
		print("TextToSpeech: Warning - null or empty voice_id provided")
		return false
		
	if voice_id in get_voice_list():
		selected_voice_id = voice_id
		current_voice = voice_id # Set compatibility property
		return true
	
	speech_error.emit("Invalid voice ID: " + str(voice_id))
	return false

# Set the voice by name or partial name match
func set_voice_by_name(voice_name):
	for voice in voices:
		if voice["name"].to_lower().contains(voice_name.to_lower()):
			selected_voice_id = voice["id"]
			current_voice = selected_voice_id # Set compatibility property
			return true
	return false

# Set speech rate (0.1 to 2.0, with 1.0 being normal speed)
func set_speech_rate(rate):
	speech_rate = clamp(rate, 0.1, 2.0)

# Get current speech rate
func get_rate():
	return speech_rate

# Add this compatibility method to match WebTTS API
func set_rate(rate):
	set_speech_rate(rate)
	return true

# Set speech volume (0.0 to 1.0)
func set_speech_volume(volume):
	speech_volume = clamp(volume, 0.0, 1.0)

# Similar compatibility method for volume if needed
func set_volume(volume):
	set_speech_volume(volume)
	return true

# Set speech pitch (0.5 to 2.0)
func set_speech_pitch(pitch):
	speech_pitch = clamp(pitch, 0.5, 2.0)

# Similar compatibility method for pitch if needed
func set_pitch(pitch):
	set_speech_pitch(pitch)
	return true