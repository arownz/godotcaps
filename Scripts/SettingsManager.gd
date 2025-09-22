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
		"tts_volume": 100
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
	apply_audio_settings()
	
	# Ensure button audio uses SFX bus after a frame (so scene is loaded)
	call_deferred("_ensure_button_audio_uses_sfx_bus")
	
	# Reapply audio settings after all nodes are ready to ensure proper initialization
	call_deferred("_reapply_audio_settings_after_initialization")

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
			current_settings.accessibility.tts_volume = config.get_value("accessibility", "tts_volume", 100)
		
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
	config.set_value("accessibility", "tts_volume", current_settings.accessibility.tts_volume)
	
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
				"tts_volume":
					apply_tts_volume_globally(value)
		"audio":
			match setting:
				"master_volume":
					apply_master_volume(value)
				"sfx_volume":
					apply_sfx_volume(value)
				"music_volume":
					apply_music_volume(value)
		"gameplay":
			pass # Gameplay settings don't need immediate application

func apply_accessibility_settings():
	"""Apply all accessibility settings"""
	apply_reading_speed_globally(current_settings.accessibility.reading_speed)
	apply_tts_volume_globally(current_settings.accessibility.tts_volume)

func apply_audio_settings():
	"""Apply all audio settings"""
	apply_master_volume(current_settings.audio.master_volume)
	apply_sfx_volume(current_settings.audio.sfx_volume)
	apply_music_volume(current_settings.audio.music_volume)

func apply_reading_speed_globally(speed: float):
	"""Apply reading speed setting globally"""
	print("SettingsManager: Applying reading speed: ", speed)
	# This affects text animation speeds, typewriter effects, etc.

func apply_tts_volume_globally(volume: int):
	"""Apply TTS volume setting globally to all active TTS instances"""
	print("SettingsManager: Applying TTS volume: ", volume)
	# Signal all TTS instances to update their volume
	var tts_nodes = get_tree().get_nodes_in_group("tts_instances")
	for tts_node in tts_nodes:
		if tts_node.has_method("set_volume"):
			tts_node.set_volume(volume / 100.0)

func apply_animation_reduction_globally(enabled: bool):
	"""Apply animation reduction setting globally"""
	print("SettingsManager: Applying animation reduction: ", enabled)
	# This would disable or reduce UI animations for users with motion sensitivity

func apply_master_volume(volume: int):
	"""Apply master volume setting"""
	print("SettingsManager: Applying master volume: ", volume)
	var volume_db = linear_to_db(volume / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_db)

func apply_sfx_volume(volume: int):
	"""Apply SFX volume setting"""
	print("SettingsManager: Applying SFX volume: ", volume)
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index >= 0:
		var volume_db = linear_to_db(volume / 100.0)
		AudioServer.set_bus_volume_db(sfx_bus_index, volume_db)
	else:
		print("SettingsManager: SFX bus not found, creating it")
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "SFX")
		var volume_db = linear_to_db(volume / 100.0)
		AudioServer.set_bus_volume_db(1, volume_db)
	
	# Apply SFX bus to all existing button audio players that might not have it set
	_ensure_button_audio_uses_sfx_bus()

func apply_music_volume(volume: int):
	"""Apply music volume setting"""
	print("SettingsManager: Applying music volume: ", volume)
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index >= 0:
		var volume_db = linear_to_db(volume / 100.0)
		AudioServer.set_bus_volume_db(music_bus_index, volume_db)
	else:
		print("SettingsManager: Music bus not found, creating it")
		AudioServer.add_bus(2)
		AudioServer.set_bus_name(2, "Music")
		var volume_db = linear_to_db(volume / 100.0)
		AudioServer.set_bus_volume_db(2, volume_db)
	
	# Also notify BackgroundMusicManager if it exists
	var music_manager = get_node_or_null("/root/BackgroundMusicManager")
	if music_manager and music_manager.has_method("set_music_volume"):
		music_manager.set_music_volume(volume / 100.0)

func _ensure_button_audio_uses_sfx_bus():
	"""Ensure all button audio players use the SFX bus"""
	var root = get_tree().current_scene
	if root:
		var button_audio_nodes = []
		_find_button_audio_recursive(root, button_audio_nodes)
		
		for audio_node in button_audio_nodes:
			if audio_node.bus != "SFX":
				audio_node.bus = "SFX"
				print("SettingsManager: Set ", audio_node.name, " to use SFX bus")

func _find_button_audio_recursive(node: Node, result_array: Array):
	"""Recursively find ButtonClick and ButtonHover audio nodes"""
	if node is AudioStreamPlayer and (node.name == "ButtonClick" or node.name == "ButtonHover"):
		result_array.append(node)
	
	for child in node.get_children():
		_find_button_audio_recursive(child, result_array)

func _reapply_audio_settings_after_initialization():
	"""Reapply all audio settings after all components are initialized"""
	print("SettingsManager: Reapplying audio settings after initialization")
	apply_audio_settings()
	
	# Specifically ensure BackgroundMusicManager gets the current volume
	var music_manager = get_node_or_null("/root/BackgroundMusicManager")
	if music_manager and music_manager.has_method("set_music_volume"):
		var music_volume = current_settings.audio.music_volume
		music_manager.set_music_volume(music_volume / 100.0)
		print("SettingsManager: Applied music volume to BackgroundMusicManager: ", music_volume, "%")

func get_reading_speed() -> float:
	return current_settings.accessibility.reading_speed

func get_tts_voice_id() -> String:
	return current_settings.accessibility.tts_voice_id

func get_tts_rate() -> float:
	return current_settings.accessibility.tts_rate

func get_tts_volume() -> int:
	return current_settings.accessibility.tts_volume

func set_tts_voice_id(voice_id: String):
	set_setting("accessibility", "tts_voice_id", voice_id)

func set_tts_rate(rate: float):
	set_setting("accessibility", "tts_rate", rate)

func set_tts_volume(volume: int):
	set_setting("accessibility", "tts_volume", volume)

func should_show_tutorials() -> bool:
	return current_settings.gameplay.show_tutorials

func debug_audio_settings():
	"""Debug function to print current audio settings and bus volumes"""
	print("=== AUDIO SETTINGS DEBUG ===")
	print("Settings values:")
	print("- Master Volume: ", current_settings.audio.master_volume, "%")
	print("- SFX Volume: ", current_settings.audio.sfx_volume, "%")
	print("- Music Volume: ", current_settings.audio.music_volume, "%")
	
	print("Audio bus volumes:")
	var master_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	print("- Master Bus: ", db_to_linear(master_db) * 100, "% (", master_db, " dB)")
	
	var sfx_index = AudioServer.get_bus_index("SFX")
	if sfx_index >= 0:
		var sfx_db = AudioServer.get_bus_volume_db(sfx_index)
		print("- SFX Bus: ", db_to_linear(sfx_db) * 100, "% (", sfx_db, " dB)")
	else:
		print("- SFX Bus: Not found")
	
	var music_index = AudioServer.get_bus_index("Music")
	if music_index >= 0:
		var music_db = AudioServer.get_bus_volume_db(music_index)
		print("- Music Bus: ", db_to_linear(music_db) * 100, "% (", music_db, " dB)")
	else:
		print("- Music Bus: Not found")
	
	var music_manager = get_node_or_null("/root/BackgroundMusicManager")
	if music_manager:
		print("- BackgroundMusicManager: Found")
		if music_manager.has_method("set_music_volume"):
			print("  - set_music_volume method: Available")
		else:
			print("  - set_music_volume method: Not available")
	else:
		print("- BackgroundMusicManager: Not found")
	print("=== END AUDIO DEBUG ===")
