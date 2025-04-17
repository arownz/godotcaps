extends Control

signal picture_selected(picture_id)
signal cancelled

var selected_picture_id = ""
var selected_button = null
var current_equipped_id = ""
var checkmark_icons = {}

func _ready():
    # Initialize UI
    $Panel/ConfirmButton.disabled = true
    
    # Create checkmark icons for all portrait buttons but make them invisible
    for child in $Panel/ScrollContainer/GridContainer.get_children():
        if child is TextureButton:
            var portrait_id = child.name.replace("Portrait", "")
            
            # Create checkmark icon as a child of the button
            var checkmark = TextureRect.new()
            checkmark.texture = load("res://gui/ProfileScene/Done 1.png")
            checkmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            checkmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            checkmark.size_flags_horizontal = Control.SIZE_SHRINK_END
            checkmark.size_flags_vertical = Control.SIZE_SHRINK_END
            checkmark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
            checkmark.position = Vector2(child.size.x - 30, child.size.y - 30)
            checkmark.visible = false
            checkmark.custom_minimum_size = Vector2(30, 30)
            child.add_child(checkmark)
            
            # Store reference to the checkmark
            checkmark_icons[portrait_id] = checkmark
    
    # Show checkmark for currently equipped profile
    update_checkmarks()

func set_current_profile(profile_id):
    current_equipped_id = profile_id
    update_checkmarks()

func update_checkmarks():
    # Hide all checkmarks first
    for icon in checkmark_icons.values():
        if icon:
            icon.visible = false
    
    # Show checkmark for currently equipped profile
    if current_equipped_id in checkmark_icons:
        var icon = checkmark_icons[current_equipped_id]
        if icon:
            icon.visible = true

func _on_portrait_button_pressed(picture_id):
    # Find the button that was pressed
    selected_picture_id = picture_id
    
    # Reset styling for all portrait buttons
    for child in $Panel/ScrollContainer/GridContainer.get_children():
        if child is TextureButton:
            child.modulate = Color(1, 1, 1, 1)
    
    # Highlight the selected button
    var sender = get_viewport().gui_get_focus_owner()
    if sender and sender is TextureButton:
        sender.modulate = Color(0.5, 0.8, 1.0, 1.0)
        selected_button = sender
    
    # Enable confirm button
    $Panel/ConfirmButton.disabled = false

func _on_confirm_button_pressed():
    # Emit signal with selected picture
    emit_signal("picture_selected", selected_picture_id)
    queue_free()

func _on_close_button_pressed():
    # Emit cancelled signal
    emit_signal("cancelled")
    queue_free()
