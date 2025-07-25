extends CanvasLayer

signal closed

# Default properties
var default_title = "Notification"
var default_message = "This is a notification message."
var default_button_text = "OK"

func _ready():
	# Hide popup by default
	hide()
	
	# Set up animation with null checks
	var popup_container = $PopupContainer
	if popup_container:
		popup_container.modulate = Color(1, 1, 1, 0)
		popup_container.scale = Vector2(0.8, 0.8)
	
	# Center the popup with null check
	var popup_background = $PopupContainer/CenterContainer/PopupBackground
	if popup_background:
		popup_background.pivot_offset = popup_background.size / 2
	else:
		print("Warning: PopupBackground not found in notification popup")

func show_notification(title = default_title, message = default_message, button_text = default_button_text):
	# Add null checks before setting text
	var title_label = $PopupContainer/CenterContainer/PopupBackground/VBoxContainer/TitleLabel
	var message_label = $PopupContainer/CenterContainer/PopupBackground/VBoxContainer/MessageLabel
	var button_label = $PopupContainer/CenterContainer/PopupBackground/VBoxContainer/CloseButton
	
	if title_label:
		title_label.text = title
	else:
		print("Warning: TitleLabel not found in notification popup")
		
	if message_label:
		message_label.text = message
	else:
		print("Warning: MessageLabel not found in notification popup")
		
	if button_label:
		button_label.text = button_text
	else:
		print("Warning: CloseButton Label not found in notification popup")
	
	# Show the popup
	show()
	
	# Animate the popup with null check
	var popup_container = $PopupContainer
	if popup_container:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(popup_container, "modulate", Color(1, 1, 1, 1), 0.3)
		tween.tween_property(popup_container, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		print("Warning: PopupContainer not found in notification popup")

func _on_close_button_pressed():
	var popup_container = $PopupContainer
	if popup_container:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(popup_container, "modulate", Color(1, 1, 1, 0), 0.2)
		tween.tween_property(popup_container, "scale", Vector2(0.8, 0.8), 0.2)
		
		await tween.finished
	
	hide()
	emit_signal("closed")
