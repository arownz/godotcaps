extends Node
class_name TextToSpeech

signal voices_loaded
signal speech_started
signal speech_finished

var tts_available = false
var voices = []
var selected_voice_id = ""
var speech_rate = 0.8  # Default to a slightly slower rate (Range: 0.1 to 2.0)
var speech_volume = 1.0 # Volume (Range: 0.0 to 1.0)
var speech_pitch = 1.0  # Pitch (Range: 0.5 to 2.0)

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
		print("Using English voice: ", selected_voice_id)
	
	# Signal that voices are loaded and ready
	voices_loaded.emit()

func speak(text):
	if !tts_available:
		print("TTS not available")
		return
		
	if selected_voice_id == "":
		print("No TTS voice selected")
		return
		
	if text.strip_edges() == "":
		print("Cannot speak empty text")
		return
	
	# Fixed: Pass the required voice_id parameter - Godot requires at least these two parameters
	print("Speaking text: ", text, " with voice: ", selected_voice_id)
	DisplayServer.tts_speak(text, selected_voice_id)
	
	print("Speaking text with rate ", speech_rate, ": ", text)
	speech_started.emit()

func stop_speaking():
	if !tts_available:
		return
		
	# Stop all speech
	DisplayServer.tts_stop()
	speech_finished.emit()

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
		return true
	return false

# Set the voice by name or partial name match
func set_voice_by_name(voice_name):
	for voice in voices:
		if voice["name"].to_lower().contains(voice_name.to_lower()):
			selected_voice_id = voice["id"]
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
