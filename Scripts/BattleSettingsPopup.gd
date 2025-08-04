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
