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
var character_names = ["Lexia", "Ragna", "Magi"]
var character_textures = {
	"unlocked": [],
	"locked": []
}

# Character data with stats, bonuses, and unlock requirements
var character_data = {
	"lexia": {
		"display_name": "Lexia",
		"weapon": "Sword",
		"counter_name": "Blade Beam",
		"stat_bonuses": {
			"health": 5, # Slight health bonus
			"damage": 3, # Slight damage bonus
			"durability": 2 # Slight durability bonus
		},
		"animation_scene": "res://Sprites/Animation/DefaultPlayer_Animation.tscn",
		"unlock_requirement": {"type": "lexia", "value": 0}, # Always unlocked
		"description": "A dyslexic balanced sword master wielding a trusty sword."
	},
	"ragna": {
		"display_name": "Ragna",
		"weapon": "Rapier",
		"counter_name": "Swift Pierce",
		"stat_bonuses": {
			"health": - 10, # Less health
			"damage": 15, # More damage
			"durability": - 2 # Less durability
		},
		"animation_scene": "res://Sprites/Animation/Ragna_Animation.tscn",
		"unlock_requirement": {"type": "dungeon_unlock", "value": 1}, # Unlocked when Dungeon 1 is completed (Dungeon 2 becomes available)
		"description": "A dyslexic swift duelist with high damage but lower defenses."
	},
	"magi": {
		"display_name": "Magi",
		"weapon": "Buster",
		"counter_name": "Ambatakam",
		"stat_bonuses": {
			"health": 20, # More health
			"damage": - 5, # Less damage
			"durability": 8 # Much more durability
		},
		"animation_scene": "res://Sprites/Animation/Magi_Animation.tscn", # To be created
		"unlock_requirement": {"type": "dungeon_unlock", "value": 2}, # Unlocked when Dungeon 2 is completed (Dungeon 3 becomes available)
		"description": "A dyslexic tanker with a trusty buster and high durability and health."
	}
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
# Custom character stats popup reference
var character_stats_popup: CanvasLayer


func _ready():
	# Enhanced fade-in animation matching SettingScene style
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Preload character textures
	character_textures.unlocked = [
		preload("res://gui/Update/UI/lexia_card.png"), # Lexia
		preload("res://gui/Update/UI/Rani_Card5.png"), # Ragna (using same texture for now)
		preload("res://gui/Update/UI/lexia_card.png"), # Magi (using same texture for now)
	]
	character_textures.locked = [
		null, # Character 1 is always unlocked
		preload("res://gui/Update/UI/Ragna_Card_Locked.png"),
		preload("res://gui/Update/UI/Lexia_Card_Locked.png")
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
	
	# Get reference to custom character stats popup
	character_stats_popup = $CharacterStatsPopup
	
	# Connect close button for character stats popup (top-right X button)
	var close_x_button = character_stats_popup.get_node_or_null("PopupContainer/CenterContainer/StatsPanel/CloseButton")
	if close_x_button:
		if not close_x_button.pressed.is_connected(_on_character_stats_popup_close):
			close_x_button.pressed.connect(_on_character_stats_popup_close)
		if not close_x_button.mouse_entered.is_connected(_on_close_button_hover):
			close_x_button.mouse_entered.connect(_on_close_button_hover)
	
	# Connect close button for character stats popup (bottom close button if exists)
	var close_button = character_stats_popup.get_node_or_null("PopupContainer/CenterContainer/StatsPanel/StatsContent/CloseButton")
	if close_button:
		close_button.pressed.connect(_on_character_stats_popup_close)
	
	# Connect background click to close popup
	var popup_bg = character_stats_popup.get_node("PopupBackground")
	if popup_bg:
		popup_bg.gui_input.connect(_on_character_stats_background_clicked)
	
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

	$SelectButton.mouse_entered.connect(_on_select_button_hover_entered)

	# Connect hover sounds for each character texture button
	for i in range(CHARACTER_COUNT):
		var character_node = character_carousel.get_child(i)
		var texture_button = character_node.get_node("TextureButton")
		if texture_button and !texture_button.is_connected("mouse_entered", _on_character_texture_hover):
			texture_button.mouse_entered.connect(_on_character_texture_hover)
		# (Optional) play sound on focus via keyboard navigation
		if texture_button and !texture_button.is_connected("focus_entered", _on_character_texture_hover):
			texture_button.focus_entered.connect(_on_character_texture_hover)

# Show character stats in custom popup
func _show_character_stats_popup(character_index: int):
	var character_key = character_names[character_index].to_lower()
	var character_info = character_data[character_key]
	var bonuses = character_info["stat_bonuses"]
	
	# Update character title
	var title_label = character_stats_popup.get_node("PopupContainer/CenterContainer/StatsPanel/StatsContent/CharacterTitle")
	if title_label:
		title_label.text = character_info["display_name"]
	
	# Update weapon info
	var weapon_label = character_stats_popup.get_node("PopupContainer/CenterContainer/StatsPanel/StatsContent/WeaponContainer/WeaponLabel")
	if weapon_label:
		weapon_label.text = "Weapon: " + character_info["weapon"]
	
	var counter_label = character_stats_popup.get_node("PopupContainer/CenterContainer/StatsPanel/StatsContent/WeaponContainer/CounterLabel")
	if counter_label:
		counter_label.text = "Counter: " + character_info["counter_name"]
	
	# Update health bonus
	var health_value = character_stats_popup.get_node("PopupContainer/CenterContainer/StatsPanel/StatsContent/StatsContainer/HealthStat/HealthValue")
	if health_value:
		var health_bonus = bonuses["health"]
		health_value.text = " " + ("+" if health_bonus > 0 else "") + str(health_bonus)
		health_value.add_theme_color_override("font_color", Color.GREEN if health_bonus > 0 else (Color.RED if health_bonus < 0 else Color.WHITE))
	
	# Update attack bonus
	var attack_value = character_stats_popup.get_node("PopupContainer/CenterContainer/StatsPanel/StatsContent/StatsContainer/AttackStat/AttackValue")
	if attack_value:
		var attack_bonus = bonuses["damage"]
		attack_value.text = " " + ("+" if attack_bonus > 0 else "") + str(attack_bonus)
		attack_value.add_theme_color_override("font_color", Color.GREEN if attack_bonus > 0 else (Color.RED if attack_bonus < 0 else Color.WHITE))
	
	# Update durability bonus
	var durability_value = character_stats_popup.get_node("PopupContainer/CenterContainer/StatsPanel/StatsContent/StatsContainer/DurabilityStat/DurabilityValue")
	if durability_value:
		var durability_bonus = bonuses["durability"]
		durability_value.text = " " + ("+" if durability_bonus > 0 else "") + str(durability_bonus)
		durability_value.add_theme_color_override("font_color", Color.GREEN if durability_bonus > 0 else (Color.RED if durability_bonus < 0 else Color.WHITE))
	
	# Update description
	var description_label = character_stats_popup.get_node("PopupContainer/CenterContainer/StatsPanel/StatsContent/Description")
	if description_label:
		description_label.text = character_info["description"]
	
	# Show the popup with animation
	character_stats_popup.visible = true
	var popup_container = character_stats_popup.get_node("PopupContainer")
	if popup_container:
		popup_container.modulate.a = 0.0
		popup_container.scale = Vector2(0.8, 0.8)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(popup_container, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(popup_container, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# Close character stats popup
func _close_character_stats_popup():
	var popup_container = character_stats_popup.get_node("PopupContainer")
	if popup_container:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(popup_container, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
		tween.tween_property(popup_container, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
		await tween.finished
	character_stats_popup.visible = false

# Event handlers for character stats popup
func _on_character_stats_popup_close():
	$ButtonClick.play()
	_close_character_stats_popup()

func _on_character_stats_background_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_character_stats_popup()


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
				current_character = characters.get("selected_character", 0)
			else:
				# Initialize characters data in Firebase if not exists
				await _initialize_character_data_in_firebase()
			
			# Also check dungeon progression to determine unlocked characters
			var dungeons = document.get_value("dungeons")
			if dungeons:
				var completed = dungeons.get("completed", {})
				
				# Check if dungeon 1 is completed to unlock Ragna (Dungeon 2 becomes available)
				if completed.has("1"):
					var dungeon1_data = completed["1"]
					if dungeon1_data.get("completed", false) or dungeon1_data.get("stages_completed", 0) >= 5:
						unlocked_characters = max(unlocked_characters, 2) # Ragna unlocked when Dungeon 2 becomes available
				
				# Check if dungeon 2 is completed to unlock Magi (Dungeon 3 becomes available)
				if completed.has("2"):
					var dungeon2_data = completed["2"]
					if dungeon2_data.get("completed", false) or dungeon2_data.get("stages_completed", 0) >= 5:
						unlocked_characters = max(unlocked_characters, 3) # Magi unlocked when Dungeon 3 becomes available
		else:
			print("Demo mode: Only Lexia available")
			await _initialize_character_data_in_firebase()
	else:
		# Demo mode - only Lexia available
		unlocked_characters = 1
		current_character = 0
		print("No auth: Only Lexia available")
	
	# Set initial carousel position and update display
	await get_tree().process_frame # Wait one frame to ensure scene is fully loaded
	
	# Test circular arrangement for characters
	print("=== CIRCULAR CHARACTER LAYOUT TEST ===")
	print("Testing circular arrangement for all scenarios:")
	print()
	
	# Test what each scenario should look like
	for test_center in range(CHARACTER_COUNT):
		print("SCENARIO: Character ", test_center + 1, " (", character_names[test_center], ") is centered")
		for i in range(CHARACTER_COUNT):
			var relative_pos = (i - test_center + CHARACTER_COUNT) % CHARACTER_COUNT
			var desc = ""
			match relative_pos:
				0: desc = "CENTER"
				1: desc = "RIGHT"
				2: desc = "LEFT"
			print("  Character ", i + 1, " (", character_names[i], ") would be: ", desc, " (relative_pos: ", relative_pos, ")")
		print()
	
	print("Current setup: Character ", current_character + 1, " (", character_names[current_character], ") should be centered")
	print("=== CHARACTER TEST COMPLETE ===")
	print()
	
	_center_carousel_on_current_character()
	update_character_display()

# Center the carousel on the current character (for initial positioning)
func _center_carousel_on_current_character():
	# Position all characters relative to the center position
	_position_all_characters_for_selection(current_character)

# Position all characters based on which one should be centered (CIRCULAR LAYOUT)
func _position_all_characters_for_selection(selected_index):
	print("=== CIRCULAR CHARACTER POSITIONING ===")
	print("Centering character index: ", selected_index, " (Character ", selected_index + 1, ")")
	print("CENTER_POSITION: ", CENTER_POSITION)
	print("CHARACTER_SPACING: ", CHARACTER_SPACING)
	
	# Circular positions: LEFT ← CENTER → RIGHT
	# We arrange characters in a circle around the selected one
	for i in range(CHARACTER_COUNT):
		var character_node = character_carousel.get_child(i)
		print("Node ", i, " name: ", character_node.name)
		print("Before - Character ", i + 1, " at x: ", character_node.position.x)
		
		# Calculate circular offset from selected character
		var relative_position = (i - selected_index + CHARACTER_COUNT) % CHARACTER_COUNT
		
		var new_x: float
		var position_desc: String
		
		# Position based on circular arrangement
		match relative_position:
			0: # This is the selected character - CENTER
				new_x = CENTER_POSITION
				position_desc = "CENTER"
			1: # Next character in sequence - RIGHT
				new_x = CENTER_POSITION + CHARACTER_SPACING
				position_desc = "RIGHT"
			2: # Previous character in sequence - LEFT
				new_x = CENTER_POSITION - CHARACTER_SPACING
				position_desc = "LEFT"
		
		# Apply the position
		character_node.position.x = new_x
		
		print("After - Character ", i + 1, " at x: ", new_x, " (", position_desc, ", relative_pos: ", relative_position, ")")
	
	print("=== CIRCULAR CHARACTER POSITIONING COMPLETE ===")
	print()

# Animate selection indicator for better dyslexia visibility
func _animate_selection_indicator(indicator: Control):
	# Stop any existing animation
	var existing_tween = null
	if indicator.has_meta("selection_tween"):
		existing_tween = indicator.get_meta("selection_tween")
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
		# Check if character is unlocked
		var is_unlocked = i < unlocked_characters
		
		# Set the appropriate texture and hover behavior
		if is_unlocked:
			if character_textures.unlocked[i] != null:
				texture_button.texture_normal = character_textures.unlocked[i]
		else:
			if character_textures.locked[i] != null:
				texture_button.texture_normal = character_textures.locked[i]
		
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
	$ButtonClick.play()
	current_character = (current_character + 1) % CHARACTER_COUNT # Wrap around: 0→1→2→0
	_animate_carousel_to_position(current_character)
	update_character_display()

func _on_previous_button_pressed():
	$ButtonClick.play()
	current_character = (current_character - 1 + CHARACTER_COUNT) % CHARACTER_COUNT # Wrap around: 2→1→0→2
	_animate_carousel_to_position(current_character)
	update_character_display()

# Handle character selection with circular behavior and stats display
func _on_character1_pressed():
	if unlocked_characters >= 1: # Character 1 is always unlocked
		# Show character stats in custom popup
		_show_character_stats_popup(0)
		
		# Update selection if different character
		if current_character != 0:
			current_character = 0
			_animate_carousel_to_position(current_character)
			update_character_display()
	# No else needed since Character 1 is always unlocked

func _on_character2_pressed():
	if unlocked_characters >= 2:
		# Show character stats in custom popup
		_show_character_stats_popup(1)
		
		# Update selection if different character
		if current_character != 1:
			current_character = 1
			_animate_carousel_to_position(current_character)
			update_character_display()
	else:
		# Show notification for locked character - Ragna requires completing dungeon 1 to unlock Dungeon 2
		notification_popup.show_notification("Character Locked!", "Unlock Dungeon 2 to unlock Ragna.", "OK")

func _on_character3_pressed():
	if unlocked_characters >= 3:
		# Show character stats in custom popup
		_show_character_stats_popup(2)
		
		# Update selection if different character
		if current_character != 2:
			current_character = 2
			_animate_carousel_to_position(current_character)
			update_character_display()
	else:
		# Show notification for locked character - Magi is coming soon
		notification_popup.show_notification("Character Locked!", "Magi is coming soon!", "OK")

# Animation function for smooth circular carousel movement
func _animate_carousel_to_position(character_index):
	var tween = create_tween()
	tween.set_ease(ANIMATION_EASE)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate all characters to their new circular positions
	for i in range(CHARACTER_COUNT):
		var character_node = character_carousel.get_child(i)
		
		# Calculate circular position (same logic as positioning function)
		var relative_position = (i - character_index + CHARACTER_COUNT) % CHARACTER_COUNT
		
		var target_x: float
		match relative_position:
			0: # Center
				target_x = CENTER_POSITION
			1: # Right
				target_x = CENTER_POSITION + CHARACTER_SPACING
			2: # Left
				target_x = CENTER_POSITION - CHARACTER_SPACING
		
		tween.parallel().tween_property(character_node, "position:x", target_x, ANIMATION_DURATION)

# Add handler for notification closed
func _on_notification_closed():
	# Handle notification close if needed
	pass

# Button hover handlers
func _on_back_button_hover_entered():
	$ButtonHover.play()
	var back_label = $BackButton/BackLabel
	if back_label:
		back_label.visible = true

func _on_back_button_hover_exited():
	var back_label = $BackButton/BackLabel
	if back_label:
		back_label.visible = false

func _on_next_button_hover_entered():
	$ButtonHover.play()
	var next_label = $NextButton/NextLabel
	if next_label:
		next_label.visible = true

func _on_next_button_hover_exited():
	var next_label = $NextButton/NextLabel
	if next_label:
		next_label.visible = false

func _on_previous_button_hover_entered():
	$ButtonHover.play()
	var previous_label = $PreviousButton/PreviousLabel
	if previous_label:
		previous_label.visible = true

func _on_previous_button_hover_exited():
	var previous_label = $PreviousButton/PreviousLabel
	if previous_label:
		previous_label.visible = false

func _on_select_button_hover_entered():
	$ButtonHover.play()

func _on_character_texture_hover():
	$ButtonHover.play()

func _on_close_button_hover():
	$ButtonHover.play()

func _on_back_button_pressed():
	$ButtonClick.play()
	_fade_out_and_change_scene("res://Scenes/MainMenu.tscn")

# Helper function to fade out before changing scenes
func _fade_out_and_change_scene(scene_path: String):
	# Enhanced fade-out animation matching SettingScene style
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_select_button_pressed():
	$ButtonClick.play()
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
			
			# Update selected character in characters data
			var characters = user_doc.get_value("characters")
			if not characters:
				characters = {}
			characters["selected_character"] = current_character
			
			# Also update player stats with character bonuses
			var character_key = character_names[current_character].to_lower()
			var character_info = character_data[character_key]
			var bonuses = character_info["stat_bonuses"]
			
			# Get current stats and apply bonuses while preserving base stats from leveling
			var stats = user_doc.get_value("stats")
			if stats and stats.has("player"):
				var player_stats = stats["player"]
				
				# PRESERVE base stats from leveling - these should never change when switching characters
				var base_health = player_stats.get("base_health", 100)
				var base_damage = player_stats.get("base_damage", 10)
				var base_durability = player_stats.get("base_durability", 5)
				
				# Apply NEW character bonuses to the SAME base stats
				player_stats["health"] = base_health + bonuses["health"]
				player_stats["damage"] = base_damage + bonuses["damage"]
				player_stats["durability"] = base_durability + bonuses["durability"]
				player_stats["skin"] = character_info["animation_scene"]
				
				# Store current character info
				player_stats["current_character"] = character_key
				
				stats["player"] = player_stats
				user_doc.add_or_update_field("stats", stats)
			
			user_doc.add_or_update_field("characters", characters)
			
			# Save the updated document
			var save_task = await collection.update(user_doc)
			if save_task and !("error" in save_task.keys()):
				print("Character selection saved: " + character_names[current_character])
				print("Applied stat bonuses: ", bonuses)
			else:
				print("Failed to save character selection")
	
	# For now, just print and go back to main menu
	print("Selected character: " + character_names[current_character])
	_fade_out_and_change_scene("res://Scenes/MainMenu.tscn")

# Initialize character data in Firebase
func _initialize_character_data_in_firebase():
	if not Firebase.Auth.auth:
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		var characters = document.get_value("characters")
		if not characters:
			# Initialize character data
			characters = {
				"unlocked_count": 1,
				"selected_character": 0,
				"unlock_notifications_shown": []
			}
			
			document.add_or_update_field("characters", characters)
			var updated_doc = await collection.update(document)
			if updated_doc:
				print("Character data initialized in Firebase")
