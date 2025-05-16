extends CanvasLayer

signal closed

# Default properties
var default_title = "Notification"
var default_message = "This is a notification message."
var default_button_text = "OK"

func _ready():
	# Hide popup by default
	hide()
	
	# Set up animation
	$PopupContainer.modulate = Color(1, 1, 1, 0)
	$PopupContainer.scale = Vector2(0.8, 0.8)
	
	# Center the popup
	$PopupContainer/CenterContainer/PopupBackground.pivot_offset = $PopupContainer/CenterContainer/PopupBackground.size / 2

func show_notification(title = default_title, message = default_message, button_text = default_button_text):
	# Set the text
	$PopupContainer/CenterContainer/PopupBackground/VBoxContainer/TitleLabel.text = title
	$PopupContainer/CenterContainer/PopupBackground/VBoxContainer/MessageLabel.text = message
	$PopupContainer/CenterContainer/PopupBackground/VBoxContainer/CloseButton/Label.text = button_text
	
	# Show the popup
	show()
	
	# Animate the popup
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($PopupContainer, "modulate", Color(1, 1, 1, 1), 0.3)
	tween.tween_property($PopupContainer, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_close_button_pressed():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($PopupContainer, "modulate", Color(1, 1, 1, 0), 0.2)
	tween.tween_property($PopupContainer, "scale", Vector2(0.8, 0.8), 0.2)
	
	await tween.finished
	hide()
	emit_signal("closed")
