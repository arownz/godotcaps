extends Node
class_name TextToSpeech

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
var speech_rate = 0.8 # Default to a slightly slower rate (Range: 0.1 to 2.0)
var speech_volume = 1.0 # Volume (Range: 0.0 to 1.0)
var speech_pitch = 1.0 # Pitch (Range: 0.5 to 2.0)

func _ready():
	# Check if TTS is available on this platform
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		tts_available = true
		_initialize_tts()
	else:
		print("Text-to-speech is not available on this platform")

func _initialize_tts():
	if !tts_available:
		return
		
	# Get available voices
	voices = DisplayServer.tts_get_voices()
	
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
		print("No TTS voices available")
		
	# Alternative: Get English voices if available
	var english_voices = DisplayServer.tts_get_voices_for_language("en")
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
	
	# IMPORTANT: Call with only the required parameters that were working
	print("Speaking text: ", text, " with voice: ", selected_voice_id)
	
	# Try to speak - but don't try to capture return value since it's void
	DisplayServer.tts_speak(text, selected_voice_id)
	
	print("Speaking text with rate ", speech_rate, ": ", text)
	speech_started.emit()
	
	# Create a simple timer to emit speech completion after estimated duration
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.5 + (text.length() * 0.1) # Simple estimate based on text length
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
	if voice_id in get_voice_list():
		selected_voice_id = voice_id
		current_voice = voice_id # Set compatibility property
		return true
	
	speech_error.emit("Invalid voice ID: " + voice_id)
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