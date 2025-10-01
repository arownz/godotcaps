extends CanvasLayer

signal closed
signal button_pressed # New signal for when the main button is actually clicked

# Default properties
var default_title = "Notification"
var default_message = "This is a notification message."
var default_button_text = "OK"

func _ready():
	# Hide popup by default
	hide()
	
	# Set up animation with null checks - matching SettingScene.gd pattern
	var popup_container = $PopupContainer
	if popup_container:
		popup_container.modulate.a = 0.0
		popup_container.scale = Vector2(0.8, 0.8)
	
	# Center the popup with null check
	var popup_background = $PopupContainer/CenterContainer/PopupBackground
	if popup_background:
		popup_background.pivot_offset = popup_background.size / 2
	else:
		print("Warning: PopupBackground not found in notification popup")
	
	# Connect background click for closing - matching SettingScene.gd pattern
	var background = $Background
	if background and not background.gui_input.is_connected(_on_background_clicked):
		print("NotificationPopup: Connecting background click to: ", background.name)
		background.gui_input.connect(_on_background_clicked)
	else:
		print("NotificationPopup: Background node not found!")
	
	# Override the X button connection to use the non-engaging close
	var close_x_button = $PopupContainer/CenterContainer/PopupBackground/CloseXButton
	if close_x_button:
		# Disconnect the existing connection and connect to our specific function
		if close_x_button.pressed.is_connected(_on_close_button_pressed):
			close_x_button.pressed.disconnect(_on_close_button_pressed)
		close_x_button.pressed.connect(_on_close_x_button_pressed)

func _on_background_clicked(event):
	print("NotificationPopup: Background input received: ", event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("NotificationPopup: Background clicked, closing popup without engaging")
		# Background click should not trigger engagement - just close
		close_notification()

func close_notification():
	"""Close notification with animation - matching SettingScene.gd pattern"""
	# Try playing sound with error handling
	var button_click = $ButtonClick
	if button_click and button_click.has_method("play"):
		button_click.set_stream_paused(false) # Ensure not paused
		if OS.has_feature("web"):
			# Web-specific sound handling
			if button_click.stream and button_click.stream.is_class("AudioStreamOGGVorbis"):
				button_click.play()
		else:
			button_click.play()
	
	var popup_container = $PopupContainer
	var tween = create_tween()
	tween.set_parallel(true)
	# Fade out background
	var bg = get_node_or_null("Background")
	if bg:
		tween.tween_property(bg, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	# Panel fade and scale
	if popup_container:
		tween.tween_property(popup_container, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
		tween.tween_property(popup_container, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	
	await tween.finished
	hide()
	
	# Notify background music manager that notification is closed
	var bg_manager = get_node_or_null("/root/BackgroundMusicManager")
	if bg_manager and bg_manager.has_method("_check_current_scene_and_play"):
		bg_manager._check_current_scene_and_play()
		print("NotificationPopup: Notified BackgroundMusicManager to resume music")
	
	emit_signal("closed")
	
	# Remove from tree to prevent duplicates and memory leaks
	call_deferred("queue_free")

func show_notification(title = default_title, message = default_message, button_text = default_button_text):
	# Add null checks before setting text
	var title_label = $PopupContainer/CenterContainer/PopupBackground/VBoxContainer/TopContainer/TitleLabel
	var message_label = $PopupContainer/CenterContainer/PopupBackground/VBoxContainer/MessageLabel
	var button_label = $PopupContainer/CenterContainer/PopupBackground/VBoxContainer/CloseButton
	var popup_background = $PopupContainer/CenterContainer/PopupBackground
	
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
	
	# Calculate dynamic size based on content
	if popup_background and message_label:
		var calculated_size = _calculate_popup_size(message)
		popup_background.custom_minimum_size = calculated_size
		
		# Update pivot offset for proper centering with the new size
		popup_background.pivot_offset = calculated_size / 2
		
		# Force a layout update to ensure proper sizing
		popup_background.queue_redraw()
		
		print("Notification popup resized to: ", calculated_size, " for message: ", message.substr(0, 50), "...")
	
	# Show the popup
	show()
	
	# Reset background opacity before animation
	var bg = get_node_or_null("Background")
	if bg:
		bg.modulate.a = 1.0 # Reset background opacity
	
	# Enhanced fade-in animation matching SettingScene.gd pattern
	var popup_container = $PopupContainer
	if popup_container:
		popup_container.modulate.a = 0.0
		popup_container.scale = Vector2(0.8, 0.8)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(popup_container, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(popup_container, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		print("Warning: PopupContainer not found in notification popup")

# Calculate popup size based on message content
# Dynamic sizing rules:
# - Base size: 500x200 for simple content (1-2 sentences, 1 paragraph)
# - Max width: 500px (for readability)
# - Height scaling: +40px per additional paragraph, +20px per extra sentence
# - Max height: 250px for 1-2 paragraphs, 350px for more paragraphs
# - Character count consideration for very long messages
func _calculate_popup_size(message: String) -> Vector2:
	# Base size for minimal content
	var base_width = 500.0
	var base_height = 200.0
	
	# Count paragraphs (split by \n - including empty lines for spacing)
	var lines = message.split("\n")
	var paragraph_count = 0
	var sentence_count = 0
	var total_char_count = 0
	
	# Analyze content structure
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.length() > 0:
			paragraph_count += 1
			total_char_count += trimmed.length()
			
			# Count sentences in this line (split by ., !, ?)
			var sentences = []
			var temp_sentences = trimmed.split(".")
			for s in temp_sentences:
				sentences.append_array(s.split("!"))
			
			var final_sentences = []
			for s in sentences:
				final_sentences.append_array(s.split("?"))
			
			for sentence in final_sentences:
				if sentence.strip_edges().length() > 0:
					sentence_count += 1
	
	# Calculate width (keep max width at 500 for readability)
	var calculated_width = base_width
	
	# Calculate height based on content structure
	var calculated_height = base_height
	
	# Add height for additional paragraphs
	if paragraph_count > 1:
		calculated_height += (paragraph_count - 1) * 40 # 40px per extra paragraph
	
	# Add height for sentence density (longer sentences need more space)
	if sentence_count > 2:
		calculated_height += (sentence_count - 2) * 20 # 20px per extra sentence
	
	# Consider character count for very long content
	if total_char_count > 100: # Long messages
		var extra_height = int((total_char_count - 100) / 50.0) * 15
		calculated_height += extra_height
	
	# Apply constraints based on your requirements
	if paragraph_count <= 2:
		# For 1-2 paragraphs, max 250px as requested
		calculated_height = min(calculated_height, 250.0)
	else:
		# For more paragraphs, allow more height but cap it
		calculated_height = min(calculated_height, 350.0)
	
	# Ensure minimum usable size
	calculated_height = max(calculated_height, 200.0)
	calculated_width = max(calculated_width, 400.0)
	
	print("Content analysis - Paragraphs: ", paragraph_count, ", Sentences: ", sentence_count, ", Characters: ", total_char_count)
	print("Calculated size: ", Vector2(calculated_width, calculated_height))
	
	return Vector2(calculated_width, calculated_height)

func _on_close_button_pressed():
	# This is the main button (like "Engage"), emit button_pressed signal
	emit_signal("button_pressed")
	close_notification()

func _on_close_x_button_pressed():
	# This is the X button - just close without emitting button_pressed
	print("NotificationPopup: X button clicked, closing popup")
	close_notification()


func _on_close_button_mouse_entered() -> void:
	$ButtonHover.play()
