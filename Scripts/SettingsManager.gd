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
	_setup_audio_bus_hierarchy()
	load_settings()
	apply_accessibility_settings()
	apply_audio_settings()
	
	# Debug initial state
	print("SettingsManager: Initial audio setup complete")
	debug_audio_settings()
	
	# Ensure button audio uses SFX bus after a frame (so scene is loaded)
	call_deferred("_ensure_button_audio_uses_sfx_bus")
	
	# Reapply audio settings after all nodes are ready to ensure proper initialization
	call_deferred("_reapply_audio_settings_after_initialization")
	
	# Also force audio check after a longer delay to catch late-loaded nodes
	call_deferred("_delayed_audio_check")

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

func _setup_audio_bus_hierarchy():
	"""Setup audio buses - SFX and Music as independent buses for web compatibility"""
	print("SettingsManager: Setting up audio bus hierarchy")
	
	# Ensure SFX bus exists
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index < 0:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "SFX")
		sfx_bus_index = 1
		print("SettingsManager: Created SFX bus at index ", sfx_bus_index)
	
	# Ensure Music bus exists
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index < 0:
		AudioServer.add_bus(2)
		AudioServer.set_bus_name(2, "Music")
		music_bus_index = 2
		print("SettingsManager: Created Music bus at index ", music_bus_index)
	
	print("SettingsManager: Audio bus setup complete - SFX and Music as independent buses")

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
	"""Apply master volume setting by affecting all audio buses"""
	print("SettingsManager: Applying master volume: ", volume)
	var master_db = linear_to_db(volume / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
	
	# For web compatibility, also apply master volume as a multiplier to other buses
	var master_multiplier = volume / 100.0
	
	# Apply to SFX bus
	var sfx_volume = current_settings.audio.sfx_volume
	var sfx_final = sfx_volume * master_multiplier
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index >= 0:
		var sfx_db = linear_to_db(sfx_final / 100.0)
		AudioServer.set_bus_volume_db(sfx_bus_index, sfx_db)
		print("SettingsManager: Applied master to SFX - ", sfx_volume, "% * ", volume, "% = ", sfx_final, "%")
	
	# For Music, notify BackgroundMusicManager to recalculate with new master volume
	var music_manager = get_node_or_null("/root/BackgroundMusicManager")
	if music_manager and music_manager.has_method("set_music_volume"):
		var music_volume = current_settings.audio.music_volume
		music_manager.set_music_volume(music_volume / 100.0)
		print("SettingsManager: Applied master volume change to BackgroundMusicManager")

func apply_sfx_volume(volume: int):
	"""Apply SFX volume setting with master volume consideration"""
	print("SettingsManager: Applying SFX volume: ", volume)
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index >= 0:
		# Apply master volume multiplier for web compatibility
		var master_volume = current_settings.audio.master_volume
		var final_volume = volume * (master_volume / 100.0)
		var volume_db = linear_to_db(final_volume / 100.0)
		AudioServer.set_bus_volume_db(sfx_bus_index, volume_db)
		print("SettingsManager: SFX final volume: ", volume, "% * ", master_volume, "% = ", final_volume, "%")
	else:
		print("SettingsManager: SFX bus not found, creating it")
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "SFX")
		var master_volume = current_settings.audio.master_volume
		var final_volume = volume * (master_volume / 100.0)
		var volume_db = linear_to_db(final_volume / 100.0)
		AudioServer.set_bus_volume_db(1, volume_db)
	
	# Apply SFX bus to all existing button audio players that might not have it set
	_ensure_button_audio_uses_sfx_bus()

func apply_music_volume(volume: int):
	"""Apply music volume setting - only affects BackgroundMusicManager, not SFX"""
	print("SettingsManager: Applying music volume: ", volume, "% (BackgroundMusicManager only)")
	
	# Only notify BackgroundMusicManager - do NOT touch AudioServer Music bus
	# This prevents music volume from interfering with any audio routing
	var music_manager = get_node_or_null("/root/BackgroundMusicManager")
	if music_manager and music_manager.has_method("set_music_volume"):
		# BackgroundMusicManager handles its own volume control independently
		music_manager.set_music_volume(volume / 100.0)
		print("SettingsManager: Music volume applied to BackgroundMusicManager: ", volume, "%")
	else:
		print("SettingsManager: BackgroundMusicManager not found - music volume not applied")
	
	# Ensure SFX bus assignment is correct after any audio setting change
	call_deferred("_ensure_all_sfx_audio_uses_correct_bus")
	print("SettingsManager: Music volume changed - SFX audio routing verified")

func _ensure_button_audio_uses_sfx_bus():
	"""Ensure all button audio players use the SFX bus"""
	var root = get_tree().current_scene
	if root:
		var button_audio_nodes = []
		_find_button_audio_recursive(root, button_audio_nodes)
		
		for audio_node in button_audio_nodes:
			if audio_node.bus != "SFX":
				print("SettingsManager: Found ", audio_node.name, " using bus '", audio_node.bus, "', changing to SFX")
				audio_node.bus = "SFX"
			else:
				print("SettingsManager: ", audio_node.name, " already using SFX bus")
	
	# Also check all canvas layers (like settings popups)
	var canvas_layers = get_tree().get_nodes_in_group("settings_popups")
	for layer in canvas_layers:
		var popup_audio_nodes = []
		_find_button_audio_recursive(layer, popup_audio_nodes)
		for audio_node in popup_audio_nodes:
			if audio_node.bus != "SFX":
				print("SettingsManager: Found popup ", audio_node.name, " using bus '", audio_node.bus, "', changing to SFX")
				audio_node.bus = "SFX"
			else:
				print("SettingsManager: Popup ", audio_node.name, " already using SFX bus")
	
	# Also scan for any other audio players that should use SFX
	_ensure_all_sfx_audio_uses_correct_bus()

func _ensure_all_sfx_audio_uses_correct_bus():
	"""Find and fix any AudioStreamPlayer that should be using SFX bus"""
	var all_audio_players = get_tree().get_nodes_in_group("audio_players")
	if all_audio_players.is_empty():
		# If no group exists, scan manually
		var root = get_tree().current_scene
		if root:
			var all_players = []
			_find_all_audio_players_recursive(root, all_players)
			for player in all_players:
				if player is AudioStreamPlayer:
					# Check if it's likely an SFX sound (not background music)
					var node_name = player.name.to_lower()
					if ("button" in node_name or "click" in node_name or "hover" in node_name or
						"sfx" in node_name or "sound" in node_name or "audio" in node_name or
						"attack" in node_name or "hurt" in node_name or "skill" in node_name or
						"counter" in node_name or "swordslash" in node_name or "player" in node_name or
						"enemy" in node_name or "celebration" in node_name or "notification" in node_name or
						"boar" in node_name or "slime" in node_name or "snake" in node_name or
						"treant" in node_name or "autoattack" in node_name or "dead" in node_name):
						if player.bus != "SFX":
							print("SettingsManager: Found SFX audio '", player.name, "' using bus '", player.bus, "', changing to SFX")
							player.bus = "SFX"
						else:
							print("SettingsManager: SFX audio '", player.name, "' already using SFX bus")
					elif player.name.to_lower() == "backgroundmusicplayer":
						# Ensure background music uses Music bus
						if player.bus != "Music":
							print("SettingsManager: Found background music using bus '", player.bus, "', changing to Music")
							player.bus = "Music"

func _find_all_audio_players_recursive(node: Node, result_array: Array):
	"""Recursively find all AudioStreamPlayer nodes"""
	if node is AudioStreamPlayer:
		result_array.append(node)
	
	for child in node.get_children():
		_find_all_audio_players_recursive(child, result_array)

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
	
	# Specifically ensure BackgroundMusicManager gets the current volume with master consideration
	var music_manager = get_node_or_null("/root/BackgroundMusicManager")
	if music_manager and music_manager.has_method("set_music_volume"):
		var music_volume = current_settings.audio.music_volume
		music_manager.set_music_volume(music_volume / 100.0)
		print("SettingsManager: Applied music volume to BackgroundMusicManager: ", music_volume, "% (with master volume consideration)")
	
	# Ensure all SFX audio is properly routed
	call_deferred("_ensure_all_sfx_audio_uses_correct_bus")

func _delayed_audio_check():
	"""Delayed audio check to catch any late-loaded audio nodes"""
	await get_tree().create_timer(1.0).timeout
	print("SettingsManager: Running delayed audio bus check...")
	_ensure_button_audio_uses_sfx_bus()
	debug_audio_settings()

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
