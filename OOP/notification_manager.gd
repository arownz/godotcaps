extends Node

# Constants for positioning
enum Position {
    CENTER,
    TOP,
    BOTTOM,
    TOP_LEFT,
    TOP_RIGHT,
    BOTTOM_LEFT,
    BOTTOM_RIGHT
}

var current_notification: CanvasLayer = null
var notification_queue = []
var is_showing = false

# Show a notification with the given title and message
# Optional parameters:
# - duration: How long to display the notification (0 = requires manual dismissal)
# - position: Where to position the notification (default: CENTER)
# - color: Background color for the notification (default: #004457)
func show_notification(title: String, message: String, duration: float = 0, position: Position = Position.CENTER, color: Color = Color(0, 0.266667, 0.337255)):
    # Queue the notification if one is already showing
    if is_showing:
        notification_queue.append({
            "title": title,
            "message": message,
            "duration": duration,
            "position": position,
            "color": color
        })
        return
    
    is_showing = true
    
    # Create notification scene
    var notification = _create_notification_scene(title, message, color)
    
    # Add to scene
    get_tree().root.add_child(notification)
    current_notification = notification
    
    # Position the notification
    _position_notification(notification, position)
    
    # Set up notification dismissal
    var close_button = notification.get_node("NotificationPanel/VBoxContainer/CloseButton")
    if close_button:
        close_button.pressed.connect(_on_notification_dismissed.bind(notification))
    
    # Auto-dismiss after duration if specified
    if duration > 0:
        await get_tree().create_timer(duration).timeout
        if is_instance_valid(notification):
            _dismiss_notification(notification)

# Create notification scene programmatically
func _create_notification_scene(title: String, message: String, color: Color) -> CanvasLayer:
    var canvas_layer = CanvasLayer.new()
    canvas_layer.layer = 10 # Make sure it appears above other UI
    
    var panel = PanelContainer.new()
    panel.name = "NotificationPanel"
    panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    
    # Create a style for the panel
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.9, 0.9, 0.9, 0.95)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    style.shadow_color = Color(0, 0, 0, 0.3)
    style.shadow_size = 4
    style.shadow_offset = Vector2(0, 2)
    panel.add_theme_stylebox_override("panel", style)
    
    # Set up container
    var vbox = VBoxContainer.new()
    vbox.name = "VBoxContainer"
    vbox.custom_minimum_size = Vector2(400, 0)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    
    # Title label
    var title_label = Label.new()
    title_label.name = "TitleLabel"
    title_label.text = title
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_color_override("font_color", color)
    title_label.add_theme_font_size_override("font_size", 20)
    
    # Separator
    var separator = HSeparator.new()
    separator.name = "Separator"
    
    # Message label
    var message_label = Label.new()
    message_label.name = "MessageLabel"
    message_label.text = message
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_font_size_override("font_size", 16)
    
    # Spacer
    var spacer = Control.new()
    spacer.name = "Spacer"
    spacer.custom_minimum_size = Vector2(0, 10)
    
    # Close button
    var close_button = Button.new()
    close_button.name = "CloseButton"
    close_button.text = "Close"
    close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    
    # Add to scene tree
    canvas_layer.add_child(panel)
    panel.add_child(vbox)
    vbox.add_child(title_label)
    vbox.add_child(separator)
    vbox.add_child(message_label)
    vbox.add_child(spacer)
    vbox.add_child(close_button)
    
    return canvas_layer

# Position the notification based on the specified position
func _position_notification(notification: CanvasLayer, position: Position):
    var panel = notification.get_node("NotificationPanel")
    
    # Center the panel by default
    panel.position = Vector2(0, 0)
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.5
    panel.anchor_bottom = 0.5
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    
    # Adjust position based on enum
    match position:
        Position.TOP:
            panel.anchor_top = 0.0
            panel.anchor_bottom = 0.0
            panel.position.y = 50
        Position.BOTTOM:
            panel.anchor_top = 1.0
            panel.anchor_bottom = 1.0
            panel.position.y = -50
        Position.TOP_LEFT:
            panel.anchor_left = 0.0
            panel.anchor_right = 0.0
            panel.anchor_top = 0.0
            panel.anchor_bottom = 0.0
            panel.position = Vector2(50, 50)
        Position.TOP_RIGHT:
            panel.anchor_left = 1.0
            panel.anchor_right = 1.0
            panel.anchor_top = 0.0
            panel.anchor_bottom = 0.0
            panel.position = Vector2(-50, 50)
        Position.BOTTOM_LEFT:
            panel.anchor_left = 0.0
            panel.anchor_right = 0.0
            panel.anchor_top = 1.0
            panel.anchor_bottom = 1.0
            panel.position = Vector2(50, -50)
        Position.BOTTOM_RIGHT:
            panel.anchor_left = 1.0
            panel.anchor_right = 1.0
            panel.anchor_top = 1.0
            panel.anchor_bottom = 1.0
            panel.position = Vector2(-50, -50)

# Handler for close button press
func _on_notification_dismissed(notification: CanvasLayer):
    _dismiss_notification(notification)

# Dismiss a notification and show the next one if in queue
func _dismiss_notification(notification: CanvasLayer):
    if notification == current_notification:
        current_notification = null
        
        # Remove from scene
        notification.queue_free()
        
        # Show next notification if there's one in queue
        is_showing = false
        if not notification_queue.empty():
            var next = notification_queue.pop_front()
            show_notification(next.title, next.message, next.duration, next.position, next.color)
