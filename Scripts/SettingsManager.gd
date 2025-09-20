extends Node

# SettingsManager - Global settings handler for dyslexia-friendly features
# This singleton manages and applies settings across all scenes

signal settings_changed(setting_category: String, setting_name: String, value)

# Settings file path
const SETTINGS_FILE_PATH = "user://settings.cfg"

# Current settings data
var current_settings = {
	"accessibility": {
		"reading_speed": 1.0,
		# Added TTS related defaults so retrieval never returns null
		"tts_voice_id": "default",
		"tts_rate": 1.0,
	},
	"audio": {
		"master_volume": 75,
		"sfx_volume": 80,
		"music_volume": 60
	},
	"gameplay": {
		"show_tutorials": true
	}
}

func _ready():
	print("SettingsManager: Initializing global settings manager")
	load_settings()
	apply_accessibility_settings()

func load_settings():
	"""Load settings from config file"""
	print("SettingsManager: Loading settings from file")
	
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	
	if err == OK:
		print("SettingsManager: Settings file found, loading saved settings")
		# Load accessibility settings
		if config.has_section("accessibility"):
			current_settings.accessibility.reading_speed = config.get_value("accessibility", "reading_speed", 1.0)
			current_settings.accessibility.tts_voice_id = config.get_value("accessibility", "tts_voice_id", "default")
			current_settings.accessibility.tts_rate = config.get_value("accessibility", "tts_rate", 1.0)
		
		# Load audio settings
		if config.has_section("audio"):
			current_settings.audio.master_volume = config.get_value("audio", "master_volume", 75)
			current_settings.audio.sfx_volume = config.get_value("audio", "sfx_volume", 80)
			current_settings.audio.music_volume = config.get_value("audio", "music_volume", 60)
		
		# Load gameplay settings
		if config.has_section("gameplay"):
			current_settings.gameplay.show_tutorials = config.get_value("gameplay", "show_tutorials", true)
		
		print("SettingsManager: Settings loaded successfully")
	else:
		print("SettingsManager: No settings file found, using defaults")
		save_settings()

func save_settings():
	"""Save current settings to config file"""
	print("SettingsManager: Saving settings to file")
	
	var config = ConfigFile.new()
	
	# Save accessibility settings
	config.set_value("accessibility", "reading_speed", current_settings.accessibility.reading_speed)
	config.set_value("accessibility", "tts_voice_id", current_settings.accessibility.tts_voice_id)
	config.set_value("accessibility", "tts_rate", current_settings.accessibility.tts_rate)
	
	# Save audio settings
	config.set_value("audio", "master_volume", current_settings.audio.master_volume)
	config.set_value("audio", "sfx_volume", current_settings.audio.sfx_volume)
	config.set_value("audio", "music_volume", current_settings.audio.music_volume)
	
	# Save gameplay settings
	config.set_value("gameplay", "show_tutorials", current_settings.gameplay.show_tutorials)
	
	# Save to file
	var err = config.save(SETTINGS_FILE_PATH)
	if err == OK:
		print("SettingsManager: Settings saved successfully")
	else:
		print("SettingsManager: Error saving settings: ", err)

func get_setting(category: String, setting: String):
	"""Get a specific setting value"""
	if current_settings.has(category) and current_settings[category].has(setting):
		return current_settings[category][setting]
	return null

func set_setting(category: String, setting: String, value):
	"""Set a specific setting value and save"""
	if not current_settings.has(category):
		current_settings[category] = {}
	
	current_settings[category][setting] = value
	save_settings()
	
	# Apply the setting immediately
	apply_setting(category, setting, value)
	
	# Emit signal for other systems to react
	settings_changed.emit(category, setting, value)
	
	print("SettingsManager: Setting updated - ", category, ".", setting, " = ", value)

func apply_setting(category: String, setting: String, value):
	"""Apply a specific setting immediately"""
	match category:
		"accessibility":
			match setting:
				"reading_speed":
					apply_reading_speed_globally(value)
		"audio":
			match setting:
				"master_volume":
					apply_master_volume(value)
				"sfx_volume":
					apply_sfx_volume(value)
				"music_volume":
					apply_music_volume(value)
		"gameplay":
			# Gameplay settings are usually applied by individual scenes
			pass

func apply_accessibility_settings():
	"""Apply all accessibility settings"""
	apply_reading_speed_globally(current_settings.accessibility.reading_speed)

func apply_reading_speed_globally(speed: float):
	"""Apply reading speed setting globally"""
	print("SettingsManager: Applying reading speed: ", speed)
	# This affects text animation speeds, typewriter effects, etc.

func apply_animation_reduction_globally(enabled: bool):
	"""Apply animation reduction setting globally"""
	print("SettingsManager: Applying animation reduction: ", enabled)
	# This would disable or reduce UI animations for users with motion sensitivity

func apply_master_volume(volume: int):
	"""Apply master volume setting"""
	print("SettingsManager: Applying master volume: ", volume)
	# TODO: Implement when audio system is added
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume / 100.0))

func apply_sfx_volume(volume: int):
	"""Apply SFX volume setting"""
	print("SettingsManager: Applying SFX volume: ", volume)
	# TODO: Implement when audio system is added

func apply_music_volume(volume: int):
	"""Apply music volume setting"""
	print("SettingsManager: Applying music volume: ", volume)
	# TODO: Implement when audio system is added

func get_reading_speed() -> float:
	return current_settings.accessibility.reading_speed

func get_tts_voice_id() -> String:
	return current_settings.accessibility.tts_voice_id

func get_tts_rate() -> float:
	return current_settings.accessibility.tts_rate

func set_tts_voice_id(voice_id: String):
	set_setting("accessibility", "tts_voice_id", voice_id)

func set_tts_rate(rate: float):
	set_setting("accessibility", "tts_rate", rate)

func should_show_tutorials() -> bool:
	return current_settings.gameplay.show_tutorials
