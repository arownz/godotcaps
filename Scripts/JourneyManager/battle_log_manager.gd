class_name BattleLogManager
extends Node

var battle_scene # Reference to the main battle scene
var battle_log_container # Reference to the log container
var user_scrolled = false # Track if user has manually scrolled

# Introduction messages for different dungeons with high contrast colors
var introduction_messages = {
	"dungeon1": {
		"arrival": "[color=#000000]You have arrived at The Plains. This is the start of your adventure.[/color]",
		"stage_intro": "[color=#000000]A wild creature blocks your path![/color]"
	},
	"dungeon2": {
		"arrival": "[color=#000000]You enter The Forest, a more dangerous area with tougher enemies.[/color]",
		"stage_intro": "[color=#000000]Something moves in the shadows![/color]"
	},
	"dungeon3": {
		"arrival": "[color=#000000]You've reached The Mountain, home to the most fearsome creatures.[/color]",
		"stage_intro": "[color=#000000]A powerful enemy appears![/color]"
	}
}

# Log entry properties
var max_entries: int = 10
var entries: Array = []

# Reference to the log UI elements
@onready var battle_log: Control = null
@onready var log_entries_container: VBoxContainer = null

# Convert colors to high contrast versions for dyslexia accessibility
func _convert_to_high_contrast_colors(text: String) -> String:
	var high_contrast_colors = {
		"#FFD700": "#B8860B", # Gold -> Dark goldenrod (high contrast)
		"#4CAF50": "#006400", # Light green -> Dark green (high contrast)
		"#FF6B6B": "#DC143C", # Light red -> Crimson (high contrast)
		"#42A5F5": "#000080", # Light blue -> Navy blue (high contrast)
		"#EB5E4B": "#8B0000", # Orange-red -> Dark red (high contrast)
		"#F09C2D": "#B8860B", # Orange -> Dark goldenrod (high contrast)
		"#FF0000": "#be0f0fff", # Red -> Dark red (high contrast)
		"#FFA500": "#FF8C00", # Orange -> Dark orange (high contrast)
		"#000000": "#000000" # Black stays black (already high contrast)
	}
	
	var result = text
	for original_color in high_contrast_colors:
		var new_color = high_contrast_colors[original_color]
		result = result.replace(original_color, new_color)
	
	return result

func _init(scene):
	battle_scene = scene

func _ready():
	# Get reference to the battle log container - this is the actual container we use
	battle_log_container = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/BattleLogContainer/ScrollContainer/LogsContainer")
	
	# Use the LogsContainer directly as our log entries container
	log_entries_container = battle_log_container
	
	print("BattleLogManager: Container found: ", log_entries_container != null)
	print("BattleLogManager: Container type: ", log_entries_container.get_class() if log_entries_container else "null")

func display_introduction_messages():
	# Get the current dungeon number and stage
	var dungeon_num = battle_scene.dungeon_manager.dungeon_num
	var current_stage = battle_scene.dungeon_manager.stage_num
	var dungeon_key = "dungeon" + str(dungeon_num)
	
	# Dungeon names for display
	var dungeon_names = {
		1: "The Plains",
		2: "The Forest",
		3: "The Mountain"
	}
	
	var dungeon_name = dungeon_names.get(dungeon_num, "Unknown Area")
	
	# Show dungeon arrival message only on stage 1
	if current_stage == 1 and introduction_messages.has(dungeon_key):
		add_message(introduction_messages[dungeon_key]["arrival"])
		add_message("[color=#000000]Stage " + str(current_stage) + " of 5[/color]")
	else:
		# For other stages, show simple progress
		add_message("[color=#000000]" + dungeon_name + " - Stage " + str(current_stage) + " of 5[/color]")
	
	# Add stage-specific context message (simplified for dyslexia-friendly reading)
	var stage_context = ""
	match current_stage:
		1:
			stage_context = "Your journey begins here."
		2:
			stage_context = "You move forward."
		3:
			stage_context = "Halfway through!"
		4:
			stage_context = "Almost there!"
		5:
			stage_context = "Final challenge!"
		_:
			stage_context = "Keep going!"
	
	add_message("[color=#000080]" + stage_context + "[/color]")
	
	# Add enemy encounter message
	if introduction_messages.has(dungeon_key):
		add_message(introduction_messages[dungeon_key]["stage_intro"])
	
	# Add specific enemy name
	add_message("[color=#8B0000]" + battle_scene.enemy_manager.enemy_name + " wants to fight![/color]")

func add_message(text):
	# Extract message type from color tags for better categorization
	var message_type = "default"
	if "[color=#4CAF50]" in text or "Victory" in text:
		message_type = "player"
	elif "[color=#EB5E4B]" in text or "[color=#FF0000]" in text:
		message_type = "enemy"
	elif "[color=#FFA500]" in text or "[color=#F09C2D]" in text:
		message_type = "challenge"
	elif "damage" in text.to_lower():
		message_type = "damage"
	elif "heal" in text.to_lower():
		message_type = "heal"
	
	# Use the consolidated logging system
	add_log_entry(text, message_type)

func add_cancellation_message():
	# Add a specific message for challenge cancellation
	add_message("[color=#FFA500]You chose to cancel countering the enemy skill.[/color]")

# Add a function to handle challenge result logs specifically
func add_challenge_result_log(recognized_text: String, target_word: String, success: bool, bonus_damage: int = 0, player_base_damage: int = 0):
	var log_message = ""
	
	# Get current character's counter name
	var counter_name = _get_current_character_counter_name()
	
	if success:
		log_message = "[color=#4CAF50]" + counter_name + " successful![/color] [color=#000000]You recognized: \"" + recognized_text + "\"[/color]"
		if bonus_damage > 0 and player_base_damage > 0:
			var total_damage = player_base_damage + bonus_damage
			log_message += "[color=#000000] (Damage: " + str(player_base_damage) + " + " + str(bonus_damage) + " = " + str(total_damage) + ")[/color]"
		elif bonus_damage > 0:
			log_message += "[color=#000000] (Bonus damage: +" + str(bonus_damage) + ")[/color]"
	else:
		log_message = "[color=#FF0000]" + counter_name + " failed.[/color] [color=#000000]You recognized: \"" + recognized_text + "\". The word was: \"" + target_word + "\"[/color]"
	
	# Use the existing add_log_entry function with a challenge type
	add_log_entry(log_message, "challenge")

# Get the current character's counter name from character data
func _get_current_character_counter_name() -> String:
	# Try to get character info from player manager or battle scene
	if battle_scene and battle_scene.has_method("get") and battle_scene.player_manager:
		var player_stats = battle_scene.player_manager.player_firebase_data
		if player_stats and player_stats.has("current_character"):
			var character_key = player_stats["current_character"]
			return _get_counter_name_for_character(character_key)
	
	# Fallback to default
	return "Blade Beam"

# Map character keys to their counter names
func _get_counter_name_for_character(character_key: String) -> String:
	var character_counters = {
		"lexia": "Blade Beam",
		"ragna": "Swift Pierce"
	}
	return character_counters.get(character_key, "Blade Beam")

func _scroll_to_bottom():
	# Wait for the next frame to ensure UI has updated
	await battle_scene.get_tree().process_frame
	
	# Access the ScrollContainer
	var scroll_container = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/BattleLogContainer/ScrollContainer")
	
	# Auto-scroll to the bottom
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _on_scroll_value_changed(value):
	# Detect if user has manually scrolled up
	var scroll_container = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/BattleLogContainer/ScrollContainer")
	var scroll_bar = scroll_container.get_v_scroll_bar()
	
	# If at the bottom, user is not considered to have scrolled
	if value >= scroll_bar.max_value - 50:
		user_scrolled = false
	else:
		user_scrolled = true

# Function to add a new log entry with optional type for color coding
func add_log_entry(text: String, type: String = "default") -> void:
	# Convert colors to high contrast for dyslexia accessibility
	var high_contrast_text = _convert_to_high_contrast_colors(text)
	
	# Check for duplicate entries BEFORE adding timestamp - compare just the content
	var clean_message_text = high_contrast_text
	var regex = RegEx.new()
	regex.compile("\\[/?[^\\]]*\\]")
	clean_message_text = regex.sub(clean_message_text, "", true).strip_edges()
	
	# Special handling for "Counter by" messages - prevent any duplication within 10 entries
	var is_counter_message = "counter by" in clean_message_text.to_lower()
	var is_success_message = "counter attack success" in clean_message_text.to_lower() or "successfully countered" in clean_message_text.to_lower()
	var entries_to_check = 10 if is_counter_message else 5
	
	# Never filter out success messages - they should always appear
	if is_success_message:
		print("Battle Log: Success message always allowed - " + clean_message_text)
	else:
		# Check if the same message content was added recently
		var recent_entries_to_check = min(entries_to_check, entries.size())
		for i in range(recent_entries_to_check):
			var recent_entry = entries[entries.size() - 1 - i]
			var recent_clean_text = recent_entry.get("original", recent_entry.text)
			var recent_clean_regex = RegEx.new()
			recent_clean_regex.compile("\\[/?[^\\]]*\\]")
			recent_clean_text = recent_clean_regex.sub(recent_clean_text, "", true).strip_edges()
			
			# Also remove timestamp pattern like "[12:34] " from the stored text for comparison
			var timestamp_regex = RegEx.new()
			timestamp_regex.compile("^\\[\\d{2}:\\d{2}\\] ")
			if recent_entry.has("text"):
				var text_without_timestamp = timestamp_regex.sub(recent_entry.text, "", 1)
				recent_clean_text = recent_clean_regex.sub(text_without_timestamp, "", true).strip_edges()
			
			# For counter messages, be extra strict about duplicates
			if is_counter_message and "counter by" in recent_clean_text.to_lower():
				print("Battle Log: Duplicate counter message prevented - " + clean_message_text)
				return
			elif clean_message_text == recent_clean_text:
				print("Battle Log: Duplicate content prevented - " + clean_message_text)
				return
	
	# Add timestamp with black color
	var current_time = Time.get_time_dict_from_system()
	var timestamp = "[color=#000000]%02d:%02d[/color]" % [current_time.hour, current_time.minute]
	
	# Strip bbcode tags for console output and clean display
	var clean_text = high_contrast_text
	clean_text = regex.sub(clean_text, "", true)
	
	var formatted_text = "[%s] %s" % [timestamp, clean_text]
	
	# Add to entries array (use high contrast text for display)
	entries.push_back({"text": formatted_text, "type": type, "original": high_contrast_text})
	
	# Keep only the last max_entries
	while entries.size() > max_entries:
		entries.pop_front()
	
	# Update UI if available
	update_ui()
	
	# Also print to console for debugging
	print("Battle Log: " + formatted_text)

# Update the UI with current entries
func update_ui() -> void:
	if not log_entries_container:
		return
	
	# Clear existing entries
	for child in log_entries_container.get_children():
		child.queue_free()
	
	# Add entries from newest to oldest
	for entry in entries:
		# Create a panel container for each log entry with ui_2.png background
		var log_entry_panel = PanelContainer.new()
		
		# Create and apply the ui_2.png style
		var style = StyleBoxTexture.new()
		style.texture = load("res://gui/Update/UI/ui.png")
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		log_entry_panel.add_theme_stylebox_override("panel", style)
		
		# Use RichTextLabel to support bbcode in original text
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.custom_minimum_size = Vector2(0, 30)
		
		# Use original text with bbcode if available, otherwise use clean text
		var display_text = entry.get("original", entry.text)
		var timestamp_part = entry.text.split("] ")[0] + "] "
		var message_part = display_text
		
		# If original has bbcode, combine timestamp with original message
		if entry.has("original"):
			label.text = timestamp_part + message_part
		else:
			label.text += entry.text

		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Apply dyslexia-friendly font - using preload to ensure it's loaded
		var dyslexia_font = preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf")
		label.add_theme_font_override("font", dyslexia_font)
		label.add_theme_font_override("normal_font", dyslexia_font)
		label.add_theme_font_override("bold_font", dyslexia_font)
		label.add_theme_font_override("italics_font", dyslexia_font)
		label.add_theme_font_override("bold_italics_font", dyslexia_font)
		label.add_theme_font_override("mono_font", dyslexia_font)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_font_size_override("normal_font_size", 16)
		
		# Set default font color to black for any text without explicit color tags
		label.add_theme_color_override("default_color", Color.BLACK)
		
		# Add font shadow for better readability and accessibility
		label.add_theme_color_override("font_shadow_color", Color(0.3, 0.3, 0.3, 0.8)) # Dark gray shadow
		# label.add_theme_constant_override("shadow_offset_x", 2)
		# label.add_theme_constant_override("shadow_offset_y", 2)
		label.add_theme_constant_override("shadow_outline_size", 4)
		
		# Add the label to the panel
		log_entry_panel.add_child(label)
		
		# Add the panel (with label inside) to the container
		log_entries_container.add_child(log_entry_panel)
	
	# Make sure the newest entry is visible
	if log_entries_container.get_child_count() > 0:
		# Get the ScrollContainer from our battle_scene reference
		var scroll_container = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/BattleLogContainer/ScrollContainer")
		if scroll_container is ScrollContainer:
			await get_tree().process_frame
			scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

# Add enhanced level-up message with high contrast colors (no emojis for dyslexia font compatibility)
func add_level_up_message(new_level: int, health_increase: int, damage_increase: int, durability_increase: int, new_health: int, new_damage: int, new_durability: int):
	# Main level-up announcement
	add_message("[color=#B8860B]LEVEL UP! You reached level " + str(new_level) + "![/color]")
	
	# Show stat increases with high contrast colors (deliberately low for dyslexic balance)
	add_message("[color=#006400]Health increased by +" + str(health_increase) + " (now " + str(new_health) + ")[/color]")
	add_message("[color=#8B0000]Damage increased by +" + str(damage_increase) + " (now " + str(new_damage) + ")[/color]")
	add_message("[color=#000080]Durability increased by +" + str(durability_increase) + " (now " + str(new_durability) + ")[/color]")

# Add motivational message encouraging word challenges for dyslexic learners
	# Check if near stat caps and provide appropriate encouragement
	if health_increase == 0 and damage_increase == 0 and durability_increase == 0:
		add_message("[color=#B8860B]Stats at maximum! Word challenges are your key to power![/color]")
	else:
		add_message("[color=#B8860B]Practice word challenges to grow even stronger![/color]")

# Clear all log entries
func clear_log() -> void:
	entries.clear()
	update_ui()