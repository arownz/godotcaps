extends Control

# UI References
@onready var tab_container = $MainContainer/ContentContainer/TabContainer
@onready var dungeon_ranking_tab = $MainContainer/ContentContainer/TabContainer.get_node("Dungeon Rankings")
@onready var power_scale_tab = $MainContainer/ContentContainer/TabContainer.get_node("Power Scale")
@onready var word_recognize_tab = $MainContainer/ContentContainer/TabContainer.get_node("Word Masters")
@onready var back_button = $MainContainer/HeaderPanel/HeaderContainer/TitleContainer/BackButton

# Leaderboard data containers  
@onready var dungeon_scroll = $MainContainer/ContentContainer/TabContainer.get_node("Dungeon Rankings/ScrollContainer")
@onready var dungeon_list = $MainContainer/ContentContainer/TabContainer.get_node("Dungeon Rankings/ScrollContainer/VBoxContainer")
@onready var power_scroll = $MainContainer/ContentContainer/TabContainer.get_node("Power Scale/ScrollContainer")
@onready var power_list = $MainContainer/ContentContainer/TabContainer.get_node("Power Scale/ScrollContainer/VBoxContainer")
@onready var word_scroll = $MainContainer/ContentContainer/TabContainer.get_node("Word Masters/ScrollContainer")
@onready var word_list = $MainContainer/ContentContainer/TabContainer.get_node("Word Masters/ScrollContainer/VBoxContainer")

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

# Helper function to create a bordered container
func _create_bordered_container(content: Control, min_size: Vector2, bg_color: Color = Color(0.1, 0.1, 0.1, 0.3)) -> Control:
	var container = Panel.new()
	container.custom_minimum_size = min_size
	
	# Create StyleBox for border
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.4, 0.4, 0.4, 0.8)
	# Reduced margins to prevent text clipping
	style_box.content_margin_left = 8
	style_box.content_margin_right = 8
	style_box.content_margin_top = 5
	style_box.content_margin_bottom = 5
	
	container.add_theme_stylebox_override("panel", style_box)
	container.add_child(content)
	
	return container

# Helper function to create a responsive bordered container with flexible width
func _create_responsive_bordered_container(content: Control, min_size: Vector2, max_size: Vector2, bg_color: Color = Color(0.1, 0.1, 0.1, 0.3), size_flags: int = Control.SIZE_EXPAND_FILL) -> Control:
	var container = Panel.new()
	container.custom_minimum_size = min_size
	container.size_flags_horizontal = size_flags
	
	# Set maximum size if specified
	if max_size.x > 0 and max_size.x > min_size.x:
		container.custom_minimum_size.x = min(container.custom_minimum_size.x, max_size.x)
	
	# Create StyleBox for border
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.4, 0.4, 0.4, 0.8)
	style_box.content_margin_left = 5
	style_box.content_margin_right = 5
	style_box.content_margin_top = 3
	style_box.content_margin_bottom = 3
	
	container.add_theme_stylebox_override("panel", style_box)
	
	# Ensure content fits properly
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(content)
	
	return container

# Simplified header function for dungeon rankings with reliable text display
func _create_simple_dungeon_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	header.custom_minimum_size = Vector2(0, 55)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Rank
	var rank_label = _create_simple_label("RANK", 16, Color(1, 0.9, 0.3))
	var rank_container = _create_bordered_container(rank_label, Vector2(100, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(rank_container)
	
	# Avatar
	var pic_label = _create_simple_label("AVATAR", 14, Color(0.8, 0.9, 1))
	var pic_container = _create_bordered_container(pic_label, Vector2(80, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(pic_container)
	
	# Player
	var name_label = _create_simple_label("PLAYER", 16, Color(0.9, 0.95, 1))
	var name_container = _create_bordered_container(name_label, Vector2(280, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(name_container)
	
	# Medal
	var medal_label = _create_simple_label("MEDAL", 16, Color(1, 0.8, 0.2))
	var medal_container = _create_bordered_container(medal_label, Vector2(100, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(medal_container)
	
	# Current Dungeon
	var dungeon_label = _create_simple_label("DUNGEON", 16, Color(0.7, 0.9, 0.7))
	var dungeon_container = _create_bordered_container(dungeon_label, Vector2(140, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(dungeon_container)
	
	# Current Stage
	var stages_label = _create_simple_label("STAGE", 16, Color(0.9, 0.7, 0.9))
	var stages_container = _create_bordered_container(stages_label, Vector2(90, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(stages_container)
	
	# Enemies Defeated
	var enemies_label = _create_simple_label("KILLS", 16, Color(1, 0.4, 0.4))
	var enemies_container = _create_bordered_container(enemies_label, Vector2(90, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(enemies_container)
	
	return header

# Simplified header function for power scale rankings with reliable text display
func _create_simple_power_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	header.custom_minimum_size = Vector2(0, 55)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Rank
	var rank_label = _create_simple_label("RANK", 16, Color(1, 0.9, 0.3))
	var rank_container = _create_bordered_container(rank_label, Vector2(100, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(rank_container)
	
	# Avatar
	var pic_label = _create_simple_label("AVATAR", 14, Color(0.8, 0.9, 1))
	var pic_container = _create_bordered_container(pic_label, Vector2(80, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(pic_container)
	
	# Player
	var name_label = _create_simple_label("PLAYER", 16, Color(0.9, 0.95, 1))
	var name_container = _create_bordered_container(name_label, Vector2(250, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(name_container)
	
	# Level
	var level_label = _create_simple_label("LVL", 16, Color(1, 1, 0.3))
	var level_container = _create_bordered_container(level_label, Vector2(80, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(level_container)
	
	# Health (green color)
	var health_label = _create_simple_label("HP", 16, Color(0.3, 1, 0.3))
	var health_container = _create_bordered_container(health_label, Vector2(100, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(health_container)
	
	# Attack (red color)
	var attack_label = _create_simple_label("DMG", 16, Color(1, 0.3, 0.3))
	var attack_container = _create_bordered_container(attack_label, Vector2(100, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(attack_container)
	
	# Durability (blue color)
	var durability_label = _create_simple_label("DEF", 16, Color(0.3, 0.7, 1))
	var durability_container = _create_bordered_container(durability_label, Vector2(110, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(durability_container)
	
	# Power Scale (yellow color)
	var power_label = _create_simple_label("SCALE", 16, Color(1, 0.8, 0.2))
	var power_container = _create_bordered_container(power_label, Vector2(100, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(power_container)
	
	return header

# Simplified header function for word recognize rankings with reliable text display
func _create_simple_word_recognize_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	header.custom_minimum_size = Vector2(0, 55)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Rank
	var rank_label = _create_simple_label("RANK", 16, Color(1, 0.9, 0.3))
	var rank_container = _create_bordered_container(rank_label, Vector2(100, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(rank_container)
	
	# Avatar
	var pic_label = _create_simple_label("AVATAR", 14, Color(0.8, 0.9, 1))
	var pic_container = _create_bordered_container(pic_label, Vector2(80, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(pic_container)
	
	# Player
	var name_label = _create_simple_label("PLAYER", 16, Color(0.9, 0.95, 1))
	var name_container = _create_bordered_container(name_label, Vector2(280, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(name_container)
	
	# STT Completed (blue-green color)
	var stt_label = _create_simple_label("STT", 16, Color(0.3, 0.8, 1))
	var stt_container = _create_bordered_container(stt_label, Vector2(100, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(stt_container)
	
	# Whiteboard Completed (green-blue color)
	var wb_label = _create_simple_label("BOARD", 14, Color(0.3, 1, 0.8))
	var wb_container = _create_bordered_container(wb_label, Vector2(120, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(wb_container)
	
	# Total WordRecognize (bright green color)
	var total_label = _create_simple_label("TOTAL", 16, Color(0.5, 1, 0.5))
	var total_container = _create_bordered_container(total_label, Vector2(100, 50), Color(0.15, 0.25, 0.35, 0.8))
	header.add_child(total_container)
	
	return header

# Helper function to create a simple, reliable label
func _create_simple_label(text: String, font_size: int = 16, color: Color = Color(1, 1, 1), alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	
	# Remove size expansion to prevent overflow
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Ensure text fits within bounds
	label.clip_contents = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	return label

# Helper function to create a responsive label that truncates long text
func _create_responsive_label(text: String, max_chars: int, font_size: int = 16, color: Color = Color(1, 1, 1), alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label = Label.new()
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://Fonts/dyslexiafont/OpenDyslexic-Bold.otf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	
	# Set basic sizing
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Enable text clipping
	label.clip_contents = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# Truncate text if too long
	var display_text = text
	if text.length() > max_chars:
		display_text = text.substr(0, max_chars - 3) + "..."
	
	label.text = display_text
	
	return label

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
	
	# Connect back button (guard against duplicate connection)
	if back_button:
		if not back_button.pressed.is_connected(_on_back_button_pressed):
			back_button.pressed.connect(_on_back_button_pressed)

# Setup enhanced tab styling for modern appearance
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
	
	# Hover style
	var tab_hover_style = StyleBoxFlat.new()
	tab_hover_style.bg_color = Color(0.2, 0.25, 0.35, 0.85)
	tab_hover_style.corner_radius_top_left = 8
	tab_hover_style.corner_radius_top_right = 8
	tab_hover_style.border_width_top = 2
	tab_hover_style.border_width_left = 1
	tab_hover_style.border_width_right = 1
	tab_hover_style.border_color = Color(0.5, 0.6, 0.8, 0.9)
	tab_hover_style.content_margin_left = 15
	tab_hover_style.content_margin_right = 15
	tab_hover_style.content_margin_top = 8
	tab_hover_style.content_margin_bottom = 8
	
	# Apply styles to tab container
	tabs.add_theme_stylebox_override("tab_unselected", tab_style)
	tabs.add_theme_stylebox_override("tab_selected", tab_selected_style)
	tabs.add_theme_stylebox_override("tab_hovered", tab_hover_style)
	
	# Tab font styling
	tabs.add_theme_color_override("font_unselected_color", Color(0.9, 0.9, 0.9, 0.8))
	tabs.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
	tabs.add_theme_color_override("font_hovered_color", Color(1, 1, 0.9, 0.9))
	
	# Panel background for tab content
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.5, 0.7, 0.6)
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 15
	panel_style.content_margin_bottom = 15
	
	tabs.add_theme_stylebox_override("panel", panel_style)

# Load all user data from Firestore for leaderboard
func _load_leaderboard_data():
	if !Firebase.Auth or !Firebase.Auth.auth:
		print("Leaderboard: No authentication found")
		return ;
	
	print("Leaderboard: Loading user data from Firestore...")
	
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
		_populate_dungeon_rankings()
		_populate_power_scale_rankings()
		_populate_word_recognize_rankings()
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
		
		# Get current dungeon and stage from progress
		var current_dungeon = progress.get("current_dungeon", 1)
		var current_stage = progress.get("current_stage", 1)
		var enemies_defeated = progress.get("enemies_defeated", 0)
		
		# Calculate highest completed dungeon and total stages for ranking purposes
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
					# Partially completed dungeon
					highest_dungeon = max(highest_dungeon, int(dungeon_id))
		
		# Use current dungeon/stage for display, but highest completed for ranking
		user_data["current_dungeon"] = current_dungeon
		user_data["current_stage"] = current_stage
		user_data["highest_dungeon"] = highest_dungeon
		user_data["total_stages_completed"] = total_stages_completed
		user_data["enemies_defeated"] = enemies_defeated
		
		# Update rank based on progress
		user_data["rank"] = _calculate_rank_from_progress(highest_dungeon, total_stages_completed)
	else:
		user_data["current_dungeon"] = 1
		user_data["current_stage"] = 1
		user_data["highest_dungeon"] = 0
		user_data["total_stages_completed"] = 0
		user_data["enemies_defeated"] = 0
		user_data["rank"] = "bronze"
	
	# Get word challenges data
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
	
	# Calculate power score (combined stats)
	user_data["power_score"] = user_data["health"] + user_data["damage"] + user_data["durability"]
	
	return user_data

# Calculate rank based on dungeon progress
func _calculate_rank_from_progress(highest_dungeon: int, total_stages: int) -> String:
	if highest_dungeon >= 3 and total_stages >= 10: # Completed multiple dungeons
		return "gold"
	elif highest_dungeon >= 2 and total_stages >= 5: # Reached second dungeon
		return "silver"
	else:
		return "bronze"

# Populate dungeon rankings tab
func _populate_dungeon_rankings():
	# Clear existing entries
	for child in dungeon_list.get_children():
		child.queue_free()
	
	# Sort users by dungeon progress (current dungeon first, then current stage, then enemies defeated)
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
	var header = _create_simple_dungeon_header() # Use simplified version
	dungeon_list.add_child(header)
	
	# Add spacer after header
	var header_spacer = Control.new()
	header_spacer.custom_minimum_size = Vector2(0, 5)
	dungeon_list.add_child(header_spacer)
	
	# Add user entries
	for i in range(sorted_users.size()):
		var user = sorted_users[i]
		var entry = _create_dungeon_entry(user, i + 1)
		dungeon_list.add_child(entry)
		
		# Highlight current user
		if user.get("is_current_user", false):
			entry.modulate = Color(1.2, 1.2, 0.8) # Slightly golden tint
		
		# Add small spacer between entries (except last one)
		if i < sorted_users.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 3)
			dungeon_list.add_child(spacer)

# Populate power scale rankings tab  
func _populate_power_scale_rankings():
	# Clear existing entries
	for child in power_list.get_children():
		child.queue_free()
	
	# Sort users by power score (health + damage + durability)
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["power_score"] != b["power_score"]:
			return a["power_score"] > b["power_score"]
		return a["level"] > b["level"]
	)
		# Add header
	var header = _create_simple_power_header() # Use simplified version
	power_list.add_child(header)
	
	# Add spacer after header
	var header_spacer = Control.new()
	header_spacer.custom_minimum_size = Vector2(0, 5)
	power_list.add_child(header_spacer)
		# Add user entries
	for i in range(sorted_users.size()):
		var user = sorted_users[i]
		var entry = _create_power_entry(user, i + 1)
		power_list.add_child(entry)
		
		# Highlight current user
		if user.get("is_current_user", false):
			entry.modulate = Color(1.2, 1.2, 0.8) # Slightly golden tint
		
		# Add small spacer between entries (except last one)
		if i < sorted_users.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 3)
			power_list.add_child(spacer)

# Create entry for dungeon rankings
func _create_dungeon_entry(user_data: Dictionary, rank: int) -> Control:
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 3)
	entry.custom_minimum_size = Vector2(0, 60)
	
	# Add alternating row colors for better readability
	var row_bg = Panel.new()
	if rank % 2 == 0:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.95, 0.96, 0.98, 0.3)
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_right = 8
		style_box.corner_radius_bottom_left = 8
		row_bg.add_theme_stylebox_override("panel", style_box)
		row_bg.z_index = -1
	
	# Rank number with special styling for top 3
	var rank_text = str(rank)
	var rank_color = Color(1, 1, 1)
	var bg_color = Color(0.15, 0.2, 0.3, 0.7)
	
	if rank == 1:
		rank_text = "#" + str(rank)
		rank_color = Color(1, 0.85, 0.2)
		bg_color = Color(0.8, 0.6, 0.1, 0.3)
	elif rank == 2:
		rank_text = "#" + str(rank)
		rank_color = Color(0.9, 0.9, 0.9)
		bg_color = Color(0.6, 0.6, 0.6, 0.3)
	elif rank == 3:
		rank_text = "#" + str(rank)
		rank_color = Color(0.8, 0.5, 0.2)
		bg_color = Color(0.6, 0.4, 0.1, 0.3)
	
	var rank_label = _create_simple_label(rank_text, 16, rank_color)
	var rank_container = _create_bordered_container(rank_label, Vector2(100, 55), bg_color)
	entry.add_child(rank_container)
	
	# Profile picture with better styling
	var profile_rect = TextureRect.new()
	profile_rect.custom_minimum_size = Vector2(45, 45)
	profile_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var profile_id = user_data.get("profile_picture", "13")
	if profile_id == "default":
		profile_id = "13"
	var profile_texture = load("res://gui/ProfileScene/Profile/portrait" + profile_id + ".png")
	if profile_texture:
		profile_rect.texture = profile_texture
	
	var profile_center = Control.new()
	profile_center.custom_minimum_size = Vector2(80, 60)
	profile_center.add_child(profile_rect)
	profile_rect.position = Vector2(17, 7)
	var profile_container = _create_bordered_container(profile_center, Vector2(80, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(profile_container)
	
	# Player name with highlighting for current user
	var player_name = user_data.get("username", "Unknown")
	var name_color = Color(1, 1, 1)
	var name_bg_color = Color(0.1, 0.15, 0.25, 0.7)
	
	if user_data.get("is_current_user", false):
		name_color = Color(1, 1, 0.3)
		name_bg_color = Color(0.3, 0.25, 0.1, 0.5)
		player_name = "* " + player_name + " (You)"
	
	var name_label = _create_responsive_label(player_name, 25, 16, name_color, HORIZONTAL_ALIGNMENT_LEFT)
	var name_container = _create_bordered_container(name_label, Vector2(280, 55), name_bg_color)
	entry.add_child(name_container)
	
	# Medal with glow effect
	var medal_rect = TextureRect.new()
	medal_rect.custom_minimum_size = Vector2(35, 35)
	medal_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var rank_key = user_data.get("rank", "bronze")
	if medal_textures.has(rank_key):
		medal_rect.texture = medal_textures[rank_key]
	
	var medal_center = Control.new()
	medal_center.custom_minimum_size = Vector2(100, 60)
	medal_center.add_child(medal_rect)
	medal_rect.position = Vector2(32, 12)
	var medal_container = _create_bordered_container(medal_center, Vector2(100, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(medal_container)
	
	# Current dungeon with color coding
	var dungeon_text = ""
	var dungeon_color = Color(0.8, 0.8, 0.8)
	var current_dungeon = user_data.get("current_dungeon", 1)
	if current_dungeon > 0:
		dungeon_text = dungeon_names.get(current_dungeon, "Unknown")
		# Color code dungeons
		if current_dungeon == 1:
			dungeon_color = Color(0.6, 0.9, 0.6) # Green for Plains
		elif current_dungeon == 2:
			dungeon_color = Color(0.6, 0.8, 0.4) # Forest Green
		elif current_dungeon == 3:
			dungeon_color = Color(0.7, 0.7, 0.9) # Mountain Blue
	else:
		dungeon_text = "Not Started"
		dungeon_color = Color(0.6, 0.6, 0.6)
	
	var dungeon_label = _create_simple_label(dungeon_text, 16, dungeon_color)
	var dungeon_container = _create_bordered_container(dungeon_label, Vector2(140, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(dungeon_container)
	
	# Current stage with progress indication
	var current_stage = user_data.get("current_stage", 1)
	var stages_text = str(current_stage)
	var stages_color = Color(1, 1, 1)
	
	# Color code based on stage progress within dungeon
	if current_stage >= 5:
		stages_color = Color(0.2, 1, 0.2) # Green for boss stage
	elif current_stage >= 4:
		stages_color = Color(1, 1, 0.2) # Yellow for high stages
	elif current_stage >= 3:
		stages_color = Color(1, 0.7, 0.2) # Orange for mid stages
	elif current_stage >= 2:
		stages_color = Color(0.8, 0.8, 0.8) # Light gray for early stages
	else:
		stages_color = Color(0.9, 0.9, 0.9) # White for first stage
	
	var stages_label = _create_simple_label(stages_text, 16, stages_color)
	var stages_container = _create_bordered_container(stages_label, Vector2(90, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(stages_container)
	
	# Enemies defeated with color coding
	var enemies_defeated = user_data.get("enemies_defeated", 0)
	var enemies_text = str(enemies_defeated)
	var enemies_color = Color(1, 1, 1)
	
	# Color code based on enemies defeated
	if enemies_defeated >= 50:
		enemies_color = Color(1, 0.2, 0.2) # Red for high kill count
	elif enemies_defeated >= 25:
		enemies_color = Color(1, 0.6, 0.2) # Orange for medium kill count
	elif enemies_defeated >= 10:
		enemies_color = Color(1, 1, 0.2) # Yellow for some kills
	elif enemies_defeated > 0:
		enemies_color = Color(0.8, 0.8, 0.8) # Light gray for few kills
	else:
		enemies_color = Color(0.5, 0.5, 0.5) # Dark gray for no kills
	
	var enemies_label = _create_simple_label(enemies_text, 16, enemies_color)
	var enemies_container = _create_bordered_container(enemies_label, Vector2(90, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(enemies_container)
	
	return entry

# Create entry for power scale rankings
func _create_power_entry(user_data: Dictionary, rank: int) -> Control:
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 3)
	entry.custom_minimum_size = Vector2(0, 60)
	
	# Add alternating row colors for better readability
	var row_bg = Panel.new()
	if rank % 2 == 0:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.95, 0.96, 0.98, 0.3)
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_right = 8
		style_box.corner_radius_bottom_left = 8
		row_bg.add_theme_stylebox_override("panel", style_box)
		row_bg.z_index = -1
	
	# Rank number with special styling for top 3
	var rank_text = str(rank)
	var rank_color = Color(1, 1, 1)
	var bg_color = Color(0.15, 0.2, 0.3, 0.7)
	
	if rank == 1:
		rank_text = "#" + str(rank)
		rank_color = Color(1, 0.85, 0.2)
		bg_color = Color(0.8, 0.6, 0.1, 0.3)
	elif rank == 2:
		rank_text = "#" + str(rank)
		rank_color = Color(0.9, 0.9, 0.9)
		bg_color = Color(0.6, 0.6, 0.6, 0.3)
	elif rank == 3:
		rank_text = "#" + str(rank)
		rank_color = Color(0.8, 0.5, 0.2)
		bg_color = Color(0.6, 0.4, 0.1, 0.3)
	
	var rank_label = _create_simple_label(rank_text, 16, rank_color)
	var rank_container = _create_bordered_container(rank_label, Vector2(100, 55), bg_color)
	entry.add_child(rank_container)
	
	# Profile picture
	var profile_rect = TextureRect.new()
	profile_rect.custom_minimum_size = Vector2(45, 45)
	profile_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var profile_id = user_data.get("profile_picture", "13")
	if profile_id == "default":
		profile_id = "13"
	var profile_texture = load("res://gui/ProfileScene/Profile/portrait" + profile_id + ".png")
	if profile_texture:
		profile_rect.texture = profile_texture
	
	var profile_center = Control.new()
	profile_center.custom_minimum_size = Vector2(80, 60)
	profile_center.add_child(profile_rect)
	profile_rect.position = Vector2(17, 7)
	var profile_container = _create_bordered_container(profile_center, Vector2(80, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(profile_container)
	
	# Player name with highlighting for current user
	var player_name = user_data.get("username", "Unknown")
	var name_color = Color(1, 1, 1)
	var name_bg_color = Color(0.1, 0.15, 0.25, 0.7)
	
	if user_data.get("is_current_user", false):
		name_color = Color(1, 1, 0.3)
		name_bg_color = Color(0.3, 0.25, 0.1, 0.5)
		player_name = "* " + player_name + " (You)"
	
	var name_label = _create_responsive_label(player_name, 22, 16, name_color, HORIZONTAL_ALIGNMENT_LEFT)
	var name_container = _create_bordered_container(name_label, Vector2(250, 55), name_bg_color)
	entry.add_child(name_container)
	
	# Level with color coding
	var level = user_data.get("level", 1)
	var level_color = Color(1, 1, 0.3)
	if level >= 10:
		level_color = Color(1, 0.8, 0.2) # Gold for high levels
	elif level >= 5:
		level_color = Color(0.8, 0.8, 1) # Light blue for medium levels
	
	var level_label = _create_simple_label(str(level), 16, level_color)
	var level_container = _create_bordered_container(level_label, Vector2(80, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(level_container)
	
	# Health (with color)
	var health = user_data.get("health", 100)
	var health_label = _create_simple_label(str(health), 16, Color(0.3, 1, 0.3))
	var health_container = _create_bordered_container(health_label, Vector2(100, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(health_container)
	
	# Attack/Damage (with color)
	var damage = user_data.get("damage", 10)
	var damage_label = _create_simple_label(str(damage), 16, Color(1, 0.3, 0.3))
	var damage_container = _create_bordered_container(damage_label, Vector2(100, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(damage_container)
	
	# Durability/Defense (with color)
	var durability = user_data.get("durability", 5)
	var durability_label = _create_simple_label(str(durability), 16, Color(0.3, 0.7, 1))
	var durability_container = _create_bordered_container(durability_label, Vector2(110, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(durability_container)
	
	# Power score (total with special styling)
	var power_score = user_data.get("power_score", health + damage + durability)
	var power_text = str(power_score)
	var power_color = Color(1, 0.8, 0.2)
	
	# Add special indicators for high power
	if power_score >= 200:
		power_color = Color(1, 0.2, 0.2) # Red for very high power
	elif power_score >= 150:
		power_color = Color(1, 0.6, 0.2) # Orange for high power
	elif power_score >= 120:
		power_color = Color(1, 1, 0.2) # Yellow for good power
	
	var power_label = _create_simple_label(power_text, 16, power_color)
	var power_container = _create_bordered_container(power_label, Vector2(100, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(power_container)
	
	return entry

# Create entry for word recognize rankings
func _create_word_recognize_entry(user_data: Dictionary, rank: int) -> Control:
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 3)
	entry.custom_minimum_size = Vector2(0, 60)
	
	# Add alternating row colors for better readability
	var row_bg = Panel.new()
	if rank % 2 == 0:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.95, 0.96, 0.98, 0.3)
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_right = 8
		style_box.corner_radius_bottom_left = 8
		row_bg.add_theme_stylebox_override("panel", style_box)
		row_bg.z_index = -1
	
	# Rank number with special styling for top 3
	var rank_text = str(rank)
	var rank_color = Color(1, 1, 1)
	var bg_color = Color(0.15, 0.2, 0.3, 0.7)
	
	if rank == 1:
		rank_text = "#" + str(rank)
		rank_color = Color(1, 0.85, 0.2)
		bg_color = Color(0.8, 0.6, 0.1, 0.3)
	elif rank == 2:
		rank_text = "#" + str(rank)
		rank_color = Color(0.9, 0.9, 0.9)
		bg_color = Color(0.6, 0.6, 0.6, 0.3)
	elif rank == 3:
		rank_text = "#" + str(rank)
		rank_color = Color(0.8, 0.5, 0.2)
		bg_color = Color(0.6, 0.4, 0.1, 0.3)
	
	var rank_label = _create_simple_label(rank_text, 16, rank_color)
	var rank_container = _create_bordered_container(rank_label, Vector2(100, 55), bg_color)
	entry.add_child(rank_container)
	
	# Profile picture
	var profile_rect = TextureRect.new()
	profile_rect.custom_minimum_size = Vector2(45, 45)
	profile_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var profile_id = user_data.get("profile_picture", "13")
	if profile_id == "default":
		profile_id = "13"
	var profile_texture = load("res://gui/ProfileScene/Profile/portrait" + profile_id + ".png")
	if profile_texture:
		profile_rect.texture = profile_texture
	
	var profile_center = Control.new()
	profile_center.custom_minimum_size = Vector2(80, 60)
	profile_center.add_child(profile_rect)
	profile_rect.position = Vector2(17, 7)
	var profile_container = _create_bordered_container(profile_center, Vector2(80, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(profile_container)
	
	# Player name with highlighting for current user
	var player_name = user_data.get("username", "Unknown")
	var name_color = Color(1, 1, 1)
	var name_bg_color = Color(0.1, 0.15, 0.25, 0.7)
	
	if user_data.get("is_current_user", false):
		name_color = Color(1, 1, 0.3)
		name_bg_color = Color(0.3, 0.25, 0.1, 0.5)
		player_name = "* " + player_name + " (You)"
	
	var name_label = _create_responsive_label(player_name, 25, 16, name_color, HORIZONTAL_ALIGNMENT_LEFT)
	var name_container = _create_bordered_container(name_label, Vector2(280, 55), name_bg_color)
	entry.add_child(name_container)
	
	# STT challenges completed with icons
	var stt_completed = user_data.get("stt_completed", 0)
	var stt_text = str(stt_completed)
	var stt_color = Color(0.3, 1, 0.3)
	
	if stt_completed >= 50:
		stt_text += " PRO"
		stt_color = Color(0.2, 1, 0.2)
	elif stt_completed >= 25:
		stt_text += " ADV"
		stt_color = Color(0.5, 1, 0.5)
	elif stt_completed >= 10:
		stt_color = Color(0.7, 1, 0.7)
	
	var stt_label = _create_simple_label(stt_text, 16, stt_color)
	var stt_container = _create_bordered_container(stt_label, Vector2(100, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(stt_container)
	
	# Whiteboard challenges completed with icons
	var whiteboard_completed = user_data.get("whiteboard_completed", 0)
	var whiteboard_text = str(whiteboard_completed)
	var whiteboard_color = Color(0.3, 0.7, 1)
	
	if whiteboard_completed >= 50:
		whiteboard_text += " PRO"
		whiteboard_color = Color(0.2, 0.6, 1)
	elif whiteboard_completed >= 25:
		whiteboard_text += " ADV"
		whiteboard_color = Color(0.4, 0.7, 1)
	elif whiteboard_completed >= 10:
		whiteboard_color = Color(0.6, 0.8, 1)
	
	var whiteboard_label = _create_simple_label(whiteboard_text, 16, whiteboard_color)
	var whiteboard_container = _create_bordered_container(whiteboard_label, Vector2(120, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(whiteboard_container)
	
	# Total word challenges with special styling
	var total_words = stt_completed + whiteboard_completed
	var total_text = str(total_words)
	var total_color = Color(1, 0.8, 0.2)
	
	if total_words >= 100:
		total_text += " MASTER"
		total_color = Color(1, 0.2, 0.2) # Red for word masters
	elif total_words >= 75:
		total_text += " EXPERT"
		total_color = Color(1, 0.6, 0.2) # Orange for advanced
	elif total_words >= 50:
		total_text += " SKILLED"
		total_color = Color(1, 1, 0.2) # Yellow for intermediate
	elif total_words >= 25:
		total_color = Color(1, 0.9, 0.5) # Light yellow for beginner+
	
	var total_label = _create_simple_label(total_text, 16, total_color)
	var total_container = _create_bordered_container(total_label, Vector2(100, 55), Color(0.05, 0.05, 0.05, 0.3))
	entry.add_child(total_container)
	
	return entry

# Populate word recognize rankings tab
func _populate_word_recognize_rankings():
	# Safety check - ensure all required nodes exist
	if not word_list:
		print("WordRecognize tab nodes not found - skipping population")
		return
		
	# Clear existing entries
	for child in word_list.get_children():
		child.queue_free()
	
	# Sort users by total word recognize challenges (highest first)
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b):
		if a["word_recognize"] != b["word_recognize"]:
			return a["word_recognize"] > b["word_recognize"]
		# If word recognize is tied, sort by level
		return a["level"] > b["level"]
	)
	
	# Add header
	var header = _create_simple_word_recognize_header()
	word_list.add_child(header)
	
	# Add spacer after header
	var header_spacer = Control.new()
	header_spacer.custom_minimum_size = Vector2(0, 5)
	word_list.add_child(header_spacer)
	
	# Add user entries
	for i in range(sorted_users.size()):
		var user = sorted_users[i]
		var entry = _create_word_recognize_entry(user, i + 1)
		word_list.add_child(entry)
		
		# Highlight current user
		if user.get("is_current_user", false):
			entry.modulate = Color(1.2, 1.2, 0.8) # Slightly golden tint
		
		# Add small spacer between entries (except last one)
		if i < sorted_users.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 3)
			word_list.add_child(spacer)

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
