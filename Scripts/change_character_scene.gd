extends Control

# Constants
const CHARACTER_COUNT = 3
const ANIMATION_DURATION = 0.5
const ANIMATION_EASE = Tween.EASE_OUT_IN
const SCREEN_CENTER_X = 730.0 # Center of 1460px viewport
const CHARACTER_SPACING = 700.0 # Distance between characters
const CENTER_POSITION = 430.0 # X position for centered character (730 - 300 for half character width)

# Character Properties
var current_character = 0 # 0-based index (0 = Character 1)
var unlocked_characters = 1 # How many characters are unlocked (at least 1)
var character_names = ["Lexia", "Magi", "Ragnar"]
var character_textures = {
	"unlocked": [],
	"locked": []
}

# References to UI elements
@onready var character_carousel = $CharacterContainer/CharacterCarousel
@onready var next_button = $NextButton
@onready var previous_button = $PreviousButton
@onready var select_button = $SelectButton

# Firebase references
var user_data = {}
# Selection indicator reference
var selection_indicators = []

# Add notification popup reference
var notification_popup: CanvasLayer

func _ready():
	# Preload character textures
	character_textures.unlocked = [
		preload("res://gui/Update/UI/Character Select Unlocked.png"),
		null, # Will add Magi unlocked texture when available
		null # Will add Ragnar unlocked texture when available
	]
	character_textures.locked = [
		null, # Character 1 is always unlocked
		preload("res://gui/Update/UI/Character_Card_Lock.png"),
		preload("res://gui/Update/UI/Character_Card_Lock.png")
	]
	
	# Setup selection indicators for each character
	for i in range(CHARACTER_COUNT):
		var character_node = character_carousel.get_child(i)
		
		# Create dyslexia-friendly selection indicator with curved border
		var selection_container = Control.new()
		selection_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_container.visible = false
		
		# Position the indicator as a border around the texture button
		character_node.add_child(selection_container)
		selection_container.show_behind_parent = true
		selection_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		selection_container.offset_left = -12
		selection_container.offset_top = -12
		selection_container.offset_right = 12
		selection_container.offset_bottom = 12
		
		# Create black border (outer)
		var black_border = ColorRect.new()
		black_border.color = Color.BLACK
		black_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_container.add_child(black_border)
		black_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Create golden outline (inner)
		var golden_outline = ColorRect.new()
		golden_outline.color = Color(1.0, 0.8, 0.2, 0.9) # Bright golden color
		golden_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_container.add_child(golden_outline)
		golden_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		golden_outline.offset_left = 4
		golden_outline.offset_top = 4
		golden_outline.offset_right = -4
		golden_outline.offset_bottom = -4
		
		# Create inner transparent area
		var inner_area = ColorRect.new()
		inner_area.color = Color.TRANSPARENT
		inner_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_container.add_child(inner_area)
		inner_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner_area.offset_left = 8
		inner_area.offset_top = 8
		inner_area.offset_right = -8
		inner_area.offset_bottom = -8
		
		selection_indicators.append(selection_container)
	
	# Create notification popup
	notification_popup = load("res://Scenes/NotificationPopUp.tscn").instantiate()
	add_child(notification_popup)
	notification_popup.closed.connect(_on_notification_closed)
	
	# Setup hover functionality for navigation buttons
	_setup_hover_functionality()
	
	# Load user data and update UI
	_load_user_data()

# Setup hover functionality for navigation buttons
func _setup_hover_functionality():
	# Connect hover events for back button
	$BackButton.mouse_entered.connect(_on_back_button_hover_entered)
	$BackButton.mouse_exited.connect(_on_back_button_hover_exited)
	
	# Connect hover events for next button
	$NextButton.mouse_entered.connect(_on_next_button_hover_entered)
	$NextButton.mouse_exited.connect(_on_next_button_hover_exited)
	
	# Connect hover events for previous button
	$PreviousButton.mouse_entered.connect(_on_previous_button_hover_entered)
	$PreviousButton.mouse_exited.connect(_on_previous_button_hover_exited)

# Load user data from Firebase
func _load_user_data():
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		var document = await collection.get_doc(user_id)
		if document and !("error" in document.keys() and document.get_value("error")):
			# Extract character progress data using the new structure
			var characters = document.get_value("characters")
			if characters:
				# Load unlocked characters from Firebase
				unlocked_characters = characters.get("unlocked_count", 1)
		else:
			print("Demo mode: Only Lexia available")
	else:
		# Demo mode - only Lexia available
		unlocked_characters = 1
		current_character = 0
		print("No auth: Only Lexia available")
	
	# Set initial carousel position and update display
	_center_carousel_on_current_character()
	update_character_display()

# Center the carousel on the current character (for initial positioning)
func _center_carousel_on_current_character():
	# Position all characters relative to the center position
	_position_all_characters_for_selection(current_character)

# Position all characters based on which one should be centered
func _position_all_characters_for_selection(selected_index):
	for i in range(CHARACTER_COUNT):
		var character_node = character_carousel.get_child(i)
		var offset = (i - selected_index) * CHARACTER_SPACING
		character_node.position.x = CENTER_POSITION + offset

# Animate selection indicator for better dyslexia visibility
func _animate_selection_indicator(indicator: Control):
	# Stop any existing animation
	var existing_tween = indicator.get_meta("selection_tween", null)
	if existing_tween and is_instance_valid(existing_tween):
		existing_tween.kill()
	
	# Create pulsing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(indicator, "modulate:a", 0.7, 0.8)
	tween.tween_property(indicator, "modulate:a", 1.0, 0.8)
	
	# Store tween reference for cleanup
	indicator.set_meta("selection_tween", tween)

# Update the character display based on current selection and unlock status
func update_character_display():
	for i in range(CHARACTER_COUNT):
		var character_node = character_carousel.get_child(i)
		var texture_button = character_node.get_node("TextureButton")
		var status_label = character_node.get_node("StatusLabel")
		
		# Check if character is unlocked
		var is_unlocked = i < unlocked_characters
		
		# Set the appropriate texture and hover behavior
		if is_unlocked:
			if character_textures.unlocked[i] != null:
				texture_button.texture_normal = character_textures.unlocked[i]
			status_label.text = "Unlocked"
			status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5)) # Green
		else:
			if character_textures.locked[i] != null:
				texture_button.texture_normal = character_textures.locked[i]
			status_label.text = "Locked"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Red
		
		# Show selection indicator only on the current character
		if i < selection_indicators.size():
			selection_indicators[i].visible = (i == current_character)
			if i == current_character:
				_animate_selection_indicator(selection_indicators[i])
	
	# Update button visibility - always show both buttons for circular navigation
	next_button.visible = true
	previous_button.visible = true
	
	# Enable/disable select button based on selected character's unlock status
	select_button.disabled = current_character >= unlocked_characters

# Handle navigation buttons with circular behavior
func _on_next_button_pressed():
	current_character = (current_character + 1) % CHARACTER_COUNT # Wrap around: 0→1→2→0
	_animate_carousel_to_position(current_character)
	update_character_display()

func _on_previous_button_pressed():
	current_character = (current_character - 1 + CHARACTER_COUNT) % CHARACTER_COUNT # Wrap around: 2→1→0→2
	_animate_carousel_to_position(current_character)
	update_character_display()

# Handle character selection with circular behavior
func _on_character1_pressed():
	if unlocked_characters >= 1: # Character 1 is always unlocked
		if current_character != 0:
			current_character = 0
			_animate_carousel_to_position(current_character)
			update_character_display()
	# No else needed since Character 1 is always unlocked

func _on_character2_pressed():
	if unlocked_characters >= 2:
		if current_character != 1:
			current_character = 1
			_animate_carousel_to_position(current_character)
			update_character_display()
	else:
		# Show notification for locked character
		notification_popup.show_notification("Character Locked!", "Please complete more challenges to unlock Magi.", "OK")

func _on_character3_pressed():
	if unlocked_characters >= 3:
		if current_character != 2:
			current_character = 2
			_animate_carousel_to_position(current_character)
			update_character_display()
	else:
		# Show notification for locked character
		notification_popup.show_notification("Character Locked!", "Please complete more challenges to unlock Ragnar.", "OK")

# Animation function for smooth carousel movement
func _animate_carousel_to_position(character_index):
	var tween = create_tween()
	tween.set_ease(ANIMATION_EASE)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate all characters to their new positions
	for i in range(CHARACTER_COUNT):
		var character_node = character_carousel.get_child(i)
		var offset = (i - character_index) * CHARACTER_SPACING
		var target_x = CENTER_POSITION + offset
		
		tween.parallel().tween_property(character_node, "position:x", target_x, ANIMATION_DURATION)

# Add handler for notification closed
func _on_notification_closed():
	# Handle notification close if needed
	pass

# Button hover handlers
func _on_back_button_hover_entered():
	var back_label = $BackButton/BackLabel
	if back_label:
		back_label.visible = true

func _on_back_button_hover_exited():
	var back_label = $BackButton/BackLabel
	if back_label:
		back_label.visible = false

func _on_next_button_hover_entered():
	var next_label = $NextButton/NextLabel
	if next_label:
		next_label.visible = true

func _on_next_button_hover_exited():
	var next_label = $NextButton/NextLabel
	if next_label:
		next_label.visible = false

func _on_previous_button_hover_entered():
	var previous_label = $PreviousButton/PreviousLabel
	if previous_label:
		previous_label.visible = true

func _on_previous_button_hover_exited():
	var previous_label = $PreviousButton/PreviousLabel
	if previous_label:
		previous_label.visible = false

# Handle navigation and select buttons
func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_select_button_pressed():
	if current_character >= unlocked_characters:
		return # Don't allow selecting locked characters
	
	# Save to Firebase if authenticated
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		# First get the existing document
		var get_task = await collection.get_doc(user_id)
		if get_task:
			var user_doc = get_task
			
			# Update selected character
			user_doc.add_or_update_field("selected_character", current_character)
			
			# Save the updated document
			var save_task = await collection.update(user_doc)
			if save_task and !("error" in save_task.keys()):
				print("Character selection saved: " + character_names[current_character])
			else:
				print("Failed to save character selection")
	
	# For now, just print and go back to main menu
	print("Selected character: " + character_names[current_character])
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
