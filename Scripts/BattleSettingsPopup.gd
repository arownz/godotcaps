extends CanvasLayer

signal engage_confirmed
signal quit_requested

var energy_cost = 2

func _ready():
	# Connect button signals
	$PopupPanel/CloseButton.pressed.connect(_close_popup)
	$PopupPanel/VBoxContainer/ButtonContainer/EngageButton.pressed.connect(_on_engage_button_pressed)
	$PopupPanel/VBoxContainer/ButtonContainer/QuitButton.pressed.connect(_on_quit_button_pressed)
	
	# Connect background click to quit
	$Background.gui_input.connect(_on_background_input)
	
	# Enhanced fade-in animation with smooth scaling
	$Background.modulate.a = 0.0
	$PopupPanel.scale = Vector2(0.8, 0.8)
	$PopupPanel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	# Background fade
	tween.tween_property($Background, "modulate:a", 0.6, 0.3).set_ease(Tween.EASE_OUT)
	# Panel scale and fade
	tween.tween_property($PopupPanel, "scale", Vector2(1, 1), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property($PopupPanel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

func set_energy_cost(cost: int):
	energy_cost = cost
	$PopupPanel/VBoxContainer/MessageLabel.text = "Starting this battle will consume " + str(cost) + " energy.\nAre you ready to engage?"

func set_battle_state(battle_active: bool):
	# Deprecated - use set_battle_session_state instead
	set_battle_session_state(battle_active, battle_active)

func set_battle_session_state(has_battle_occurred: bool, battle_currently_active: bool = false):
	if has_battle_occurred:
		# Hide the engage button since a battle has already occurred in this session
		$PopupPanel/VBoxContainer/ButtonContainer/EngageButton.visible = false
		$PopupPanel/VBoxContainer/ButtonContainer/EngageButton.disabled = true
		
		if battle_currently_active:
			# Battle, challenge, or endgame screen is active
			$PopupPanel/VBoxContainer/MessageLabel.text = "Battle session is currently active.\nUse the quit button to leave the battle."
			$PopupPanel/VBoxContainer/Title.text = "Battle Menu"
		else:
			# Battle session has completely ended
			$PopupPanel/VBoxContainer/MessageLabel.text = "Battle session has ended."
			$PopupPanel/VBoxContainer/Title.text = "Battle Menu"

func _on_engage_button_pressed():
	$ButtonClick.play()
	# Check energy first before doing anything
	if ! await _check_energy_and_show_notification():
		# Not enough energy - re-enable button and update message
		$PopupPanel/VBoxContainer/ButtonContainer/EngageButton.visible = true
		$PopupPanel/VBoxContainer/ButtonContainer/EngageButton.disabled = false
		$PopupPanel/VBoxContainer/MessageLabel.text = "Insufficient energy to start battle.\nPlease wait for energy to recover."
		return
	
	# Hide the engage button immediately to prevent multiple clicks
	$PopupPanel/VBoxContainer/ButtonContainer/EngageButton.visible = false
	# Also disable it for extra safety
	$PopupPanel/VBoxContainer/ButtonContainer/EngageButton.disabled = true
	
	# Update the message to show battle is starting
	$PopupPanel/VBoxContainer/MessageLabel.text = "Battle starting...\nEnergy consumed!"
	
	# Show feedback for a brief moment before closing
	await get_tree().create_timer(0.5).timeout
	
	_close_popup()
	engage_confirmed.emit()

func _on_quit_button_pressed():
	$ButtonClick.play()
	_close_popup()
	quit_requested.emit()

func _on_background_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_popup()

func _close_popup():
	# Enhanced fade-out animation
	var tween = create_tween()
	tween.set_parallel(true)
	# Background fade
	tween.tween_property($Background, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	# Panel scale and fade
	tween.tween_property($PopupPanel, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property($PopupPanel, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()

# NEW: Check energy and show notification if insufficient 
func _check_energy_and_show_notification() -> bool:
	# Get current energy without consuming it
	if !Firebase.Auth.auth:
		_show_energy_notification(0, 20)
		return false
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get user document
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var stats_data = user_doc.get_value("stats")
		if stats_data != null and "player" in stats_data:
			var player_data = stats_data["player"]
			var current_energy = player_data.get("energy", 0)
			var max_energy = 20
			
			# Check if player has enough energy
			if current_energy < 2:
				_show_energy_notification(current_energy, max_energy)
				return false
			
			return true
		else:
			_show_energy_notification(0, 20)
			return false
	else:
		_show_energy_notification(0, 20)
		return false

# NEW: Show energy notification popup
func _show_energy_notification(current_energy: int, max_energy: int):
	print("BattleSettingsPopup: Showing energy notification: " + str(current_energy) + "/" + str(max_energy))
	
	# Create a new notification popup since this popup will close
	var notification_popup_scene = load("res://Scenes/NotificationPopUp.tscn")
	if notification_popup_scene:
		var notification_popup = notification_popup_scene.instantiate()
		
		# Add to the main scene tree (not as child of this popup)
		get_tree().current_scene.add_child(notification_popup)
		
		var title = "Not Enough Energy"
		var message = ""
		
		# Calculate energy recovery time information
		var energy_recovery_info = await _get_energy_recovery_info()
		var recovery_text = ""
		if energy_recovery_info.has("next_energy_time"):
			recovery_text = "\n\nNext energy in: " + energy_recovery_info["next_energy_time"]
		else:
			recovery_text = "\n\nEnergy recovers every 4 minutes."
		
		if current_energy == 0:
			message = "You have no energy remaining (" + str(current_energy) + "/" + str(max_energy) + ").\n\nEnergy is required to engage in battles. Wait for energy to recover over time." + recovery_text
		else:
			message = "You need 2 energy to start a battle, but you only have " + str(current_energy) + " energy remaining.\n\nWait for energy to recover over time." + recovery_text
		
		var button_text = "OK"
		
		# Show the notification
		notification_popup.show_notification(title, message, button_text)
	else:
		print("Error: Could not load NotificationPopUp scene")

# NEW: Get energy recovery time information
func _get_energy_recovery_info() -> Dictionary:
	var result = {}
	
	if !Firebase.Auth.auth:
		return result
	
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get user document (don't use await here to avoid blocking)
	var user_doc = await collection.get_doc(user_id)
	if user_doc and !("error" in user_doc.keys() and user_doc.get_value("error")):
		var stats_data = user_doc.get_value("stats")
		if stats_data != null and "player" in stats_data:
			var player_data = stats_data["player"]
			var current_energy = player_data.get("energy", 0)
			var max_energy = 20
			var energy_recovery_rate = 240 # 4 minutes in seconds
			
			# If at max energy, no recovery needed
			if current_energy >= max_energy:
				return result
			
			var current_time = Time.get_unix_time_from_system()
			var last_update = player_data.get("last_energy_update", current_time)
			var time_since_last_recovery = current_time - last_update
			var time_until_next_energy = energy_recovery_rate - fmod(time_since_last_recovery, energy_recovery_rate)
			
			var minutes = int(time_until_next_energy / 60)
			var seconds = int(time_until_next_energy) % 60
			
			result["next_energy_time"] = "%d:%02d" % [minutes, seconds]
			result["current_energy"] = current_energy
			result["max_energy"] = max_energy
	
	return result


func _on_engage_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_quit_button_mouse_entered() -> void:
	$ButtonHover.play()


func _on_close_button_mouse_entered() -> void:
	$ButtonHover.play()
