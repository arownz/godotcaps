class_name BattleLogManager
extends Node

var battle_scene  # Reference to the main battle scene
var battle_log_container  # Reference to the log container
var user_scrolled = false  # Track if user has manually scrolled

# Introduction messages for different dungeons
var introduction_messages = {
	"dungeon1": [
		"[color=#000000]You have arrived at The Plains. This is the start of your adventure.[/color]",
		"[color=#000000]While traveling, you encounter an enemy blocking your path.[/color]"
	],
	"dungeon2": [
		"[color=#000000]You enter The Forest, a more dangerous area with tougher enemies.[/color]",
		"[color=#000000]The trees rustle as an enemy appears before you.[/color]"
	],
	"dungeon3": [
		"[color=#000000]You've reached The Mountain, home to the most fearsome creatures.[/color]",
		"[color=#000000]An enemy rams behind the rocks, ready to attack![/color]"
	]
}

# Log entry properties
var max_entries: int = 10
var entries: Array = []

# Reference to the log UI elements
@onready var battle_log: Control = null 
@onready var log_entries_container: VBoxContainer = null

func _init(scene):
	battle_scene = scene

func _ready():
	# Get reference to the battle log container - this is the actual container we use
	battle_log_container = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/BattleLogContainer/ScrollContainer/LogsContainer")
	
	# Use the LogsContainer directly as our log entries container
	log_entries_container = battle_log_container
	
	print("BattleLogManager: Container found: ", log_entries_container != null)
	print("BattleLogManager: Container type: ", log_entries_container.get_class() if log_entries_container else "null")
	
	# Adding a test entry
	add_log_entry("[color=#EB5E4B]Battle started[/color]", "system")

func display_introduction_messages():
	# Get the current dungeon number
	var dungeon_num = battle_scene.dungeon_manager.dungeon_num
	var dungeon_key = "dungeon" + str(dungeon_num)
	
	# Add dungeon introduction messages
	if introduction_messages.has(dungeon_key):
		for message in introduction_messages[dungeon_key]:
			add_message(message)
	
	# Add enemy introduction message
	add_message("[color=#000000]You encounter a " + battle_scene.enemy_manager.enemy_name + "![/color]")

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
func add_challenge_result_log(recognized_text: String, target_word: String, success: bool, bonus_damage: int = 0):
	var log_message = ""
	
	if success:
		log_message = "[color=#000000]Challenge successful! You wrote: \"" + recognized_text + "\"[/color]"
		if bonus_damage > 0:
			log_message += "[color=#000000] (Bonus damage: +" + str(bonus_damage) + ")[/color]"
	else:
		log_message = "[color=#000000]Challenge failed. You wrote: \"" + recognized_text + "\". The word was: \"" + target_word + "\"[/color]"
	
	# Use the existing add_log_entry function with a challenge type
	add_log_entry(log_message, "challenge")

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
	# Add timestamp with black color
	var current_time = Time.get_time_dict_from_system()
	var timestamp = "[color=#000000]%02d:%02d[/color]" % [current_time.hour, current_time.minute]
	
	# Strip bbcode tags for console output and clean display
	var clean_text = text
	var regex = RegEx.new()
	regex.compile("\\[/?[^\\]]*\\]")
	clean_text = regex.sub(clean_text, "", true)
	
	var formatted_text = "[%s] %s" % [timestamp, clean_text]
	
	# Check for duplicate entries to prevent spam
	if entries.size() > 0 and entries[-1].text == formatted_text:
		print("Battle Log: Duplicate entry prevented - " + formatted_text)
		return
	
	# Add to entries array
	entries.push_back({"text": formatted_text, "type": type, "original": text})
	
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
		style.texture = load("res://gui/Update/UI/ui_2.png")
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
			label.text = entry.text
		
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Apply dyslexia-friendly font - using preload to ensure it's loaded
		var dyslexia_font = preload("res://Fonts/dyslexiafont/OpenDyslexic-Bold-Italic.otf")
		print("BattleLogManager: Applying font: ", dyslexia_font != null)
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
		
		print("BattleLogManager: Font applied to label: ", label.get_theme_font("font") != null)
		
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

# Add enhanced level-up message with emojis and colors
func add_level_up_message(new_level: int, health_increase: int, damage_increase: int, durability_increase: int, new_health: int, new_damage: int, new_durability: int):
	# Main level-up announcement with celebration emoji
	add_message("[color=#FFD700]🎉 LEVEL UP! 🎉 You reached level " + str(new_level) + "![/color]")
	
	# Show stat increases with appropriate website emojis and colors
	add_message("[color=#4CAF50]💚 Health increased by +" + str(health_increase) + " (now " + str(new_health) + ")[/color]")
	add_message("[color=#FF6B6B]💪 Damage increased by +" + str(damage_increase) + " (now " + str(new_damage) + ")[/color]")
	add_message("[color=#42A5F5]🛡️ Durability increased by +" + str(durability_increase) + " (now " + str(new_durability) + ")[/color]")

# Add a motivational message for player growth
	add_message("[color=#FFD700]⭐ You are growing stronger! Keep fighting! ⭐[/color]")

# Clear all log entries
func clear_log() -> void:
	entries.clear()
	update_ui()