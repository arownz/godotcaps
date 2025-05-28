extends Control

# UI References
@onready var back_button = $MainContainer/VBoxContainer/HeaderContainer/BackButton

# Accessibility Settings
@onready var font_size_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/FontSizeContainer/FontSizeSlider
@onready var font_size_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/FontSizeContainer/FontSizeValue
@onready var reading_speed_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/ReadingSpeedContainer/ReadingSpeedSlider
@onready var reading_speed_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/ReadingSpeedContainer/ReadingSpeedValue
@onready var high_contrast_toggle = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/HighContrastContainer/HighContrastToggle
@onready var animation_toggle = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/AnimationContainer/AnimationToggle

# Audio Settings (disabled for now)
@onready var master_volume_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MasterVolumeContainer/MasterVolumeValue
@onready var sfx_volume_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/SFXVolumeContainer/SFXVolumeSlider
@onready var sfx_volume_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/SFXVolumeContainer/SFXVolumeValue
@onready var music_volume_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MusicVolumeContainer/MusicVolumeValue

# Gameplay Settings
@onready var difficulty_option = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/GameplaySection/DifficultyContainer/DifficultyOption
@onready var auto_save_toggle = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/GameplaySection/AutoSaveContainer/AutoSaveToggle
@onready var tutorials_toggle = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/GameplaySection/TutorialsContainer/TutorialsToggle

# Data Settings
@onready var reset_progress_button = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/DataSection/ResetProgressButton
@onready var export_data_button = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/DataSection/ExportDataButton

func _ready():
	print("SettingScene: Initializing settings screen")
	
	# Connect button signals
	back_button.pressed.connect(_on_back_button_pressed)
	reset_progress_button.pressed.connect(_on_reset_progress_button_pressed)
	export_data_button.pressed.connect(_on_export_data_button_pressed)
	
	# Connect accessibility settings
	font_size_slider.value_changed.connect(_on_font_size_changed)
	reading_speed_slider.value_changed.connect(_on_reading_speed_changed)
	high_contrast_toggle.toggled.connect(_on_high_contrast_toggled)
	animation_toggle.toggled.connect(_on_animation_toggle_toggled)
	
	# Connect audio settings (disabled but connected for future use)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	
	# Connect gameplay settings
	difficulty_option.item_selected.connect(_on_difficulty_selected)
	auto_save_toggle.toggled.connect(_on_auto_save_toggled)
	tutorials_toggle.toggled.connect(_on_tutorials_toggled)
	
	# Setup difficulty options
	setup_difficulty_options()
	
	# Update UI from global settings
	update_ui_from_settings()

func setup_difficulty_options():
	"""Setup the difficulty dropdown options"""
	difficulty_option.clear()
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Normal")
	difficulty_option.add_item("Hard")
	difficulty_option.selected = 1  # Default to Normal

func update_ui_from_settings():
	"""Update UI elements to reflect current settings from SettingsManager"""
	# Accessibility settings
	font_size_slider.value = SettingsManager.get_setting("accessibility", "font_size")
	font_size_value.text = str(int(SettingsManager.get_setting("accessibility", "font_size")))
	
	reading_speed_slider.value = SettingsManager.get_setting("accessibility", "reading_speed")
	reading_speed_value.text = str(SettingsManager.get_setting("accessibility", "reading_speed")) + "x"
	
	high_contrast_toggle.button_pressed = SettingsManager.get_setting("accessibility", "high_contrast")
	animation_toggle.button_pressed = SettingsManager.get_setting("accessibility", "reduce_animations")
	
	# Audio settings (disabled)
	master_volume_slider.value = SettingsManager.get_setting("audio", "master_volume")
	master_volume_value.text = str(SettingsManager.get_setting("audio", "master_volume")) + "%"
	
	sfx_volume_slider.value = SettingsManager.get_setting("audio", "sfx_volume")
	sfx_volume_value.text = str(SettingsManager.get_setting("audio", "sfx_volume")) + "%"
	
	music_volume_slider.value = SettingsManager.get_setting("audio", "music_volume")
	music_volume_value.text = str(SettingsManager.get_setting("audio", "music_volume")) + "%"
	
	# Gameplay settings
	var difficulty = SettingsManager.get_setting("gameplay", "difficulty")
	var difficulty_index = 1  # Default to Normal
	match difficulty:
		"Easy":
			difficulty_index = 0
		"Normal":
			difficulty_index = 1
		"Hard":
			difficulty_index = 2
	difficulty_option.selected = difficulty_index
	
	auto_save_toggle.button_pressed = SettingsManager.get_setting("gameplay", "auto_save")
	tutorials_toggle.button_pressed = SettingsManager.get_setting("gameplay", "show_tutorials")

# ===== Signal Handlers =====

func _on_back_button_pressed():
	"""Return to main menu"""
	print("SettingScene: Back button pressed")
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

# === Accessibility Settings ===

func _on_font_size_changed(value: float):
	"""Handle font size slider change"""
	SettingsManager.set_setting("accessibility", "font_size", int(value))
	font_size_value.text = str(int(value))
	print("SettingScene: Font size changed to: ", int(value))

func _on_reading_speed_changed(value: float):
	"""Handle reading speed slider change"""
	SettingsManager.set_setting("accessibility", "reading_speed", value)
	reading_speed_value.text = str(value) + "x"
	print("SettingScene: Reading speed changed to: ", value)

func _on_high_contrast_toggled(pressed: bool):
	"""Handle high contrast mode toggle"""
	SettingsManager.set_setting("accessibility", "high_contrast", pressed)
	print("SettingScene: High contrast mode: ", pressed)

func _on_animation_toggle_toggled(pressed: bool):
	"""Handle reduce animations toggle"""
	SettingsManager.set_setting("accessibility", "reduce_animations", pressed)
	print("SettingScene: Reduce animations: ", pressed)

# === Audio Settings (for future implementation) ===

func _on_master_volume_changed(value: float):
	"""Handle master volume slider change"""
	SettingsManager.set_setting("audio", "master_volume", int(value))
	master_volume_value.text = str(int(value)) + "%"
	print("SettingScene: Master volume changed to: ", int(value))

func _on_sfx_volume_changed(value: float):
	"""Handle SFX volume slider change"""
	SettingsManager.set_setting("audio", "sfx_volume", int(value))
	sfx_volume_value.text = str(int(value)) + "%"
	print("SettingScene: SFX volume changed to: ", int(value))

func _on_music_volume_changed(value: float):
	"""Handle music volume slider change"""
	SettingsManager.set_setting("audio", "music_volume", int(value))
	music_volume_value.text = str(int(value)) + "%"
	print("SettingScene: Music volume changed to: ", int(value))

# === Gameplay Settings ===

func _on_difficulty_selected(index: int):
	"""Handle difficulty selection"""
	var difficulties = ["Easy", "Normal", "Hard"]
	SettingsManager.set_setting("gameplay", "difficulty", difficulties[index])
	print("SettingScene: Difficulty changed to: ", difficulties[index])

func _on_auto_save_toggled(pressed: bool):
	"""Handle auto save toggle"""
	SettingsManager.set_setting("gameplay", "auto_save", pressed)
	print("SettingScene: Auto save: ", pressed)

func _on_tutorials_toggled(pressed: bool):
	"""Handle tutorials toggle"""
	SettingsManager.set_setting("gameplay", "show_tutorials", pressed)
	print("SettingScene: Show tutorials: ", pressed)

# === Data Management ===

func _on_reset_progress_button_pressed():
	"""Handle reset progress button"""
	print("SettingScene: Reset progress button pressed")
	
	# Create confirmation dialog
	var confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.dialog_text = "Are you sure you want to reset ALL game progress?\n\nThis will:\n• Reset your level to 1\n• Clear all dungeon progress\n• Reset all statistics\n• Remove completed challenges\n\nThis action CANNOT be undone!"
	confirmation_dialog.title = "Reset Game Progress"
	add_child(confirmation_dialog)
	confirmation_dialog.popup_centered()
	
	# Wait for user response
	await confirmation_dialog.confirmed
	confirmation_dialog.queue_free()
	
	print("SettingScene: User confirmed progress reset - proceeding...")
	await _perform_progress_reset()

func _perform_progress_reset():
	"""Actually perform the progress reset"""
	if !Firebase.Auth.auth:
		print("SettingScene: No authentication, cannot reset Firebase data")
		_show_reset_result(false, "Not authenticated - cannot reset online progress")
		return
	
	print("SettingScene: Performing Firebase data reset...")
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document first to preserve profile info
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		print("SettingScene: Current document retrieved, resetting game data...")
		
		# Preserve profile information but reset everything else
		var profile_data = document.get_value("profile")
		if !profile_data:
			profile_data = {
				"username": "Player",
				"email": "",
				"profile_picture": "default",
				"rank": "bronze"
			}
		
		# Create fresh game data structure
		var reset_data = {
			"profile": profile_data,
			"stats": {
				"player": {
					"level": 1,
					"exp": 0,
					"health": 100,
					"damage": 10,
					"durability": 5,
					"energy": 20,
					"skin": "res://Sprites/Animation/DefaultPlayer_Animation.tscn",
					"last_energy_update": Time.get_unix_time_from_system()
				}
			},
			"word_challenges": {
				"completed": {
					"stt": 0,
					"whiteboard": 0
				},
				"failed": {
					"stt": 0,
					"whiteboard": 0
				}
			},
			"dungeons": {
				"completed": {
					"1": {"completed": false, "stages_completed": 0},
					"2": {"completed": false, "stages_completed": 0},
					"3": {"completed": false, "stages_completed": 0}
				},
				"progress": {
					"enemies_defeated": 0,
					"current_dungeon": 1,
					"current_stage": 1
				}
			}
		}
		
		# Update the document with reset data
		var updated_document = await collection.add(user_id, reset_data)
		if updated_document:
			print("SettingScene: Progress reset successful!")
			_show_reset_result(true, "Game progress has been reset successfully!\n\nPlease restart the game to apply changes.")
		else:
			print("SettingScene: Failed to reset progress in Firebase")
			_show_reset_result(false, "Failed to reset progress - please try again later")
	else:
		print("SettingScene: Failed to get user document for reset")
		_show_reset_result(false, "Failed to access user data - please try again later")

func _show_reset_result(success: bool, message: String):
	"""Show the result of the reset operation"""
	var result_dialog = AcceptDialog.new()
	result_dialog.dialog_text = message
	result_dialog.title = "Reset Progress" if success else "Reset Failed"
	add_child(result_dialog)
	result_dialog.popup_centered()
	
	await result_dialog.confirmed
	result_dialog.queue_free()
	
	if success:
		# Optional: Return to main menu or restart game
		print("SettingScene: Reset completed - user should restart game")
		# get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_export_data_button_pressed():
	"""Handle export data button"""
	print("SettingScene: Export data button pressed")
	
	# Show info dialog
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Data export functionality will be available in a future update."
	dialog.title = "Export Data"
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	dialog.queue_free()
	
	# TODO: Implement actual data export when needed
