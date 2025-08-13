extends Node

# SettingsManager - Global settings handler for dyslexia-friendly features
# This singleton manages and applies settings across all scenes

signal settings_changed(setting_category: String, setting_name: String, value)

# Settings file path
const SETTINGS_FILE_PATH = "user://settings.cfg"

# Current settings data
var current_settings = {
	"accessibility": {
		"font_size": 18,
		"reading_speed": 1.0,
		"high_contrast": false,
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
			current_settings.accessibility.font_size = config.get_value("accessibility", "font_size", 18)
			current_settings.accessibility.reading_speed = config.get_value("accessibility", "reading_speed", 1.0)
			current_settings.accessibility.high_contrast = config.get_value("accessibility", "high_contrast", false)
			current_settings.accessibility.reduce_animations = config.get_value("accessibility", "reduce_animations", false)
		
		# Load audio settings
		if config.has_section("audio"):
			current_settings.audio.master_volume = config.get_value("audio", "master_volume", 75)
			current_settings.audio.sfx_volume = config.get_value("audio", "sfx_volume", 80)
			current_settings.audio.music_volume = config.get_value("audio", "music_volume", 60)
		
		# Load gameplay settings
		if config.has_section("gameplay"):
			current_settings.gameplay.difficulty = config.get_value("gameplay", "difficulty", "Normal")
			current_settings.gameplay.auto_save = config.get_value("gameplay", "auto_save", true)
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
	config.set_value("accessibility", "font_size", current_settings.accessibility.font_size)
	config.set_value("accessibility", "reading_speed", current_settings.accessibility.reading_speed)
	config.set_value("accessibility", "high_contrast", current_settings.accessibility.high_contrast)
	config.set_value("accessibility", "reduce_animations", current_settings.accessibility.reduce_animations)
	
	# Save audio settings
	config.set_value("audio", "master_volume", current_settings.audio.master_volume)
	config.set_value("audio", "sfx_volume", current_settings.audio.sfx_volume)
	config.set_value("audio", "music_volume", current_settings.audio.music_volume)
	
	# Save gameplay settings
	config.set_value("gameplay", "difficulty", current_settings.gameplay.difficulty)
	config.set_value("gameplay", "auto_save", current_settings.gameplay.auto_save)
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
				"font_size":
					apply_font_size_globally(value)
				"reading_speed":
					apply_reading_speed_globally(value)
				"high_contrast":
					apply_high_contrast_globally(value)
				"reduce_animations":
					apply_animation_reduction_globally(value)
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
	apply_font_size_globally(current_settings.accessibility.font_size)
	apply_reading_speed_globally(current_settings.accessibility.reading_speed)
	apply_high_contrast_globally(current_settings.accessibility.high_contrast)
	apply_animation_reduction_globally(current_settings.accessibility.reduce_animations)

func apply_font_size_globally(font_size: int):
	"""Apply font size setting to current scene"""
	print("SettingsManager: Applying font size: ", font_size)
	# This would need to be implemented to update all text elements in the current scene
	# For now, scenes will need to query this setting manually

func apply_reading_speed_globally(speed: float):
	"""Apply reading speed setting globally"""
	print("SettingsManager: Applying reading speed: ", speed)
	# This affects text animation speeds, typewriter effects, etc.

func apply_high_contrast_globally(enabled: bool):
	"""Apply high contrast setting globally"""
	print("SettingsManager: Applying high contrast: ", enabled)
	# This would modify color schemes throughout the UI

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

# Utility functions for other scenes to check settings
func is_high_contrast_enabled() -> bool:
	return current_settings.accessibility.high_contrast

func is_animation_reduction_enabled() -> bool:
	return current_settings.accessibility.reduce_animations

func get_reading_speed() -> float:
	return current_settings.accessibility.reading_speed

func get_font_size() -> int:
	return current_settings.accessibility.font_size

func should_show_tutorials() -> bool:
	return current_settings.gameplay.show_tutorials

func is_auto_save_enabled() -> bool:
	return current_settings.gameplay.auto_save

func get_difficulty() -> String:
	return current_settings.gameplay.difficulty
