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
	
	# Animate popup appearance
	$PopupPanel.scale = Vector2(0.5, 0.5)
	$PopupPanel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.parallel().tween_property($PopupPanel, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property($PopupPanel, "modulate:a", 1.0, 0.3)

func set_energy_cost(cost: int):
	energy_cost = cost
	$PopupPanel/VBoxContainer/MessageLabel.text = "Starting this battle will consume " + str(cost) + " energy.\nAre you ready to engage?"

func _on_engage_button_pressed():
	_close_popup()
	engage_confirmed.emit()

func _on_quit_button_pressed():
	_close_popup()
	quit_requested.emit()

func _on_background_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_popup()

func _close_popup():
	var tween = create_tween()
	tween.parallel().tween_property($PopupPanel, "scale", Vector2(0.5, 0.5), 0.2)
	tween.parallel().tween_property($PopupPanel, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property($Background, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()
