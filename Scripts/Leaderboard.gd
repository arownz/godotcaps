extends Control

# ========================================
# MODERN LEADERBOARD UI/UX REDESIGN
# Clean table structure with GridContainer
# Proper centering, hover effects, dyslexia-friendly
# ========================================

# UI References
@onready var tab_container = $MainContainer/ContentContainer/TabContainer
@onready var back_button = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton

# Leaderboard data containers - Using GridContainer structure
@onready var dungeon_grid = $MainContainer/ContentContainer/TabContainer.get_node("Dungeon Rankings/ScrollContainer/GridContainer")
@onready var power_grid = $MainContainer/ContentContainer/TabContainer.get_node("Power Scale/ScrollContainer/GridContainer")
@onready var word_grid = $MainContainer/ContentContainer/TabContainer.get_node("Word Masters/ScrollContainer/GridContainer")
@onready var phonics_grid = $MainContainer/ContentContainer/TabContainer.get_node("Phonics/ScrollContainer/GridContainer")
@onready var read_aloud_grid = $MainContainer/ContentContainer/TabContainer.get_node("Read Aloud/ScrollContainer/GridContainer")
@onready var flip_quiz_grid = $MainContainer/ContentContainer/TabContainer.get_node("Flip Quiz/ScrollContainer/GridContainer")

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

# Modern UI theme colors - Dyslexia-friendly color scheme
var theme_colors = {
	"header_bg": Color(0.12, 0.14, 0.18, 0.95),
	"row_even": Color(0.15, 0.17, 0.22, 0.85),
	"row_odd": Color(0.18, 0.20, 0.25, 0.85),
	"row_hover": Color(0.22, 0.28, 0.35, 0.95),
	"current_user": Color(0.35, 0.28, 0.10, 0.90),
	"border": Color(0.08, 0.09, 0.12, 0.95),
	"text_primary": Color(0.95, 0.93, 0.85, 1.0), # Warm off-white (easier on eyes)
	"text_secondary": Color(0.85, 0.88, 0.75, 1.0), # Soft greenish-white (high contrast, calm)
	"text_highlight": Color(1.0, 0.92, 0.4, 1.0), # Warm yellow (attention without strain)
	"gold": Color(1.0, 0.85, 0.1, 1.0),
	"silver": Color(0.85, 0.85, 0.85, 1.0), # Slightly warmer silver
	"bronze": Color(0.85, 0.6, 0.3, 1.0) # Brighter bronze for better visibility
}

# Column definitions for each leaderboard type
var column_configs = {
	"dungeon": [
		{"title": "RANK", "width": 80, "type": "rank"},
		{"title": "AVATAR", "width": 95, "type": "avatar"},
		{"title": "PLAYER", "width": 250, "type": "name"},
		{"title": "DUNGEON", "width": 165, "type": "dungeon_name"},
		{"title": "STAGE", "width": 100, "type": "current_stage"},
		{"title": "SLAIN", "width": 100, "type": "enemies_defeated"}
	],
	"power": [
		{"title": "RANK", "width": 80, "type": "rank"},
		{"title": "AVATAR", "width": 95, "type": "avatar"},
		{"title": "PLAYER", "width": 250, "type": "name"},
		{"title": "LEVEL", "width": 110, "type": "level"},
		{"title": "HEALTH", "width": 110, "type": "health"},
		{"title": "DAMAGE", "width": 110, "type": "damage"},
		{"title": "DURABILITY", "width": 160, "type": "durability"},
		{"title": "SCALE", "width": 100, "type": "power_score"}
	],
	"word": [
		{"title": "RANK", "width": 80, "type": "rank"},
		{"title": "AVATAR", "width":95, "type": "avatar"},
		{"title": "PLAYER", "width": 300, "type": "name"},
		{"title": "SPEECH", "width": 150, "type": "stt_completed"},
		{"title": "WHITEBOARD", "width": 175, "type": "whiteboard_completed"},
		{"title": "TOTAL", "width": 100, "type": "word_recognize"}
	],
	"phonics": [
		{"title": "RANK", "width": 80, "type": "rank"},
		{"title": "AVATAR", "width": 95, "type": "avatar"},
		{"title": "PLAYER", "width": 300, "type": "name"},
		{"title": "LETTERS", "width": 150, "type": "phonics_letters"},
		{"title": "WORDS", "width": 150, "type": "phonics_sight_words"},
		{"title": "PROGRESS", "width": 150, "type": "phonics_progress"}
	],
	"read_aloud": [
		{"title": "RANK", "width": 80, "type": "rank"},
		{"title": "AVATAR", "width": 95, "type": "avatar"},
		{"title": "PLAYER", "width": 300, "type": "name"},
		{"title": "GUIDED", "width": 150, "type": "read_aloud_guided"},
		{"title": "SYLLABLE", "width": 150, "type": "read_aloud_syllable"},
		{"title": "PROGRESS", "width": 150, "type": "read_aloud_progress"}
	],
	"flip_quiz": [
		{"title": "RANK", "width": 80, "type": "rank"},
		{"title": "AVATAR", "width": 95, "type": "avatar"},
		{"title": "PLAYER", "width": 300, "type": "name"},
		{"title": "ANIMALS", "width": 150, "type": "flip_quiz_animals"},
		{"title": "VEHICLES", "width": 150, "type": "flip_quiz_vehicles"},
		{"title": "PROGRESS", "width": 150, "type": "flip_quiz_progress"}
	]
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

# ========================================
# MODERN TABLE CREATION SYSTEM
# ========================================

# Create a table cell with proper styling
func _create_cell(content: Control, width: int, bg_color: Color, is_header: bool = false) -> Panel:
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(width, 50 if is_header else 60)
	
	# Create cell style
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = theme_colors["border"]
	
	if is_header:
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
	
	cell.add_theme_stylebox_override("panel", style)
	
	# Center the content
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(content)
	cell.add_child(center)
	
	return cell

# Create a label with proper styling
func _create_label(text: String, font_size: int = 16, color: Color = Color.WHITE, _bold: bool = false) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

# Create an avatar texture rect
func _create_avatar(user_data: Dictionary) -> TextureRect:
	var avatar = TextureRect.new()
	avatar.custom_minimum_size = Vector2(45, 45)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Set size flags to allow CenterContainer to properly center the avatar
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var profile_id = user_data.get("profile_picture", "13")
	if profile_id == "default":
		profile_id = "13"
	
	var profile_texture = load("res://gui/ProfileScene/Profile/portrait" + profile_id + ".png")
	if profile_texture:
		avatar.texture = profile_texture
	
	return avatar

# Create a table header row
func _create_header_row(grid: GridContainer, config_key: String):
	var columns = column_configs[config_key]
	grid.columns = columns.size()
	
	for column in columns:
		var label = _create_label(column["title"], 16, theme_colors["text_highlight"], true)
		var cell = _create_cell(label, column["width"], theme_colors["header_bg"], true)
		grid.add_child(cell)

# Create a data row with hover effect
func _create_data_row(grid: GridContainer, user_data: Dictionary, rank: int, config_key: String, row_index: int):
	var columns = column_configs[config_key]
	var is_current_user = user_data.get("is_current_user", false)
	var is_even_row = row_index % 2 == 0
	
	# Determine row background color
	var row_bg = theme_colors["current_user"] if is_current_user else (theme_colors["row_even"] if is_even_row else theme_colors["row_odd"])
	
	# Determine rank color for top 3
	var rank_color = theme_colors["text_primary"]
	if rank == 1:
		rank_color = theme_colors["gold"]
	elif rank == 2:
		rank_color = theme_colors["silver"]
	elif rank == 3:
		rank_color = theme_colors["bronze"]
	
	# Create cells for each column
	for column in columns:
		var content: Control
		var cell_bg = row_bg
		
		match column["type"]:
			"rank":
				# Rank with medal for top 3
				var hbox = HBoxContainer.new()
				hbox.alignment = BoxContainer.ALIGNMENT_CENTER
				hbox.add_theme_constant_override("separation", 8)
				
				var rank_label = _create_label(str(rank), 18, rank_color, true)
				hbox.add_child(rank_label)
				
				# Add medal for dungeon rankings
				if config_key == "dungeon" and user_data.has("current_dungeon"):
					var dungeon_level = user_data.get("current_dungeon", 0)
					if dungeon_level >= 1 and dungeon_level <= 3:
						var medal_icon = TextureRect.new()
						medal_icon.custom_minimum_size = Vector2(24, 24)
						medal_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
						medal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						
						match dungeon_level:
							1: medal_icon.texture = medal_textures["bronze"]
							2: medal_icon.texture = medal_textures["silver"]
							3: medal_icon.texture = medal_textures["gold"]
						
						hbox.add_child(medal_icon)
				
				content = hbox
			
			"avatar":
				content = _create_avatar(user_data)
			
			"name":
				var player_name = user_data.get("username", "Unknown")
				if is_current_user:
					player_name = player_name + " (You)"
				
				var name_label = _create_label(player_name, 16, theme_colors["text_highlight"] if is_current_user else theme_colors["text_primary"])
				# Truncate long names
				if player_name.length() > 20:
					name_label.text = player_name.substr(0, 17) + "..."
					name_label.tooltip_text = player_name
				content = name_label
			
			"dungeon_name":
				var dungeon_id = user_data.get("current_dungeon", 1)
				var dungeon_name = dungeon_names.get(dungeon_id, "Unknown")
				content = _create_label(dungeon_name, 16, Color(0.7, 0.9, 0.7))
			
			"phonics_progress", "read_aloud_progress", "flip_quiz_progress":
				var progress_value = user_data.get(column["type"], 0.0)
				content = _create_label("%.1f%%" % progress_value, 16, Color(1, 1, 0.4))
			
			_:
				# Default: display the value as-is
				var value = user_data.get(column["type"], 0)
				content = _create_label(str(value), 16, theme_colors["text_secondary"])
		
		var cell = _create_cell(content, column["width"], cell_bg, false)
		
		# Add hover effect to row cells (except header)
		_add_hover_effect_to_cell(cell, row_bg)
		
		grid.add_child(cell)

# Add hover effect to cell
func _add_hover_effect_to_cell(cell: Panel, original_color: Color):
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	
	cell.mouse_entered.connect(func():
		var style = cell.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.bg_color = theme_colors["row_hover"]
	)
	
	cell.mouse_exited.connect(func():
		var style = cell.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.bg_color = original_color
	)

# ========================================
# DATA LOADING & POPULATION
# ========================================

# Load all user data from Firestore for leaderboard
func _load_leaderboard_data():
	if !Firebase.Auth or !Firebase.Auth.auth:
		print("Leaderboard: No authentication found")
		return
	
	print("Leaderboard: Loading user data from Firestore...")
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

# ========================================
# POPULATE ALL LEADERBOARDS
# ========================================

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
	for child in dungeon_grid.get_children():
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
	
	# Create header
	_create_header_row(dungeon_grid, "dungeon")
	
	# Create data rows
	for i in range(sorted_users.size()):
		_create_data_row(dungeon_grid, sorted_users[i], i + 1, "dungeon", i)

# Populate power scale rankings tab
func _populate_power_scale_rankings():
	for child in power_grid.get_children():
		child.queue_free()
	
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["power_score"] != b["power_score"]:
			return a["power_score"] > b["power_score"]
		return a["level"] > b["level"]
	)
	
	_create_header_row(power_grid, "power")
	
	for i in range(sorted_users.size()):
		_create_data_row(power_grid, sorted_users[i], i + 1, "power", i)

# Populate word recognize rankings tab
func _populate_word_recognize_rankings():
	for child in word_grid.get_children():
		child.queue_free()
	
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["word_recognize"] != b["word_recognize"]:
			return a["word_recognize"] > b["word_recognize"]
		return a["level"] > b["level"]
	)
	
	_create_header_row(word_grid, "word")
	
	for i in range(sorted_users.size()):
		_create_data_row(word_grid, sorted_users[i], i + 1, "word", i)

# Populate Phonics rankings
func _populate_phonics_rankings():
	for child in phonics_grid.get_children():
		child.queue_free()
	
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["phonics_total"] != b["phonics_total"]:
			return a["phonics_total"] > b["phonics_total"]
		return a["phonics_progress"] > b["phonics_progress"]
	)
	
	_create_header_row(phonics_grid, "phonics")
	
	for i in range(sorted_users.size()):
		_create_data_row(phonics_grid, sorted_users[i], i + 1, "phonics", i)

# Populate Read Aloud rankings
func _populate_read_aloud_rankings():
	for child in read_aloud_grid.get_children():
		child.queue_free()
	
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["read_aloud_total"] != b["read_aloud_total"]:
			return a["read_aloud_total"] > b["read_aloud_total"]
		return a["read_aloud_progress"] > b["read_aloud_progress"]
	)
	
	_create_header_row(read_aloud_grid, "read_aloud")
	
	for i in range(sorted_users.size()):
		_create_data_row(read_aloud_grid, sorted_users[i], i + 1, "read_aloud", i)

# Populate Flip Quiz rankings
func _populate_flip_quiz_rankings():
	for child in flip_quiz_grid.get_children():
		child.queue_free()
	
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["flip_quiz_total"] != b["flip_quiz_total"]:
			return a["flip_quiz_total"] > b["flip_quiz_total"]
		return a["flip_quiz_progress"] > b["flip_quiz_progress"]
	)
	
	_create_header_row(flip_quiz_grid, "flip_quiz")
	
	for i in range(sorted_users.size()):
		_create_data_row(flip_quiz_grid, sorted_users[i], i + 1, "flip_quiz", i)

# ========================================
# NAVIGATION
# ========================================

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

