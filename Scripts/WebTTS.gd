extends Node
class_name WebTTS

signal tts_initialized
signal speech_started
signal speech_ended
signal voices_loaded

var tts_available = false
var is_web_platform = false
var selected_voice_id = ""
var speech_rate = 0.8  # Default to a slower rate for dyslexic users
var speech_volume = 1.0
var speech_pitch = 1.0
var available_voices = []

func _ready():
	# Check if we're running on Web platform
	is_web_platform = OS.get_name() == "Web"
	
	if is_web_platform:
		# Use JavaScript TTS which is more reliable on web
		_initialize_web_tts()
	else:
		# For other platforms, check native TTS
		tts_available = DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)
		tts_initialized.emit()

func _initialize_web_tts():
	if not is_web_platform:
		return
	
	# First, register our callbacks with unique IDs
	var voices_loaded_callback_id = JavaScriptBridge.create_callback(Callable(self, "_on_web_voices_loaded"))
	var speech_started_callback_id = JavaScriptBridge.create_callback(Callable(self, "_on_web_speech_started"))
	var speech_ended_callback_id = JavaScriptBridge.create_callback(Callable(self, "_on_web_speech_ended"))
	
	# Initialize Web Speech API via JavaScript with improved voice handling and rate control
	JavaScriptBridge.eval("""
		window.godotWebTTS = {
			synth: window.speechSynthesis,
			voices: [],
			initialized: false,
			selectedVoice: null,
			rate: 0.8,
			volume: 1.0,
			pitch: 1.0,
			
			init: function() {
				// Get available voices
				this.voices = this.synth.getVoices();
				
				// If voices aren't loaded yet, set up event handler
				if (this.voices.length === 0) {
					speechSynthesis.onvoiceschanged = () => {
						this.voices = this.synth.getVoices();
						this.initialized = true;
						
						// Find an English voice
						this.findEnglishVoice();
						
						// Call Godot callback directly with voices data
						var voicesData = this.getVoicesList();
						window.godotVoicesLoadedCallback(voicesData);
					};
				} else {
					this.initialized = true;
					this.findEnglishVoice();
					
					// Call Godot callback directly with voices data
					var voicesData = this.getVoicesList();
					window.godotVoicesLoadedCallback(voicesData);
				}
				return this.initialized;
			},
			
			findEnglishVoice: function() {
				// Select an English voice if available
				for (let i = 0; i < this.voices.length; i++) {
					if (this.voices[i].lang.startsWith('en')) {
						this.selectedVoice = this.voices[i];
						break;
					}
				}
				
				// If no English voice found, use the first available voice
				if (!this.selectedVoice && this.voices.length > 0) {
					this.selectedVoice = this.voices[0];
				}
			},
			
			getVoicesList: function() {
				const voicesList = [];
				for (let i = 0; i < this.voices.length; i++) {
					voicesList.push({
						name: this.voices[i].name,
						lang: this.voices[i].lang,
						index: i
					});
				}
				return voicesList;
			},
			
			setVoice: function(index) {
				if (index >= 0 && index < this.voices.length) {
					this.selectedVoice = this.voices[index];
					return true;
				}
				return false;
			},
			
			setRate: function(rate) {
				this.rate = parseFloat(rate);
				return true;
			},
			
			setVolume: function(volume) {
				this.volume = parseFloat(volume);
				return true;
			},
			
			setPitch: function(pitch) {
				this.pitch = parseFloat(pitch);
				return true;
			},
			
			speak: function(text) {
				if (!this.initialized) this.init();
				
				// Cancel any ongoing speech
				this.synth.cancel();
				
				// Create speech utterance
				const utterance = new SpeechSynthesisUtterance(text);
				
				// Set voice if we have one selected
				if (this.selectedVoice) {
					utterance.voice = this.selectedVoice;
				}
				
				// Apply speech parameters
				utterance.rate = this.rate;
				utterance.volume = this.volume;
				utterance.pitch = this.pitch;
				
				// Add event handlers
				utterance.onstart = () => {
					window.godotSpeechStartedCallback();
				};
				
				utterance.onend = () => {
					window.godotSpeechEndedCallback();
				};
				
				// Speak the text
				this.synth.speak(utterance);
				return true;
			},
			
			stop: function() {
				this.synth.cancel();
				window.godotSpeechEndedCallback();
				return true;
			}
		};
		
		// Set up callback functions that can be called from JavaScript
		window.godotVoicesLoadedCallback = function(voicesData) {
			""" + voices_loaded_callback_id + """(voicesData);
		};
		
		window.godotSpeechStartedCallback = function() {
			""" + speech_started_callback_id + """();
		};
		
		window.godotSpeechEndedCallback = function() {
			""" + speech_ended_callback_id + """();
		};
		
		// Initialize on load
		window.godotWebTTS.init();
	""")
	
	# Check if TTS is available in the browser
	tts_available = JavaScriptBridge.eval("window.godotWebTTS.initialized")
	tts_initialized.emit()

func _on_web_voices_loaded(voices_data):
	available_voices = voices_data
	voices_loaded.emit()

func _on_web_speech_started():
	speech_started.emit()

func _on_web_speech_ended():
	speech_ended.emit()

func get_available_voices():
	if is_web_platform:
		return available_voices
	else:
		# For non-web platforms, use the native TTS
		var voices = []
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			var native_voices = DisplayServer.tts_get_voices()
			for i in range(native_voices.size()):
				voices.append({
					"name": native_voices[i]["name"],
					"lang": native_voices[i]["language"],
					"index": i
				})
		return voices

func set_voice(index):
	if is_web_platform:
		return JavaScriptBridge.eval("window.godotWebTTS.setVoice(" + str(index) + ")")
	else:
		# For non-web platforms
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			var voices = DisplayServer.tts_get_voices()
			if index >= 0 and index < voices.size():
				selected_voice_id = voices[index]["id"]
				return true
	return false

func set_rate(rate):
	speech_rate = clamp(rate, 0.1, 2.0)
	if is_web_platform:
		return JavaScriptBridge.eval("window.godotWebTTS.setRate(" + str(speech_rate) + ")")
	return true

func set_volume(volume):
	speech_volume = clamp(volume, 0.0, 1.0)
	if is_web_platform:
		return JavaScriptBridge.eval("window.godotWebTTS.setVolume(" + str(speech_volume) + ")")
	return true

func set_pitch(pitch):
	speech_pitch = clamp(pitch, 0.5, 2.0)
	if is_web_platform:
		return JavaScriptBridge.eval("window.godotWebTTS.setPitch(" + str(speech_pitch) + ")")
	return true

func speak(text):
	if !tts_available:
		print("TTS not available")
		return false
		
	if is_web_platform:
		# Use Web Speech API
		var success = JavaScriptBridge.eval("window.godotWebTTS.speak('" + text.replace("'", "\\'") + "')")
		return success
	else:
		# Use native TTS - fallback to simple voice if no DisplayServer support
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			# In Godot, tts_speak requires at least text and voice ID
			DisplayServer.tts_speak(text, selected_voice_id, speech_rate, speech_volume, speech_pitch)
			speech_started.emit()
			return true
		
		return false

func stop_speaking():
	if !tts_available:
		return
		
	if is_web_platform:
		JavaScriptBridge.eval("window.godotWebTTS.stop()")
	else:
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			DisplayServer.tts_stop()
	
	speech_ended.emit()
