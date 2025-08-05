extends Control

# Constants
const DUNGEON_COUNT = 3
const ANIMATION_DURATION = 0.5
const ANIMATION_EASE = Tween.EASE_OUT_IN
const SCREEN_CENTER_X = 730.0 # Center of 1460px viewport
const DUNGEON_SPACING = 700.0 # Distance between dungeons
const CENTER_POSITION = 430.0 # X position for centered dungeon (730 - 300 for half dungeon width)

# Dungeon Properties
var current_dungeon = 0 # 0-based index (0 = Dungeon 1)
var unlocked_dungeons = 1 # How many dungeons are unlocked (at least 1)
var dungeon_names = ["The Plain", "The Forest", "The Mountain"]
var dungeon_textures = {
	"unlocked": [],
	"locked": []
}

# References to UI elements
@onready var dungeon_carousel = $DungeonContainer/DungeonCarousel
@onready var next_button = $NextButton
@onready var previous_button = $PreviousButton
@onready var play_button = $PlayButton

# Firebase references
var user_data = {}
# Selection indicator reference
var selection_indicators = []

# Add notification popup reference
var notification_popup: CanvasLayer

func _ready():
	# Add fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Preload dungeon textures
	dungeon_textures.unlocked = [
		preload("res://gui/Update/icons/plainselection.png"),
		preload("res://gui/Update/icons/theforesttransplant.png"),
		preload("res://gui/Update/icons/mountaintransplant.png")
	]
	dungeon_textures.locked = [
		null, # Dungeon 1 is always unlocked
		preload("res://gui/Update/icons/theforesttransplant_lock.png"),
		preload("res://gui/Update/icons/mountaintransplant_lock.png")
	]
	
	# Setup selection indicators for each dungeon
	for i in range(DUNGEON_COUNT):
		var dungeon_node = dungeon_carousel.get_child(i)
		
		# Create dyslexia-friendly selection indicator with curved border
		var selection_container = Control.new()
		selection_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_container.visible = false
		
		# Position the indicator as a border around the texture button
		dungeon_node.add_child(selection_container)
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
			# Extract dungeon progress data using the new structure
			var dungeons = document.get_value("dungeons")
			if dungeons != null and typeof(dungeons) == TYPE_DICTIONARY:
				var completed = dungeons.get("completed", {})
				
				# Count unlocked dungeons based on completion
				unlocked_dungeons = 1 # Dungeon 1 always unlocked
				
				# Check if dungeon 1 is completed (all 5 stages)
				if completed.has("1"):
					var dungeon1_data = completed["1"]
					if dungeon1_data.get("completed", false) or dungeon1_data.get("stages_completed", 0) >= 5:
						unlocked_dungeons = 2
						
						# Check if dungeon 2 is completed
						if completed.has("2"):
							var dungeon2_data = completed["2"]
							if dungeon2_data.get("completed", false) or dungeon2_data.get("stages_completed", 0) >= 5:
								unlocked_dungeons = 3
				
				# Set current dungeon to the latest (highest) unlocked dungeon
				current_dungeon = unlocked_dungeons - 1
				
				# Ensure it's not negative
				current_dungeon = max(current_dungeon, 0)
				
				print("Dungeons unlocked: ", unlocked_dungeons)
				print("Latest unlocked dungeon: ", unlocked_dungeons)
				print("Current dungeon (centered): ", current_dungeon + 1)
				print("Centering carousel on latest unlocked dungeon: ", current_dungeon + 1)
		else:
			print("Error loading user data or document not found")
			# Demo mode - center on the latest unlocked (dungeon 1)
			unlocked_dungeons = 1
			current_dungeon = 0
			print("Demo mode: Latest unlocked is dungeon ", unlocked_dungeons, ", centering on it")
	else:
		# Demo mode - center on the latest unlocked (dungeon 1)
		unlocked_dungeons = 1
		current_dungeon = 0
		print("No auth: Latest unlocked is dungeon ", unlocked_dungeons, ", centering on it")
	
	# Set initial carousel position and update display
	await get_tree().process_frame # Wait one frame to ensure scene is fully loaded
	
	# SIMPLE TEST: Just force Dungeon 1 to center position
	print("=== CIRCULAR LAYOUT TEST ===")
	print("Testing circular arrangement for all scenarios:")
	print()
	
	# Test what each scenario should look like
	for test_center in range(DUNGEON_COUNT):
		print("SCENARIO: Dungeon ", test_center + 1, " is centered (latest unlocked)")
		for i in range(DUNGEON_COUNT):
			var relative_pos = (i - test_center + DUNGEON_COUNT) % DUNGEON_COUNT
			var desc = ""
			match relative_pos:
				0: desc = "CENTER"
				1: desc = "RIGHT"
				2: desc = "LEFT"
			print("  Dungeon ", i + 1, " would be: ", desc, " (relative_pos: ", relative_pos, ")")
		print()
	
	print("Current setup: Dungeon ", current_dungeon + 1, " should be centered")
	print("=== TEST COMPLETE ===")
	print()
	
	_center_carousel_on_current_dungeon()
	update_dungeon_display()

# Center the carousel on the current dungeon (for initial positioning)
func _center_carousel_on_current_dungeon():
	print("=== INITIAL CENTERING ===")
	print("Will center on dungeon: ", current_dungeon + 1, " (index: ", current_dungeon, ")")
	print("Unlocked dungeons: ", unlocked_dungeons)
	
	# Force set positions immediately 
	_position_all_dungeons_for_selection(current_dungeon)
	
	print("=== CENTERING COMPLETE ===")
	print()

# Position all dungeons based on which one should be centered (CIRCULAR LAYOUT)
func _position_all_dungeons_for_selection(selected_index):
	print("=== CIRCULAR CAROUSEL POSITIONING ===")
	print("Centering dungeon index: ", selected_index, " (Dungeon ", selected_index + 1, ")")
	print("CENTER_POSITION: ", CENTER_POSITION)
	print("DUNGEON_SPACING: ", DUNGEON_SPACING)
	
	# Circular positions: LEFT ← CENTER → RIGHT
	# We arrange dungeons in a circle around the selected one
	for i in range(DUNGEON_COUNT):
		var dungeon_node = dungeon_carousel.get_child(i)
		print("Node ", i, " name: ", dungeon_node.name)
		print("Before - Dungeon ", i + 1, " at x: ", dungeon_node.position.x)
		
		# Calculate circular offset from selected dungeon
		var relative_position = (i - selected_index + DUNGEON_COUNT) % DUNGEON_COUNT
		
		var new_x: float
		var position_desc: String
		
		# Position based on circular arrangement
		match relative_position:
			0: # This is the selected dungeon - CENTER
				new_x = CENTER_POSITION
				position_desc = "CENTER"
			1: # Next dungeon in sequence - RIGHT
				new_x = CENTER_POSITION + DUNGEON_SPACING
				position_desc = "RIGHT"
			2: # Previous dungeon in sequence - LEFT
				new_x = CENTER_POSITION - DUNGEON_SPACING
				position_desc = "LEFT"
		
		# Apply the position
		dungeon_node.position.x = new_x
		
		print("After - Dungeon ", i + 1, " at x: ", new_x, " (", position_desc, ", relative_pos: ", relative_position, ")")
	
	print("=== CIRCULAR POSITIONING COMPLETE ===")
	print()

# Animate selection indicator for better dyslexia visibility
func _animate_selection_indicator(indicator: Control):
	# Stop any existing animation - use safe meta access
	if indicator.has_meta("selection_tween"):
		var existing_tween = indicator.get_meta("selection_tween")
		if existing_tween and is_instance_valid(existing_tween):
			existing_tween.kill()
	
	# Create pulsing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(indicator, "modulate:a", 0.7, 0.8)
	tween.tween_property(indicator, "modulate:a", 1.0, 0.8)
	
	# Store tween reference for cleanup
	indicator.set_meta("selection_tween", tween)

# Update the dungeon display based on current selection and unlock status
func update_dungeon_display():
	for i in range(DUNGEON_COUNT):
		var dungeon_node = dungeon_carousel.get_child(i)
		var texture_button = dungeon_node.get_node("TextureButton")
		var status_label = dungeon_node.get_node("StatusLabel")
		
		# Check if dungeon is unlocked
		var is_unlocked = i < unlocked_dungeons
		
		# Set the appropriate texture and hover behavior
		if is_unlocked:
			texture_button.texture_normal = dungeon_textures.unlocked[i]
			texture_button.disabled = false # Enable interaction
			texture_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			# Clear any hover texture for unlocked dungeons if needed
			status_label.text = "Unlocked"
			status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5)) # Green
		else:
			texture_button.texture_normal = dungeon_textures.locked[i]
			texture_button.disabled = false # Keep clickable for notifications
			texture_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			# Disable hover texture by setting it to the same as normal
			texture_button.texture_hover = dungeon_textures.locked[i]
			status_label.text = "Locked"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Red
			
		# Show selection indicator only on the current dungeon
		if i < selection_indicators.size():
			var indicator = selection_indicators[i]
			var was_visible = indicator.visible
			indicator.visible = (i == current_dungeon)
			
			# Clean up animation for previously selected dungeon
			if was_visible and i != current_dungeon:
				var existing_tween = indicator.get_meta("selection_tween", null)
				if existing_tween and is_instance_valid(existing_tween):
					existing_tween.kill()
				indicator.modulate.a = 1.0 # Reset alpha
			
			# Add pulsing animation for current selection
			if i == current_dungeon:
				_animate_selection_indicator(indicator)
	
	# Update button visibility - always show both buttons for circular navigation
	next_button.visible = true
	previous_button.visible = true
	
	# Enable/disable play button based on selected dungeon's unlock status
	play_button.disabled = current_dungeon >= unlocked_dungeons

# Handle navigation buttons with circular behavior
func _on_next_button_pressed():
	current_dungeon = (current_dungeon + 1) % DUNGEON_COUNT # Wrap around: 0→1→2→0
	_animate_carousel_to_position(current_dungeon)
	update_dungeon_display()

func _on_previous_button_pressed():
	current_dungeon = (current_dungeon - 1 + DUNGEON_COUNT) % DUNGEON_COUNT # Wrap around: 2→1→0→2
	_animate_carousel_to_position(current_dungeon)
	update_dungeon_display()

# Handle dungeon selection with circular behavior
func _on_dungeon1_pressed():
	if unlocked_dungeons >= 1: # Dungeon 1 is always unlocked
		if current_dungeon != 0:
			current_dungeon = 0
			_animate_carousel_to_position(current_dungeon)
			update_dungeon_display()
	# No else needed since Dungeon 1 is always unlocked

func _on_dungeon2_pressed():
	if unlocked_dungeons >= 2:
		if current_dungeon != 1:
			current_dungeon = 1
			_animate_carousel_to_position(current_dungeon)
			update_dungeon_display()
	else:
		# Show notification for locked dungeon
		notification_popup.show_notification("Dungeon Locked!", "Please complete 'The Plain' first to unlock this dungeon.", "OK")

func _on_dungeon3_pressed():
	if unlocked_dungeons >= 3:
		if current_dungeon != 2:
			current_dungeon = 2
			_animate_carousel_to_position(current_dungeon)
			update_dungeon_display()
	else:
		# Show notification for locked dungeon
		notification_popup.show_notification("Dungeon Locked!", "Please complete 'The Plain' and 'The Forest' first to unlock this dungeon.", "OK")

# Animation function for smooth circular carousel movement
func _animate_carousel_to_position(dungeon_index):
	var tween = create_tween()
	tween.set_ease(ANIMATION_EASE)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate all dungeons to their new circular positions
	for i in range(DUNGEON_COUNT):
		var dungeon_node = dungeon_carousel.get_child(i)
		
		# Calculate circular position (same logic as positioning function)
		var relative_position = (i - dungeon_index + DUNGEON_COUNT) % DUNGEON_COUNT
		
		var target_x: float
		match relative_position:
			0: # Center
				target_x = CENTER_POSITION
			1: # Right
				target_x = CENTER_POSITION + DUNGEON_SPACING
			2: # Left
				target_x = CENTER_POSITION - DUNGEON_SPACING
		
		tween.parallel().tween_property(dungeon_node, "position:x", target_x, ANIMATION_DURATION)

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

# Handle navigation and play buttons
func _on_back_button_pressed():
	_fade_out_and_change_scene("res://Scenes/MainMenu.tscn")

# Helper function to fade out before changing scenes
func _fade_out_and_change_scene(scene_path: String):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_play_button_pressed():
	if current_dungeon >= unlocked_dungeons:
		return # Don't allow playing locked dungeons
	
	# Save to Firebase if authenticated
	if Firebase.Auth.auth:
		var user_id = Firebase.Auth.auth.localid
		var collection = Firebase.Firestore.collection("dyslexia_users")
		
		# First get the existing document
		var get_task = await collection.get_doc(user_id)
		if get_task:
			var document = await get_task
			
			if document and document.has_method("doc_fields"):
				# Update current dungeon and stage in Firebase
				var current_data = document.doc_fields
				
				# Update dungeons progress
				if not current_data.has("dungeons"):
					current_data["dungeons"] = {}
				if not current_data.dungeons.has("progress"):
					current_data.dungeons["progress"] = {}
				
				current_data.dungeons.progress.current_dungeon = current_dungeon + 1
				current_data.dungeons.progress.current_stage = 1 # Start at stage 1
				
				# Save back to Firebase
				collection.add(user_id, current_data)
	
	# Load the appropriate dungeon map based on selection
	var dungeon_map_scene = ""
	match current_dungeon:
		0: dungeon_map_scene = "res://Scenes/Dungeon1Map.tscn"
		1: dungeon_map_scene = "res://Scenes/Dungeon2Map.tscn"
		2: dungeon_map_scene = "res://Scenes/Dungeon3Map.tscn"
	
	# Change to the selected dungeon map scene
	_fade_out_and_change_scene(dungeon_map_scene)
