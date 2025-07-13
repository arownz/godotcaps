extends Control

# UI References
@onready var back_button = $MainContainer/VBoxContainer/HeaderContainer/BackButton

# Accessibility Settings
@onready var font_size_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/FontSizeContainer/FontSizeSlider
@onready var font_size_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/FontSizeContainer/FontSizeValue
@onready var reading_speed_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/ReadingSpeedContainer/ReadingSpeedSlider
@onready var reading_speed_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/ReadingSpeedContainer/ReadingSpeedValue
@onready var high_contrast_toggle = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/HighContrastContainer/HighContrastToggle

# Audio Settings (disabled for now)
@onready var master_volume_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MasterVolumeContainer/MasterVolumeValue
@onready var sfx_volume_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/SFXVolumeContainer/SFXVolumeSlider
@onready var sfx_volume_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/SFXVolumeContainer/SFXVolumeValue
@onready var music_volume_slider = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_value = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MusicVolumeContainer/MusicVolumeValue

# Gameplay Settings
@onready var auto_save_toggle = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/GameplaySection/AutoSaveContainer/AutoSaveToggle
@onready var tutorials_toggle = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/GameplaySection/TutorialsContainer/TutorialsToggle

# Data Settings
@onready var export_data_button = $MainContainer/VBoxContainer/SettingsPanel/SettingsContent/ScrollContainer/SettingsVBox/DataSection/ExportDataButton

func _ready():
	print("SettingScene: Initializing settings screen")
	
	# Connect button signals
	back_button.pressed.connect(_on_back_button_pressed)
	export_data_button.pressed.connect(_on_export_data_button_pressed)
	
	# Connect accessibility settings
	font_size_slider.value_changed.connect(_on_font_size_changed)
	reading_speed_slider.value_changed.connect(_on_reading_speed_changed)
	high_contrast_toggle.toggled.connect(_on_high_contrast_toggled)
	
	# Connect audio settings (disabled but connected for future use)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	
	# Connect gameplay setting
	tutorials_toggle.toggled.connect(_on_tutorials_toggled)
	
	
	# Update UI from global settings
	update_ui_from_settings()

func update_ui_from_settings():
	"""Update UI elements to reflect current settings from SettingsManager"""
	# Accessibility settings
	font_size_slider.value = SettingsManager.get_setting("accessibility", "font_size")
	font_size_value.text = str(int(SettingsManager.get_setting("accessibility", "font_size")))
	
	reading_speed_slider.value = SettingsManager.get_setting("accessibility", "reading_speed")
	reading_speed_value.text = str(SettingsManager.get_setting("accessibility", "reading_speed")) + "x"
	
	high_contrast_toggle.button_pressed = SettingsManager.get_setting("accessibility", "high_contrast")
	
	# Audio settings (disabled)
	master_volume_slider.value = SettingsManager.get_setting("audio", "master_volume")
	master_volume_value.text = str(SettingsManager.get_setting("audio", "master_volume")) + "%"
	
	sfx_volume_slider.value = SettingsManager.get_setting("audio", "sfx_volume")
	sfx_volume_value.text = str(SettingsManager.get_setting("audio", "sfx_volume")) + "%"
	
	music_volume_slider.value = SettingsManager.get_setting("audio", "music_volume")
	music_volume_value.text = str(SettingsManager.get_setting("audio", "music_volume")) + "%"
	
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

func _on_tutorials_toggled(pressed: bool):
	"""Handle tutorials toggle"""
	SettingsManager.set_setting("gameplay", "show_tutorials", pressed)
	print("SettingScene: Show tutorials: ", pressed)

# === Data Management ===
	
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
