class_name BattleLogManager
extends Node

var battle_scene  # Reference to the main battle scene
var battle_log_container  # Reference to the log container
var user_scrolled = false  # Track if user has manually scrolled

# Introduction messages for different dungeons
var introduction_messages = {
	"dungeon1": [
		"You have arrived at The Plains. This is the start of your adventure.",
		"While traveling, you encounter a slime blocking your path."
	],
	"dungeon2": [
		"You enter The Forest, a more dangerous area with tougher enemies.",
		"The trees rustle as a snake appears before you."
	],
	"dungeon3": [
		"You've reached The Mountain, home to the most fearsome creatures.",
		"A goblin jumps out from behind the rocks, ready to attack!"
	]
}

# Log entry properties
var max_entries: int = 10
var entries: Array = []
var entry_colors = {
	"default": Color(5.1, 5.1, 5.1),     # White for standard messages
	"player": Color(0.4, 0.9, 0.4),      # Green for player actions
	"enemy": Color(0.9, 0.4, 0.4),       # Red for enemy actions
	"damage": Color(0.9, 0.6, 0.2),      # Orange for damage
	"heal": Color(0.2, 0.7, 0.9),        # Blue for healing
	"challenge": Color(0.9, 0.9, 0.2),   # Yellow for challenges
	"system": Color(0.7, 0.7, 0.7)       # Gray for system messages
}

# Reference to the log UI elements
@onready var battle_log: Control = null 
@onready var log_entries_container: VBoxContainer = null

func _init(scene):
	battle_scene = scene

func _ready():
	# Get reference to the battle log container
	battle_log_container = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/BattleLogContainer/ScrollContainer/LogsContainer")
	
	# Find battle log UI
	battle_log = get_node_or_null("../BattleUI/BattleLog")
	
	if battle_log:
		log_entries_container = battle_log.get_node_or_null("VBoxContainer/LogEntries")
	
	# Adding a test entry
	add_log_entry("Battle started", "system")

func display_introduction_messages():
	# Get the current dungeon number
	var dungeon_num = battle_scene.dungeon_manager.dungeon_num
	var dungeon_key = "dungeon" + str(dungeon_num)
	
	# Add dungeon introduction messages
	if introduction_messages.has(dungeon_key):
		for message in introduction_messages[dungeon_key]:
			add_message(message)
	
	# Add enemy introduction message
	add_message("You encounter a " + battle_scene.enemy_manager.enemy_name + "!")

func add_message(text):
	# Create a panel for the background
	var log_entry_panel = PanelContainer.new()
	
	# Add custom style for the background
	var style = StyleBoxTexture.new()
	style.texture = load("res://gui/ui_2.png")
	# Fix: Use content_margin_* properties instead of margin_*
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	log_entry_panel.add_theme_stylebox_override("panel", style)
	
	# Create the text label
	var log_entry = RichTextLabel.new()
	log_entry.bbcode_enabled = true
	log_entry.fit_content = true
	log_entry.scroll_active = false
	log_entry.custom_minimum_size = Vector2(0, 30)
	
	# Set the text
	log_entry.text = text
	
	# Add the label to the panel
	log_entry_panel.add_child(log_entry)
	
	# Add the panel to the log container
	battle_log_container.add_child(log_entry_panel)
	
	# Scroll to the bottom if user hasn't manually scrolled
	if !user_scrolled:
		_scroll_to_bottom()

func add_cancellation_message():
	# Add a specific message for challenge cancellation
	add_message("[color=#FFA500]You chose to cancel countering the enemy skill.[/color]")

# Add a function to handle challenge result logs specifically
func add_challenge_result_log(recognized_text: String, target_word: String, success: bool, bonus_damage: int = 0):
	var log_message = ""
	
	if success:
		log_message = "Challenge successful! You wrote: \"" + recognized_text + "\""
		if bonus_damage > 0:
			log_message += " (Bonus damage: +" + str(bonus_damage) + ")"
	else:
		log_message = "Challenge failed. You wrote: \"" + recognized_text + "\". The word was: \"" + target_word + "\""
	
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
	# Add timestamp
	var current_time = Time.get_time_dict_from_system()
	var timestamp = "%02d:%02d" % [current_time.hour, current_time.minute]
	var formatted_text = "[%s] %s" % [timestamp, text]
	
	# Add to entries array
	entries.push_back({"text": formatted_text, "type": type})
	
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
		var label = Label.new()
		label.text = entry.text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font", preload("res://Fonts/dyslexiafont/OpenDyslexic-Regular.otf"))
		label.add_theme_font_size_override("font_size", 16)
		
		# Set color based on entry type
		var color = entry_colors.get(entry.type, entry_colors.default)
		label.add_theme_color_override("font_color", color)
		
		# Add to container
		log_entries_container.add_child(label)
	
	# Make sure the newest entry is visible
	if log_entries_container.get_child_count() > 0:
		var scroll = log_entries_container.get_parent()
		if scroll is ScrollContainer:
			await get_tree().process_frame
			scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# Clear all log entries
func clear_log() -> void:
	entries.clear()
	update_ui()
