extends CanvasLayer

signal engage_confirmed
signal quit_requested

# Controls whether battle buttons (Engage/Leave) are shown
var is_battle_context: bool = false
var energy_cost: int = 2
var _context_initialized: bool = false

# UI References
@onready var close_button = $SettingsContainer/CloseButton

# Accessibility Settings
@onready var font_size_slider = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/FontSizeContainer/FontSizeSlider
@onready var font_size_value = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/FontSizeContainer/FontSizeValue
@onready var reading_speed_slider = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/ReadingSpeedContainer/ReadingSpeedSlider
@onready var reading_speed_value = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/ReadingSpeedContainer/ReadingSpeedValue
@onready var high_contrast_toggle = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AccessibilitySection/HighContrastContainer/HighContrastToggle

# Audio Settings (disabled for now)
@onready var master_volume_slider = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_value = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MasterVolumeContainer/MasterVolumeValue
@onready var sfx_volume_slider = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/SFXVolumeContainer/SFXVolumeSlider
@onready var sfx_volume_value = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/SFXVolumeContainer/SFXVolumeValue
@onready var music_volume_slider = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_value = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/AudioSection/MusicVolumeContainer/MusicVolumeValue

# Gameplay Settings
@onready var tutorials_toggle = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/GameplaySection/TutorialsContainer/TutorialsToggle

# Data Settings
@onready var data_section = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/DataSection

# Battle Section (from TSCN)
@onready var battle_section = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/BattleSection
@onready var battle_separator = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/BattleSeparator
@onready var engage_button = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/BattleSection/BattleButtonContainer/EngageButton
@onready var leave_button = $SettingsContainer/SettingsContent/ScrollContainer/SettingsVBox/BattleSection/BattleButtonContainer/LeaveButton

func _ready():
	print("SettingScene: Initializing settings popup")
	# Ensure overlay
	layer = 100

	# Background click closes popup
	var bg = get_node_or_null("Background")
	if bg and not bg.gui_input.is_connected(_on_background_input):
		bg.gui_input.connect(_on_background_input)

	# Center main container (already centered in tscn) and animate
	var panel: Control = $SettingsContainer
	if panel:
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.8, 0.8)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Connect button signals (guarded)
	if close_button and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)
	# Note: DataSection/ExportDataButton is already connected in the .tscn file
    
	# Connect accessibility settings
	if font_size_slider and not font_size_slider.value_changed.is_connected(_on_font_size_changed):
		font_size_slider.value_changed.connect(_on_font_size_changed)
	if reading_speed_slider and not reading_speed_slider.value_changed.is_connected(_on_reading_speed_changed):
		reading_speed_slider.value_changed.connect(_on_reading_speed_changed)
	if high_contrast_toggle and not high_contrast_toggle.toggled.is_connected(_on_high_contrast_toggled):
		high_contrast_toggle.toggled.connect(_on_high_contrast_toggled)
    
	# Connect audio settings (future use)
	if master_volume_slider and not master_volume_slider.value_changed.is_connected(_on_master_volume_changed):
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if sfx_volume_slider and not sfx_volume_slider.value_changed.is_connected(_on_sfx_volume_changed):
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if music_volume_slider and not music_volume_slider.value_changed.is_connected(_on_music_volume_changed):
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
    
	# Gameplay setting
	if tutorials_toggle and not tutorials_toggle.toggled.is_connected(_on_tutorials_toggled):
		tutorials_toggle.toggled.connect(_on_tutorials_toggled)
    
	# Build battle buttons at top of SettingsContent
	# Note: Battle buttons are now designed in TSCN
	_set_battle_buttons_visible(is_battle_context)
	# Ensure export data visibility matches context immediately
	if data_section:
		data_section.visible = not is_battle_context
    
	# Update UI from global settings
	update_ui_from_settings()

	# Auto-detect context if not explicitly set
	if not _context_initialized:
		_detect_and_apply_context()

	# Make layout responsive to window size
	_update_layout()

func _notification(what):
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_layout()

func _update_layout():
	var container := $SettingsContainer as Control
	if container == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	# Compact popup size: smaller and more appropriate for settings
	var min_size := Vector2(480, 350)
	var max_size := Vector2(650, 500)
	var target := Vector2(580, 420) # Fixed compact size
	
	# Scale down for smaller screens
	if vp_size.x < 800 or vp_size.y < 600:
		target = vp_size * 0.85
		target.x = clamp(target.x, min_size.x, max_size.x)
		target.y = clamp(target.y, min_size.y, max_size.y)
	
	container.size = target
	# Center the container
	container.position = (vp_size - target) / 2.0

func _detect_and_apply_context():
	var scene := get_tree().current_scene
	if scene and scene.name == "BattleScene":
		is_battle_context = true
		# Try to reflect battle session state if available
		var has_battle: bool = scene.has_node(".") and ("battle_session_started" in scene) and scene.battle_session_started
		var is_active: bool = scene.has_node(".") and ("battle_active" in scene) and scene.battle_active
		_set_battle_buttons_visible(true)
		set_battle_session_state(has_battle, is_active)
		if data_section:
			data_section.visible = false
	else:
		is_battle_context = false
		_set_battle_buttons_visible(false)
		if data_section:
			data_section.visible = true
	_context_initialized = true

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

func _on_close_button_pressed():
	$ButtonClick.play()
	print("SettingScene: Close button pressed - closing popup")
	_close_popup()

func _on_close_button_mouse_entered() -> void:
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	print("SettingScene: Back button pressed - closing popup")
	_close_popup()

	# Helper function to fade out before changing scenes
func _fade_out_and_change_scene(_scene_path: String):
	# Deprecated in popup version
	_close_popup()

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
	$ButtonClick.play()
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


func _on_back_button_mouse_entered() -> void:
	$ButtonHover.play()

func _on_export_data_button_mouse_entered() -> void:
	$ButtonHover.play()

# ===== Popup public API and helpers =====
func set_context(battle_context: bool, has_battle_occurred: bool = false, battle_currently_active: bool = false) -> void:
	is_battle_context = battle_context
	_set_battle_buttons_visible(is_battle_context)
	# Hide Data Section when opened from BattleScene
	if is_instance_valid(data_section):
		data_section.visible = not battle_context
	if battle_context:
		set_battle_session_state(has_battle_occurred, battle_currently_active)
	_context_initialized = true

func set_energy_cost(cost: int) -> void:
	energy_cost = cost

func _on_background_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_popup()

func _close_popup():
	var panel: Control = $SettingsContainer
	var tween = create_tween()
	tween.set_parallel(true)
	# Fade out background
	var bg = get_node_or_null("Background")
	if bg:
		tween.tween_property(bg, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	# Panel fade and scale
	if panel:
		tween.tween_property(panel, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
		tween.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()

# ===== Battle buttons (now designed in TSCN) =====

func _set_battle_buttons_visible(visible_in_battle: bool) -> void:
	if battle_section:
		battle_section.visible = visible_in_battle
	if battle_separator:
		battle_separator.visible = visible_in_battle

func set_battle_session_state(has_battle_occurred: bool, _battle_currently_active: bool = false) -> void:
	if not engage_button or not leave_button:
		return
	if has_battle_occurred:
		engage_button.visible = false
		engage_button.disabled = true
		leave_button.visible = true
		leave_button.disabled = false
	else:
		engage_button.visible = true
		engage_button.disabled = false
		leave_button.visible = true
		leave_button.disabled = false

func _on_engage_button_pressed():
	$ButtonClick.play()
	print("SettingScene: Engage button pressed - showing energy confirmation")
	
	# First check if user has enough energy
	if not await _check_energy_and_show_notification():
		# Not enough energy - notification already shown by _check_energy_and_show_notification
		if engage_button:
			engage_button.disabled = false
		return
	
	# User has enough energy, show confirmation popup
	_show_energy_confirmation_notification()

# NEW: Show confirmation notification before starting battle
func _show_energy_confirmation_notification():
	print("SettingScene: Showing energy confirmation notification")
	var notification_popup_scene = load("res://Scenes/NotificationPopUp.tscn")
	if notification_popup_scene:
		var notification_popup = notification_popup_scene.instantiate()
		
		# Add to root with high layer to ensure it appears on top of everything
		get_tree().root.add_child(notification_popup)
		notification_popup.layer = 200 # Higher than settings popup layer (100)

		var title = "Engage Battle"
		var message = "Starting this battle will consume " + str(energy_cost) + " energy.\nAre you ready to engage?"
		var button_text = "Engage"
		
		# Show the confirmation notification
		notification_popup.show_notification(title, message, button_text)
		
		# Connect to the notification's button_pressed signal (only when user actually clicks engage)
		if notification_popup.has_signal("button_pressed"):
			notification_popup.button_pressed.connect(_on_energy_confirmation_engage_clicked)
		
		# Also connect to closed signal to reset button state if notification is just closed
		if notification_popup.has_signal("closed"):
			notification_popup.closed.connect(_on_energy_confirmation_popup_closed)
	else:
		print("Error: Could not load NotificationPopUp scene")

# NEW: Handle when user actually clicks the engage button in the notification
func _on_energy_confirmation_engage_clicked():
	print("SettingScene: User clicked engage in confirmation - proceeding with battle start")
	
	# Hide and disable engage button to prevent multiple clicks
	if engage_button:
		engage_button.disabled = true
		engage_button.visible = false # Hide the button as requested
		engage_button.text = "Starting..."
	
	# Brief delay for feedback, then close popup and emit signal
	await get_tree().create_timer(0.3).timeout
	_close_popup()
	engage_confirmed.emit()

# NEW: Handle when notification popup is closed without clicking engage
func _on_energy_confirmation_popup_closed():
	print("SettingScene: Energy confirmation popup closed - resetting engage button state")
	
	# Reset engage button state since user didn't actually confirm
	if engage_button:
		engage_button.disabled = false
		engage_button.text = "Engage"

func _on_quit_button_pressed():
	$ButtonClick.play()
	# Leave button directly exits without notification
	_close_popup()
	quit_requested.emit()

func _on_engage_button_mouse_entered() -> void:
	$ButtonHover.play()

func _on_quit_button_mouse_entered() -> void:
	$ButtonHover.play()

# ===== Energy notification helpers (migrated) =====
func _check_energy_and_show_notification() -> bool:
	if !Firebase.Auth or !Firebase.Auth.auth:
		_show_energy_notification(0, 20)
		return false
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var stats_data = user_doc.get_value("stats")
		if stats_data != null and "player" in stats_data:
			var current_energy = stats_data["player"].get("energy", 0)
			if current_energy < energy_cost:
				_show_energy_notification(current_energy, 20)
				return false
			return true
		else:
			return false
	else:
		_show_energy_notification(0, 20)
		return false

func _show_energy_notification(current_energy: int, max_energy: int):
	print("SettingScene: Showing energy notification: " + str(current_energy) + "/" + str(max_energy))
	var notification_popup_scene = load("res://Scenes/NotificationPopUp.tscn")
	if notification_popup_scene:
		var notification_popup = notification_popup_scene.instantiate()
		
		# Add to root with high layer to ensure it appears on top of everything
		get_tree().root.add_child(notification_popup)
		notification_popup.layer = 200 # Higher than settings popup layer (100)
		
		var title = "Not Enough Energy"
		var message = ""
		var energy_recovery_info = await _get_energy_recovery_info()
		var recovery_text = ""
		if energy_recovery_info.has("next_energy_time"):
			recovery_text = "\n\nNext energy in: " + energy_recovery_info["next_energy_time"]
		if current_energy == 0:
			message = "You have no energy remaining (" + str(current_energy) + "/" + str(max_energy) + ").\n\nEnergy is required to engage in battles. Wait for energy to recover over time." + recovery_text
		else:
			message = "You need " + str(energy_cost) + " energy to start a battle, but you only have " + str(current_energy) + ".\n\nWait for energy to recover over time." + recovery_text
		var button_text = "OK"
		notification_popup.show_notification(title, message, button_text)
	else:
		print("Error: Could not load NotificationPopUp scene")

func _get_energy_recovery_info() -> Dictionary:
	var result: Dictionary = {}
	if !Firebase.Auth or !Firebase.Auth.auth:
		return result
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var stats_data = user_doc.get_value("stats")
		if stats_data != null and "player" in stats_data:
			var player_data = stats_data["player"]
			var current_energy = player_data.get("energy", 0)
			var max_energy = 20
			var energy_recovery_rate = 240.0
			if current_energy >= max_energy:
				return result
			var current_time = Time.get_unix_time_from_system()
			var last_update = player_data.get("last_energy_update", current_time)
			var time_since_last_recovery = current_time - last_update
			var time_until_next_energy = energy_recovery_rate - fmod(time_since_last_recovery, energy_recovery_rate)
			var minutes = int(time_until_next_energy / 60)
			var seconds = int(time_until_next_energy) % 60
			result["next_energy_time"] = "%d:%02d" % [minutes, seconds]
	return result
