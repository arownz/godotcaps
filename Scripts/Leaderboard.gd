extends Control

# UI References
@onready var tab_container = $MainContainer/ContentContainer/TabContainer
@onready var back_button = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton

# Leaderboard data containers  
@onready var dungeon_list = $MainContainer/ContentContainer/TabContainer.get_node("Dungeon Rankings/ScrollContainer/VBoxContainer")
@onready var power_list = $MainContainer/ContentContainer/TabContainer.get_node("Power Scale/ScrollContainer/VBoxContainer")
@onready var word_list = $MainContainer/ContentContainer/TabContainer.get_node("Word Masters/ScrollContainer/VBoxContainer")
@onready var phonics_list = $MainContainer/ContentContainer/TabContainer.get_node("Phonics/ScrollContainer/VBoxContainer")
@onready var read_aloud_list = $MainContainer/ContentContainer/TabContainer.get_node("Read Aloud/ScrollContainer/VBoxContainer")
@onready var flip_quiz_list = $MainContainer/ContentContainer/TabContainer.get_node("Flip Quiz/ScrollContainer/VBoxContainer")

# Cached leaderboard data
var all_users_data = []
var current_user_data = {}

# Medal and rank textures
var medal_textures = {
	"bronze": preload("res://gui/Update/icons/bronze medal.png"),
	"silver": preload("res://gui/Update/icons/silver medal.png"),
	"gold": preload("res://gui/Update/icons/gold medal.png")
}

# Dungeon names
var dungeon_names = {
	1: "The Plain",
	2: "The Forest",
	3: "The Mountain"
}

# Theme colors based on ModuleScene.tscn cards
var theme_colors = {
	"phonics": Color(0.2, 0.6, 0.9), # Blue #3399e6
	"read_aloud": Color(0.2, 0.8, 0.4), # Green #33cc66
	"flip_quiz": Color(0.9, 0.3, 0.3), # Red #e64d4d
	"default": Color(0.15, 0.2, 0.3) # Default dark blue
}

# Rank colors - Gold, Silver, Bronze, Default White
var rank_colors = {
	1: Color(1.0, 0.85, 0.1), # Gold
	2: Color(0.75, 0.75, 0.75), # Silver
	3: Color(0.8, 0.5, 0.2), # Bronze
	"default": Color(1, 1, 1) # White for others
}

func _ready():
	# Add fade-in animation
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	_setup_tab_styling()
	_load_leaderboard_data()
	
	# Connect back button
	if back_button and not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

# Setup enhanced tab styling
func _setup_tab_styling():
	var tabs = tab_container
	
	# Create tab bar style
	var tab_style = StyleBoxFlat.new()
	tab_style.bg_color = Color(0.15, 0.2, 0.3, 0.8)
	tab_style.corner_radius_top_left = 8
	tab_style.corner_radius_top_right = 8
	tab_style.border_width_top = 2
	tab_style.border_width_left = 1
	tab_style.border_width_right = 1
	tab_style.border_color = Color(0.4, 0.5, 0.7, 0.8)
	tab_style.content_margin_left = 15
	tab_style.content_margin_right = 15
	tab_style.content_margin_top = 8
	tab_style.content_margin_bottom = 8
	
	# Active tab style
	var tab_selected_style = StyleBoxFlat.new()
	tab_selected_style.bg_color = Color(0.25, 0.35, 0.5, 0.9)
	tab_selected_style.corner_radius_top_left = 8
	tab_selected_style.corner_radius_top_right = 8
	tab_selected_style.border_width_top = 3
	tab_selected_style.border_width_left = 2
	tab_selected_style.border_width_right = 2
	tab_selected_style.border_color = Color(0.6, 0.7, 0.9, 1.0)
	tab_selected_style.content_margin_left = 15
	tab_selected_style.content_margin_right = 15
	tab_selected_style.content_margin_top = 8
	tab_selected_style.content_margin_bottom = 8
	
	# Apply styles to tab container
	tabs.add_theme_stylebox_override("tab_unselected", tab_style)
	tabs.add_theme_stylebox_override("tab_selected", tab_selected_style)
	
	# Tab font styling
	tabs.add_theme_color_override("font_unselected_color", Color(0.9, 0.9, 0.9, 0.8))
	tabs.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))

# Helper function to create a simple, reliable bordered container
# alignment: "center" for centered content, "left" for left-aligned content
func _create_bordered_container(content: Control, min_size: Vector2, bg_color: Color = Color(0.1, 0.1, 0.1, 0.8), alignment: String = "center") -> Control:
	var container = Panel.new()
	container.custom_minimum_size = min_size
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create simple StyleBox with solid background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0, 0, 0, 0.5)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	
	container.add_theme_stylebox_override("panel", style_box)
	
	# Wrap content based on alignment to achieve centering inside the panel
	if alignment == "center":
		# Use CenterContainer to center the label inside the panel
		var center_container = CenterContainer.new()
		center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		center_container.add_child(content)
		container.add_child(center_container)
	elif alignment == "left":
		# Use HBoxContainer with left alignment
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		hbox.add_child(content)
		container.add_child(hbox)
	else:
		# Default: add content directly
		container.add_child(content)
	
	return container

# Helper function to create a reliable label with guaranteed visibility
# For centered labels, do NOT use SIZE_EXPAND_FILL - let the label size naturally
# For left-aligned labels (like player name), use SIZE_EXPAND_FILL
func _create_reliable_label(text: String, font_size: int = 16, color: Color = Color(1, 1, 1), max_chars: int = 25, expand: bool = false) -> Label:
	var label = Label.new()
	
	# Set text with truncation for long names
	var display_text = text
	if text.length() > max_chars:
		display_text = text.substr(0, max_chars - 3) + "..."
		label.tooltip_text = text # Show full text on hover
	
	label.text = display_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Use dyslexia-friendly font
	label.add_theme_font_override("font", load("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	
	# Only expand if explicitly requested (for left-aligned name columns)
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	return label

# Helper function to create a properly centered avatar/profile picture column
# Uses manual positioning for precise control - adjust Vector2 values to center
func _create_avatar_column(user_data: Dictionary, container_size: Vector2 = Vector2(100, 50), avatar_size: Vector2 = Vector2(50, 100), bg_color: Color = Color(0.15, 0.2, 0.3)) -> Control:
	# Create texture rect for the portrait
	var profile_rect = TextureRect.new()
	# 🎯 CUSTOMIZE: Change avatar size here (width, height)
	profile_rect.custom_minimum_size = avatar_size # Default: Vector2(150, 100)
	profile_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load the profile picture
	var profile_id = user_data.get("profile_picture", "13")
	if profile_id == "default":
		profile_id = "13"
	var profile_texture = load("res://gui/ProfileScene/Profile/portrait" + profile_id + ".png")
	if profile_texture:
		profile_rect.texture = profile_texture
	
	# Create container for manual positioning
	var profile_center = Control.new()
	# 🎯 CUSTOMIZE: Change container size here (width, height)
	profile_center.custom_minimum_size = container_size # Default: Vector2(100, 50)
	profile_center.add_child(profile_rect)
	
	# 🎯 DYNAMIC CENTERING: Calculate position to center avatar in container
	# Formula: x = (container_width - avatar_width) / 2, y = (container_height - avatar_height) / 2
	var x_offset = (container_size.x - avatar_size.x) / 2
	var y_offset = (container_size.y - avatar_size.y) / 2
	profile_rect.position = Vector2(x_offset, y_offset)
	
	var avatar_container = _create_bordered_container(profile_center, container_size, bg_color, "center")
	
	return avatar_container

# Create consistent leaderboard row
# Used by: Power Scale, Word Masters, Phonics, Read Aloud, Flip Quiz tabs
func _create_leaderboard_row(user_data: Dictionary, rank: int, columns: Array, theme_color: Color = Color(0.15, 0.2, 0.3)) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	# 🎯 CUSTOMIZE ROW HEIGHT: Change the Y value (currently 60)
	row.custom_minimum_size = Vector2(0, 60) # Vector2(0, HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Determine rank color
	var rank_color = rank_colors.get(rank, rank_colors["default"])
	var rank_bg_color = theme_color
	if rank <= 3:
		rank_bg_color = Color(rank_color.r * 0.3, rank_color.g * 0.3, rank_color.b * 0.3, 0.8)
	
	# 🎯 CUSTOMIZE RANK COLUMN: Change Vector2(80, 50) for width/height
	# Create rank column
	var rank_text = "#" + str(rank) if rank <= 3 else str(rank)
	var rank_label = _create_reliable_label(rank_text, 16, rank_color)
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 50), rank_bg_color, "center")
	row.add_child(rank_container)
	
	# 🎯 CUSTOMIZE AVATAR COLUMN: Modify _create_avatar_column() parameters
	# _create_avatar_column(user_data, container_size, avatar_size, bg_color)
	# container_size = Vector2(width, height) of the bordered box
	# avatar_size = Vector2(width, height) of the actual portrait image
	# Create profile picture column using the helper for proper centering
	var profile_container = _create_avatar_column(user_data, Vector2(80, 50), Vector2(40, 40), theme_color)
	row.add_child(profile_container)
	
	# 🎯 CUSTOMIZE NAME COLUMN: Change Vector2(300, 50) for width/height
	# Create player name column
	var player_name = user_data.get("username", "Unknown")
	var name_color = Color(1, 1, 1)
	var name_bg_color = theme_color
	
	if user_data.get("is_current_user", false):
		name_color = Color(1, 1, 0.3)
		name_bg_color = Color(0.3, 0.25, 0.1, 0.8)
		player_name = "* " + player_name + " (You)"
	
	var name_label = _create_reliable_label(player_name, 16, name_color, 25, true) # expand=true for left-aligned name
	var name_container = _create_bordered_container(name_label, Vector2(300, 50), name_bg_color, "left")
	row.add_child(name_container)
	
	# 🎯 CUSTOMIZE DYNAMIC COLUMNS: Column widths/colors are defined in the populate functions
	# See: _populate_power_scale_rankings(), _populate_word_recognize_rankings(), etc.
	# Each column array entry: {"key": "stat_name", "width": 100, "color": Color(...)}
	# Add additional columns based on leaderboard type
	for i in range(columns.size()):
		var column_data = columns[i]
		var raw_value = user_data.get(column_data["key"], column_data.get("default", 0))
		
		# Format value if it's a progress percentage
		var value_text = str(raw_value)
		if column_data.has("format") and column_data["format"] == "%.1f%%":
			value_text = "%.1f%%" % raw_value
		
		var column_color = column_data.get("color", Color(1, 1, 1))
		var column_width = column_data.get("width", 100)
		
		var column_label = _create_reliable_label(value_text, 16, column_color)
		var column_container = _create_bordered_container(column_label, Vector2(column_width, 50), theme_color, "center")
		row.add_child(column_container)
	
	return row

# Load all user data from Firestore for leaderboard
func _load_leaderboard_data():
	if !Firebase.Auth or !Firebase.Auth.auth:
		print("Leaderboard: No authentication found")
		return
	
	print("Leaderboard: Loading user data from Firestore...")
	
	# Start loading immediately with proper error handling
	_load_data_async()

# Separate async function to prevent cancellation warnings
func _load_data_async():
	# Get current user data first
	var current_user_id = Firebase.Auth.auth.localid
	await _load_current_user_data(current_user_id)
	
	# Use Firebase.Firestore.list() to get all documents in the collection
	var documents_list = await Firebase.Firestore.list("dyslexia_users")
	
	if documents_list and documents_list.size() > 0:
		print("Leaderboard: Found " + str(documents_list.size()) + " user documents")
		
		# Process each document
		for doc in documents_list:
			if doc and doc.has_method("get_value"):
				var user_data = _extract_user_data(doc)
				if user_data.size() > 0:
					all_users_data.append(user_data)
		
		print("Leaderboard: Processed " + str(all_users_data.size()) + " valid user profiles")
		
		# Populate all ranking tabs
		_populate_all_leaderboards()
	else:
		print("Leaderboard: No user documents found")

# Load current user's data separately
func _load_current_user_data(user_id: String):
	var collection = Firebase.Firestore.collection("dyslexia_users")
	var document = await collection.get_doc(user_id)
	
	if document and !("error" in document.keys() and document.get_value("error")):
		current_user_data = _extract_user_data(document)
		current_user_data["is_current_user"] = true
		print("Leaderboard: Current user data loaded")
	else:
		print("Leaderboard: Failed to load current user data")

# Extract user data from Firebase document
func _extract_user_data(document) -> Dictionary:
	var user_data = {}
	
	# Get profile data
	var profile = document.get_value("profile")
	if profile and typeof(profile) == TYPE_DICTIONARY:
		user_data["username"] = profile.get("username", "Unknown Player")
		user_data["profile_picture"] = profile.get("profile_picture", "13")
		user_data["rank"] = profile.get("rank", "bronze")
	else:
		user_data["username"] = "Unknown Player"
		user_data["profile_picture"] = "13"
		user_data["rank"] = "bronze"
	
	# Get player stats
	var stats = document.get_value("stats")
	if stats and typeof(stats) == TYPE_DICTIONARY:
		var player_stats = stats.get("player", {})
		user_data["level"] = player_stats.get("level", 1)
		user_data["health"] = player_stats.get("health", 100)
		user_data["damage"] = player_stats.get("damage", 10)
		user_data["durability"] = player_stats.get("durability", 5)
	else:
		user_data["level"] = 1
		user_data["health"] = 100
		user_data["damage"] = 10
		user_data["durability"] = 5
	
	# Get dungeon progress
	var dungeons = document.get_value("dungeons")
	if dungeons and typeof(dungeons) == TYPE_DICTIONARY:
		var completed = dungeons.get("completed", {})
		var progress = dungeons.get("progress", {})
		
		user_data["current_dungeon"] = progress.get("current_dungeon", 1)
		user_data["current_stage"] = progress.get("current_stage", 1)
		user_data["enemies_defeated"] = progress.get("enemies_defeated", 0)
		
		# Calculate highest completed dungeon
		var highest_dungeon = 0
		var total_stages_completed = 0
		
		for dungeon_id in ["1", "2", "3"]:
			if completed.has(dungeon_id):
				var dungeon_data = completed[dungeon_id]
				var stages_completed = dungeon_data.get("stages_completed", 0)
				total_stages_completed += stages_completed
				
				if dungeon_data.get("completed", false):
					highest_dungeon = max(highest_dungeon, int(dungeon_id))
				elif stages_completed > 0:
					highest_dungeon = max(highest_dungeon, int(dungeon_id))
		
		user_data["highest_dungeon"] = highest_dungeon
		user_data["total_stages_completed"] = total_stages_completed
		user_data["rank"] = _calculate_rank_from_progress(highest_dungeon, total_stages_completed)
	else:
		user_data["current_dungeon"] = 1
		user_data["current_stage"] = 1
		user_data["highest_dungeon"] = 0
		user_data["total_stages_completed"] = 0
		user_data["enemies_defeated"] = 0
		user_data["rank"] = "bronze"
	
	# Get word challenges data (Journey Mode STT/Whiteboard)
	var word_challenges = document.get_value("word_challenges")
	if word_challenges and typeof(word_challenges) == TYPE_DICTIONARY:
		var completed = word_challenges.get("completed", {})
		user_data["stt_completed"] = completed.get("stt", 0)
		user_data["whiteboard_completed"] = completed.get("whiteboard", 0)
		user_data["word_recognize"] = user_data["stt_completed"] + user_data["whiteboard_completed"]
	else:
		user_data["stt_completed"] = 0
		user_data["whiteboard_completed"] = 0
		user_data["word_recognize"] = 0
	
	# Get modules data for Module Mode leaderboards
	var modules = document.get_value("modules")
	if modules and typeof(modules) == TYPE_DICTIONARY:
		# Phonics Module
		var phonics = modules.get("phonics", {})
		var letters_completed = phonics.get("letters_completed", [])
		var sight_words_completed = phonics.get("sight_words_completed", [])
		
		user_data["phonics_letters"] = letters_completed.size()
		user_data["phonics_sight_words"] = sight_words_completed.size()
		user_data["phonics_total"] = letters_completed.size() + sight_words_completed.size()
		user_data["phonics_progress"] = phonics.get("progress", 0.0)
		
		# Read Aloud Module
		var read_aloud = modules.get("read_aloud", {})
		var guided_activities = read_aloud.get("guided_reading", {}).get("activities_completed", [])
		var syllable_activities = read_aloud.get("syllable_workshop", {}).get("activities_completed", [])
		
		user_data["read_aloud_guided"] = guided_activities.size()
		user_data["read_aloud_syllable"] = syllable_activities.size()
		user_data["read_aloud_total"] = guided_activities.size() + syllable_activities.size()
		user_data["read_aloud_progress"] = read_aloud.get("progress", 0.0)
		
		# Flip Quiz Module
		var flip_quiz = modules.get("flip_quiz", {})
		var animals_sets = flip_quiz.get("animals", {}).get("sets_completed", [])
		var vehicles_sets = flip_quiz.get("vehicles", {}).get("sets_completed", [])
		user_data["flip_quiz_animals"] = animals_sets.size()
		user_data["flip_quiz_vehicles"] = vehicles_sets.size()
		user_data["flip_quiz_total"] = animals_sets.size() + vehicles_sets.size()
		user_data["flip_quiz_progress"] = flip_quiz.get("progress", 0.0)
	else:
		# Default values for modules
		user_data["phonics_letters"] = 0
		user_data["phonics_sight_words"] = 0
		user_data["phonics_total"] = 0
		user_data["phonics_progress"] = 0.0
		user_data["read_aloud_guided"] = 0
		user_data["read_aloud_syllable"] = 0
		user_data["read_aloud_total"] = 0
		user_data["read_aloud_progress"] = 0.0
		user_data["flip_quiz_animals"] = 0
		user_data["flip_quiz_vehicles"] = 0
		user_data["flip_quiz_total"] = 0
		user_data["flip_quiz_progress"] = 0.0
	
	# Calculate power score (combined stats)
	user_data["power_score"] = user_data["health"] + user_data["damage"] + user_data["durability"]
	
	return user_data

# Calculate rank based on dungeon progress
func _calculate_rank_from_progress(highest_dungeon: int, total_stages: int) -> String:
	if highest_dungeon >= 3 and total_stages >= 10:
		return "gold"
	elif highest_dungeon >= 2 and total_stages >= 5:
		return "silver"
	else:
		return "bronze"

# Populate all leaderboards with consistent headers and rows
func _populate_all_leaderboards():
	_populate_dungeon_rankings()
	_populate_power_scale_rankings()
	_populate_word_recognize_rankings()
	_populate_phonics_rankings()
	_populate_read_aloud_rankings()
	_populate_flip_quiz_rankings()

# Populate dungeon rankings tab
func _populate_dungeon_rankings():
	# Clear existing entries
	for child in dungeon_list.get_children():
		child.queue_free()
	
	# Sort users by dungeon progress
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["current_dungeon"] != b["current_dungeon"]:
			return a["current_dungeon"] > b["current_dungeon"]
		if a["current_stage"] != b["current_stage"]:
			return a["current_stage"] > b["current_stage"]
		if a["enemies_defeated"] != b["enemies_defeated"]:
			return a["enemies_defeated"] > b["enemies_defeated"]
		return a["level"] > b["level"]
	)
	
	# Add header
	var header = _create_dungeon_header()
	dungeon_list.add_child(header)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	dungeon_list.add_child(spacer)
	
	# Add user entries
	for i in range(sorted_users.size()):
		var user = sorted_users[i]
		var entry = _create_dungeon_row(user, i + 1)
		dungeon_list.add_child(entry)

# Create dungeon header
func _create_dungeon_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	header.custom_minimum_size = Vector2(0, 60)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var rank_label = _create_reliable_label("RANK", 16, Color(1, 0.9, 0.3))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(rank_container)
	
	var pic_label = _create_reliable_label("AVATAR", 14, Color(0.8, 0.9, 1))
	var pic_container = _create_bordered_container(pic_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(pic_container)
	
	var name_label = _create_reliable_label("PLAYER NAME", 16, Color(0.9, 0.95, 1))
	var name_container = _create_bordered_container(name_label, Vector2(300, 50), theme_colors["default"], "center")
	header.add_child(name_container)
	
	var dungeon_label = _create_reliable_label("DUNGEON", 16, Color(0.7, 0.9, 0.7))
	var dungeon_container = _create_bordered_container(dungeon_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(dungeon_container)
	
	var stage_label = _create_reliable_label("STAGE", 16, Color(0.9, 0.7, 0.9))
	var stage_container = _create_bordered_container(stage_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(stage_container)
	
	var kills_label = _create_reliable_label("SLAIN ENEMY", 16, Color(1, 0.4, 0.4))
	var kills_container = _create_bordered_container(kills_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(kills_container)
	
	return header

# Create special dungeon entry with dungeon name display
# Used by: Dungeon Rankings tab ONLY (has custom columns)
func _create_dungeon_row(user_data: Dictionary, rank: int) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	# 🎯 CUSTOMIZE ROW HEIGHT: Change the Y value (currently 60)
	row.custom_minimum_size = Vector2(0, 60) # Vector2(0, HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Determine rank color
	var rank_color = rank_colors.get(rank, rank_colors["default"])
	var rank_bg_color = theme_colors["default"]
	if rank <= 3:
		rank_bg_color = Color(rank_color.r * 0.3, rank_color.g * 0.3, rank_color.b * 0.3, 0.8)
	
	# Get current dungeon early for both medal and dungeon column
	var current_dungeon = user_data.get("current_dungeon", 1)
	
	# 🎯 CUSTOMIZE RANK COLUMN: Change Vector2(80, 50) for width/height
	# Create rank column with medal based on dungeon level
	var rank_text = "#" + str(rank) if rank <= 3 else str(rank)
	var rank_label = _create_reliable_label(rank_text, 16, rank_color)
	
	# Create HBox to hold rank text and medal
	var rank_hbox = HBoxContainer.new()
	rank_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rank_hbox.add_theme_constant_override("separation", 5) # Space between rank and medal
	rank_hbox.add_child(rank_label)
	
	# Add medal based on user's dungeon level (1-3)
	if current_dungeon >= 1 and current_dungeon <= 3:
		var medal_texture: Texture2D = null
		match current_dungeon:
			1:
				medal_texture = load("res://gui/Update/icons/bronze medal.png")
			2:
				medal_texture = load("res://gui/Update/icons/silver medal.png")
			3:
				medal_texture = load("res://gui/Update/icons/gold medal.png")
		
		if medal_texture:
			var medal_rect = TextureRect.new()
			medal_rect.texture = medal_texture
			medal_rect.custom_minimum_size = Vector2(24, 24) # 🎯 CUSTOMIZE: Medal icon size
			medal_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			medal_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rank_hbox.add_child(medal_rect)
	
	var rank_container = _create_bordered_container(rank_hbox, Vector2(80, 50), rank_bg_color, "center")
	row.add_child(rank_container)
	
	# 🎯 CUSTOMIZE AVATAR COLUMN: Modify _create_avatar_column() parameters
	# _create_avatar_column(user_data, container_size, avatar_size, bg_color)
	# Create profile picture column using the helper for proper centering
	var profile_container = _create_avatar_column(user_data, Vector2(100, 50), Vector2(40, 40), theme_colors["default"])
	row.add_child(profile_container)
	
	# 🎯 CUSTOMIZE NAME COLUMN: Change Vector2(300, 50) for width/height
	# Create player name column
	var player_name = user_data.get("username", "Unknown")
	var name_color = Color(1, 1, 1)
	var name_bg_color = theme_colors["default"]
	
	if user_data.get("is_current_user", false):
		name_color = Color(1, 1, 0.3)
		name_bg_color = Color(0.3, 0.25, 0.1, 0.8)
		player_name = "* " + player_name + " (You)"
	
	var name_label = _create_reliable_label(player_name, 16, name_color, 25, true) # expand=true for left-aligned name
	var name_container = _create_bordered_container(name_label, Vector2(300, 50), name_bg_color, "left")
	row.add_child(name_container)
	
	# 🎯 CUSTOMIZE DUNGEON COLUMN: Change Vector2(100, 50) for width/height
	# Dungeon name instead of number
	var dungeon_name = dungeon_names.get(current_dungeon, "Unknown")
	var dungeon_label = _create_reliable_label(dungeon_name, 16, Color(0.7, 0.9, 0.7))
	var dungeon_container = _create_bordered_container(dungeon_label, Vector2(100, 50), theme_colors["default"], "center")
	row.add_child(dungeon_container)
	
	# 🎯 CUSTOMIZE STAGE COLUMN: Change Vector2(80, 50) for width/height
	# Stage
	var stage_text = str(user_data.get("current_stage", 1))
	var stage_label = _create_reliable_label(stage_text, 16, Color(0.9, 0.7, 0.9))
	var stage_container = _create_bordered_container(stage_label, Vector2(80, 50), theme_colors["default"], "center")
	row.add_child(stage_container)
	
	# 🎯 CUSTOMIZE KILLS COLUMN: Change Vector2(80, 50) for width/height
	# Kills
	var kills_text = str(user_data.get("enemies_defeated", 0))
	var kills_label = _create_reliable_label(kills_text, 16, Color(1, 0.4, 0.4))
	var kills_container = _create_bordered_container(kills_label, Vector2(80, 50), theme_colors["default"], "center")
	row.add_child(kills_container)
	
	return row

# Populate power scale rankings tab  
func _populate_power_scale_rankings():
	# Clear existing entries
	for child in power_list.get_children():
		child.queue_free()
	
	# Sort users by power score
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["power_score"] != b["power_score"]:
			return a["power_score"] > b["power_score"]
		return a["level"] > b["level"]
	)
	
	# Add header
	var header = _create_power_header()
	power_list.add_child(header)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	power_list.add_child(spacer)
	
	# Add user entries
	for i in range(sorted_users.size()):
		var user = sorted_users[i]
		# 🎯 CUSTOMIZE POWER SCALE COLUMNS: Change width/color for each column
		# Each entry: {"key": "data_field_name", "width": pixels, "color": Color(...)}
		var columns = [
			{"key": "level", "width": 80, "color": Color(1, 1, 0.3)}, # Level column
			{"key": "health", "width": 100, "color": Color(0.3, 1, 0.3)}, # Health column
			{"key": "damage", "width": 100, "color": Color(1, 0.3, 0.3)}, # Damage column
			{"key": "durability", "width": 80, "color": Color(0.3, 0.7, 1)}, # Durability column
			{"key": "power_score", "width": 100, "color": Color(1, 0.8, 0.2)} # Power Score column
		]
		
		var entry = _create_leaderboard_row(user, i + 1, columns, theme_colors["default"])
		power_list.add_child(entry)

# Create power header
func _create_power_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	header.custom_minimum_size = Vector2(0, 60)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var rank_label = _create_reliable_label("RANK", 16, Color(1, 0.9, 0.3))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(rank_container)
	
	var pic_label = _create_reliable_label("AVATAR", 14, Color(0.8, 0.9, 1))
	var pic_container = _create_bordered_container(pic_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(pic_container)

	var name_label = _create_reliable_label("PLAYER NAME", 16, Color(0.9, 0.95, 1))
	var name_container = _create_bordered_container(name_label, Vector2(300, 50), theme_colors["default"], "center")
	header.add_child(name_container)
	
	var level_label = _create_reliable_label("LEVEL", 16, Color(1, 1, 0.3))
	var level_container = _create_bordered_container(level_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(level_container)
	
	var health_label = _create_reliable_label("HEALTH", 15, Color(0.3, 1, 0.3))
	var health_container = _create_bordered_container(health_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(health_container)
	
	var damage_label = _create_reliable_label("DAMAGE", 15, Color(1, 0.3, 0.3))
	var damage_container = _create_bordered_container(damage_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(damage_container)
	
	var def_label = _create_reliable_label("DEF", 16, Color(0.3, 0.7, 1))
	var def_container = _create_bordered_container(def_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(def_container)
	
	var power_label = _create_reliable_label("POWER", 16, Color(1, 0.8, 0.2))
	var power_container = _create_bordered_container(power_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(power_container)
	
	return header

# Populate word recognize rankings tab
func _populate_word_recognize_rankings():
	# Clear existing entries
	for child in word_list.get_children():
		child.queue_free()
	
	# Sort users by total word recognize
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["word_recognize"] != b["word_recognize"]:
			return a["word_recognize"] > b["word_recognize"]
		return a["level"] > b["level"]
	)
	
	# Add header
	var header = _create_word_header()
	word_list.add_child(header)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	word_list.add_child(spacer)
	
	# Add user entries
	for i in range(sorted_users.size()):
		var user = sorted_users[i]
		var columns = [
			{"key": "stt_completed", "width": 100, "color": Color(0.3, 0.8, 1)},
			{"key": "whiteboard_completed", "width": 100, "color": Color(0.3, 1, 0.8)},
			{"key": "word_recognize", "width": 100, "color": Color(0.5, 1, 0.5)}
		]
		
		var entry = _create_leaderboard_row(user, i + 1, columns, theme_colors["default"])
		word_list.add_child(entry)

# Create word masters header
func _create_word_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	header.custom_minimum_size = Vector2(0, 60)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var rank_label = _create_reliable_label("RANK", 16, Color(1, 0.9, 0.3))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(rank_container)
	
	var pic_label = _create_reliable_label("AVATAR", 14, Color(0.8, 0.9, 1))
	var pic_container = _create_bordered_container(pic_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(pic_container)
	
	var name_label = _create_reliable_label("PLAYER NAME", 16, Color(0.9, 0.95, 1))
	var name_container = _create_bordered_container(name_label, Vector2(300, 50), theme_colors["default"], "center")
	header.add_child(name_container)
	
	var speech_label = _create_reliable_label("SPEECH", 15, Color(0.3, 0.8, 1))
	var speech_container = _create_bordered_container(speech_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(speech_container)
	
	var board_label = _create_reliable_label("WHITEBOARD", 15, Color(0.3, 1, 0.8))
	var board_container = _create_bordered_container(board_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(board_container)
	
	var total_label = _create_reliable_label("TOTAL", 16, Color(0.5, 1, 0.5))
	var total_container = _create_bordered_container(total_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(total_container)
	
	return header

# Populate Phonics rankings - BLUE theme
func _populate_phonics_rankings():
	# Clear existing entries
	for child in phonics_list.get_children():
		child.queue_free()
	
	# Sort users by phonics total
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["phonics_total"] != b["phonics_total"]:
			return a["phonics_total"] > b["phonics_total"]
		return a["phonics_progress"] > b["phonics_progress"]
	)
	
	# Add header
	var header = _create_phonics_header()
	phonics_list.add_child(header)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	phonics_list.add_child(spacer)
	
	# Add user entries
	for i in range(sorted_users.size()):
		var user = sorted_users[i]
		var columns = [
			{"key": "phonics_letters", "width": 100, "color": Color(0.3, 1, 0.3)},
			{"key": "phonics_sight_words", "width": 100, "color": Color(0.3, 0.7, 1)},
			{"key": "phonics_progress", "width": 120, "color": Color(1, 1, 0.3), "format": "%.1f%%"}
		]
		
		var entry = _create_leaderboard_row(user, i + 1, columns, theme_colors["default"])
		phonics_list.add_child(entry)

# Create phonics header - BLUE theme
func _create_phonics_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	header.custom_minimum_size = Vector2(0, 60)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var rank_label = _create_reliable_label("RANK", 16, Color(1, 0.9, 0.3))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(rank_container)
	
	var pic_label = _create_reliable_label("AVATAR", 14, Color(0.8, 0.9, 1))
	var pic_container = _create_bordered_container(pic_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(pic_container)
	
	var name_label = _create_reliable_label("PLAYER NAME", 16, Color(0.9, 0.95, 1))
	var name_container = _create_bordered_container(name_label, Vector2(300, 50), theme_colors["default"], "center")
	header.add_child(name_container)
	
	var letters_label = _create_reliable_label("LETTERS", 15, Color(0.3, 1, 0.3))
	var letters_container = _create_bordered_container(letters_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(letters_container)
	
	var words_label = _create_reliable_label("WORDS", 15, Color(0.3, 0.7, 1))
	var words_container = _create_bordered_container(words_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(words_container)
	
	var progress_label = _create_reliable_label("PROGRESS", 14, Color(1, 1, 0.3))
	var progress_container = _create_bordered_container(progress_label, Vector2(120, 50), theme_colors["default"], "center")
	header.add_child(progress_container)
	
	return header

# Populate Read Aloud rankings - GREEN theme
func _populate_read_aloud_rankings():
	# Clear existing entries
	for child in read_aloud_list.get_children():
		child.queue_free()
	
	# Sort users by read aloud total
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["read_aloud_total"] != b["read_aloud_total"]:
			return a["read_aloud_total"] > b["read_aloud_total"]
		return a["read_aloud_progress"] > b["read_aloud_progress"]
	)
	
	# Add header
	var header = _create_read_aloud_header()
	read_aloud_list.add_child(header)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	read_aloud_list.add_child(spacer)
	
	# Add user entries
	for i in range(sorted_users.size()):
		var user = sorted_users[i]
		var columns = [
			{"key": "read_aloud_guided", "width": 100, "color": Color(0.3, 1, 0.3)},
			{"key": "read_aloud_syllable", "width": 100, "color": Color(0.8, 0.3, 1)},
			{"key": "read_aloud_progress", "width": 120, "color": Color(1, 1, 0.3), "format": "%.1f%%"}
		]
		
		var entry = _create_leaderboard_row(user, i + 1, columns, theme_colors["default"])
		read_aloud_list.add_child(entry)

# Create read aloud header - GREEN theme
func _create_read_aloud_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	header.custom_minimum_size = Vector2(0, 60)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var rank_label = _create_reliable_label("RANK", 16, Color(1, 0.9, 0.3))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(rank_container)
	
	var pic_label = _create_reliable_label("AVATAR", 14, Color(0.8, 0.9, 1))
	var pic_container = _create_bordered_container(pic_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(pic_container)
	
	var name_label = _create_reliable_label("PLAYER NAME", 16, Color(0.9, 0.95, 1))
	var name_container = _create_bordered_container(name_label, Vector2(300, 50), theme_colors["default"], "center")
	header.add_child(name_container)
	
	var guided_label = _create_reliable_label("GUIDED", 15, Color(0.3, 1, 0.3))
	var guided_container = _create_bordered_container(guided_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(guided_container)
	
	var syllable_label = _create_reliable_label("SYLLABLE", 14, Color(0.8, 0.3, 1))
	var syllable_container = _create_bordered_container(syllable_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(syllable_container)
	
	var progress_label = _create_reliable_label("PROGRESS", 14, Color(1, 1, 0.3))
	var progress_container = _create_bordered_container(progress_label, Vector2(120, 50), theme_colors["default"], "center")
	header.add_child(progress_container)
	
	return header

# Populate Flip Quiz rankings - RED theme
func _populate_flip_quiz_rankings():
	# Clear existing entries
	for child in flip_quiz_list.get_children():
		child.queue_free()
	
	# Sort users by flip quiz total
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["flip_quiz_total"] != b["flip_quiz_total"]:
			return a["flip_quiz_total"] > b["flip_quiz_total"]
		return a["flip_quiz_progress"] > b["flip_quiz_progress"]
	)
	
	# Add header
	var header = _create_flip_quiz_header()
	flip_quiz_list.add_child(header)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	flip_quiz_list.add_child(spacer)
	
	# Add user entries
	for i in range(sorted_users.size()):
		var user = sorted_users[i]
		var columns = [
			{"key": "flip_quiz_animals", "width": 100, "color": Color(1, 0.6, 0.3)},
			{"key": "flip_quiz_vehicles", "width": 100, "color": Color(0.3, 0.8, 1)},
			{"key": "flip_quiz_progress", "width": 120, "color": Color(1, 1, 0.3), "format": "%.1f%%"}
		]
		
		var entry = _create_leaderboard_row(user, i + 1, columns, theme_colors["default"])
		flip_quiz_list.add_child(entry)

# Create flip quiz header - RED theme
func _create_flip_quiz_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	header.custom_minimum_size = Vector2(0, 60)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var rank_label = _create_reliable_label("RANK", 16, Color(1, 0.9, 0.3))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(rank_container)
	
	var pic_label = _create_reliable_label("AVATAR", 14, Color(0.8, 0.9, 1))
	var pic_container = _create_bordered_container(pic_label, Vector2(80, 50), theme_colors["default"], "center")
	header.add_child(pic_container)
	
	var name_label = _create_reliable_label("PLAYER NAME", 16, Color(0.9, 0.95, 1))
	var name_container = _create_bordered_container(name_label, Vector2(300, 50), theme_colors["default"], "center")
	header.add_child(name_container)
	
	var animals_label = _create_reliable_label("ANIMALS", 15, Color(1, 0.6, 0.3))
	var animals_container = _create_bordered_container(animals_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(animals_container)
	
	var vehicles_label = _create_reliable_label("VEHICLES", 14, Color(0.3, 0.8, 1))
	var vehicles_container = _create_bordered_container(vehicles_label, Vector2(100, 50), theme_colors["default"], "center")
	header.add_child(vehicles_container)
	
	var progress_label = _create_reliable_label("PROGRESS", 14, Color(1, 1, 0.3))
	var progress_container = _create_bordered_container(progress_label, Vector2(120, 50), theme_colors["default"], "center")
	header.add_child(progress_container)
	
	return header

# Back button handler
func _on_back_button_pressed():
	$ButtonClick.play()
	_fade_out_and_change_scene("res://Scenes/MainMenu.tscn")

# Helper function to fade out before changing scenes
func _fade_out_and_change_scene(scene_path: String):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_back_button_mouse_entered():
	$ButtonHover.play()