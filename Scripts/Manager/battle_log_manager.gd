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

func _init(scene):
	battle_scene = scene

func _ready():
	# Get reference to the battle log container
	battle_log_container = battle_scene.get_node("MainContainer/RightContainer/MarginContainer/VBoxContainer/BattleLogContainer/ScrollContainer/LogsContainer")

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
