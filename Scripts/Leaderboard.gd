extends Control

# UI References
@onready var tab_container = $MainContainer/TabContainer
@onready var dungeon_ranking_tab = $MainContainer/TabContainer/DungeonRankings
@onready var power_scale_tab = $MainContainer/TabContainer/PowerScale
@onready var back_button = $MainContainer/BackButton

# Leaderboard data containers
@onready var dungeon_scroll = $MainContainer/TabContainer/DungeonRankings/ScrollContainer
@onready var dungeon_list = $MainContainer/TabContainer/DungeonRankings/ScrollContainer/VBoxContainer
@onready var power_scroll = $MainContainer/TabContainer/PowerScale/ScrollContainer
@onready var power_list = $MainContainer/TabContainer/PowerScale/ScrollContainer/VBoxContainer

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
	header.add_theme_constant_override("separation", 2)
	header.custom_minimum_size = Vector2(0, 45)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Rank
	var rank_label = _create_simple_label("Rank", 16, Color(1, 1, 0.8))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(rank_container)
	
	# Avatar
	var pic_label = _create_simple_label("Avatar", 16, Color(1, 1, 0.8))
	var pic_container = _create_bordered_container(pic_label, Vector2(60, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(pic_container)
		# Player
	var name_label = _create_simple_label("Player", 16, Color(1, 1, 0.8))
	var name_container = _create_bordered_container(name_label, Vector2(220, 45), Color(0.2, 0.2, 0.3, 0.6))  # was 200

	header.add_child(name_container)
	
	# Medal
	var medal_label = _create_simple_label("Medal", 16, Color(1, 1, 0.8))
	var medal_container = _create_bordered_container(medal_label, Vector2(80, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(medal_container)
	
	# Highest Dungeon
	var dungeon_label = _create_simple_label("Dungeon", 16, Color(1, 1, 0.8))
	var dungeon_container = _create_bordered_container(dungeon_label, Vector2(160, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(dungeon_container)
	
	# Stages
	var stages_label = _create_simple_label("Stage", 16, Color(1, 1, 0.8))
	var stages_container = _create_bordered_container(stages_label, Vector2(70, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(stages_container)
	
	# Level
	var level_label = _create_simple_label("Level", 16, Color(1, 1, 0.8))
	var level_container = _create_bordered_container(level_label, Vector2(60, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(level_container)
	
	return header

# Simplified header function for power scale rankings with reliable text display
func _create_simple_power_header() -> Control:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	header.custom_minimum_size = Vector2(0, 45)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Rank
	var rank_label = _create_simple_label("Rank", 16, Color(1, 1, 0.8))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(rank_container)
	
	# Avatar
	var pic_label = _create_simple_label("Avatar", 16, Color(1, 1, 0.8))
	var pic_container = _create_bordered_container(pic_label, Vector2(60, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(pic_container)
		# Player
	var name_label = _create_simple_label("Player", 16, Color(1, 1, 0.8))
	var name_container = _create_bordered_container(name_label, Vector2(220, 45), Color(0.2, 0.2, 0.3, 0.6))  # was 200

	header.add_child(name_container)
	
	# Level
	var level_label = _create_simple_label("Level", 16, Color(1, 1, 0.8))
	var level_container = _create_bordered_container(level_label, Vector2(60, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(level_container)
	
	# Health (green color)
	var health_label = _create_simple_label("Health", 16, Color(0.2, 1, 0.2))
	var health_container = _create_bordered_container(health_label, Vector2(90, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(health_container)
	
	# Attack (red color)
	var attack_label = _create_simple_label("Attack", 16, Color(1, 0.2, 0.2))
	var attack_container = _create_bordered_container(attack_label, Vector2(90, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(attack_container)
	
	# Durability (blue color)
	var durability_label = _create_simple_label("Defense", 16, Color(0.2, 0.6, 1))
	var durability_container = _create_bordered_container(durability_label, Vector2(100, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(durability_container)
	
	# Power Scale (yellow color)
	var power_label = _create_simple_label("Scale", 16, Color(1, 1, 0.2))
	var power_container = _create_bordered_container(power_label, Vector2(100, 45), Color(0.2, 0.2, 0.3, 0.6))
	header.add_child(power_container)
	
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

func _ready():
	# Connect back button
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Load leaderboard data
	await _load_leaderboard_data()
	
	# Populate both tabs
	_populate_dungeon_rankings()
	_populate_power_scale_rankings()

# Load all user data from Firestore for leaderboard
func _load_leaderboard_data():
	if !Firebase.Auth or !Firebase.Auth.auth:
		print("Leaderboard: No authentication found")
		return
	
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
		
		# Calculate highest completed dungeon and total stages
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
		
		user_data["highest_dungeon"] = highest_dungeon
		user_data["total_stages_completed"] = total_stages_completed
		user_data["enemies_defeated"] = progress.get("enemies_defeated", 0)
		
		# Update rank based on progress
		user_data["rank"] = _calculate_rank_from_progress(highest_dungeon, total_stages_completed)
	else:
		user_data["highest_dungeon"] = 0
		user_data["total_stages_completed"] = 0
		user_data["enemies_defeated"] = 0
		user_data["rank"] = "bronze"
	
	# Calculate power score (combined stats)
	user_data["power_score"] = user_data["health"] + user_data["damage"] + user_data["durability"]
	
	return user_data

# Calculate rank based on dungeon progress
func _calculate_rank_from_progress(highest_dungeon: int, total_stages: int) -> String:
	if highest_dungeon >= 3 and total_stages >= 10:  # Completed multiple dungeons
		return "gold"
	elif highest_dungeon >= 2 and total_stages >= 5:  # Reached second dungeon
		return "silver"
	else:
		return "bronze"

# Populate dungeon rankings tab
func _populate_dungeon_rankings():
	# Clear existing entries
	for child in dungeon_list.get_children():
		child.queue_free()
	
	# Sort users by dungeon progress (highest dungeon first, then total stages)
	var sorted_users = all_users_data.duplicate()
	sorted_users.sort_custom(func(a, b): 
		if a["highest_dungeon"] != b["highest_dungeon"]:
			return a["highest_dungeon"] > b["highest_dungeon"]
		if a["total_stages_completed"] != b["total_stages_completed"]:
			return a["total_stages_completed"] > b["total_stages_completed"]
		return a["level"] > b["level"]
	)
		# Add header
	var header = _create_simple_dungeon_header()  # Use simplified version
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
			entry.modulate = Color(1.2, 1.2, 0.8)  # Slightly golden tint
		
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
	var header = _create_simple_power_header()  # Use simplified version
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
			entry.modulate = Color(1.2, 1.2, 0.8)  # Slightly golden tint
		
		# Add small spacer between entries (except last one)
		if i < sorted_users.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 3)
			power_list.add_child(spacer)

# Create entry for dungeon rankings
func _create_dungeon_entry(user_data: Dictionary, rank: int) -> Control:
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	entry.custom_minimum_size = Vector2(0, 50)
	
	# Rank number
	var rank_label = _create_simple_label(str(rank), 16, Color(1, 1, 1))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 45), Color(0.2, 0.2, 0.3, 0.6))
	entry.add_child(rank_container)
		# Profile picture
	var profile_rect = TextureRect.new()
	profile_rect.custom_minimum_size = Vector2(40, 40)
	profile_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var profile_id = user_data.get("profile_picture", "13")
	if profile_id == "default":
		profile_id = "13"
	var profile_texture = load("res://gui/ProfileScene/Profile/portrait" + profile_id + ".png")
	if profile_texture:
		profile_rect.texture = profile_texture
	
	var profile_center = Control.new()
	profile_center.custom_minimum_size = Vector2(60, 50)
	profile_center.add_child(profile_rect)
	profile_rect.position = Vector2(10, 5)
	var profile_container = _create_bordered_container(profile_center, Vector2(60, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(profile_container)
	
	# Player name
	var name_label = _create_simple_label(user_data.get("username", "Unknown"), 16, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT)
	var name_container = _create_bordered_container(name_label, Vector2(220, 45), Color(0.2, 0.2, 0.3, 0.6))  # was 200

	entry.add_child(name_container)
	
	# Medal
	var medal_rect = TextureRect.new()
	medal_rect.custom_minimum_size = Vector2(30, 30)
	medal_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var rank_key = user_data.get("rank", "bronze")
	if medal_textures.has(rank_key):
		medal_rect.texture = medal_textures[rank_key]
	
	var medal_center = Control.new()
	medal_center.custom_minimum_size = Vector2(80, 50)
	medal_center.add_child(medal_rect)
	medal_rect.position = Vector2(25, 10)
	var medal_container = _create_bordered_container(medal_center, Vector2(80, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(medal_container)
	
	# Highest dungeon
	var dungeon_text = ""
	var highest_dungeon = user_data.get("highest_dungeon", 0)
	if highest_dungeon > 0:
		dungeon_text = dungeon_names.get(highest_dungeon, "Unknown")
	else:
		dungeon_text = "Not Started"
	var dungeon_label = _create_simple_label(dungeon_text, 16, Color(1, 1, 1))
	var dungeon_container = _create_bordered_container(dungeon_label, Vector2(160, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(dungeon_container)
	
	# Total stages completed
	var stages_label = _create_simple_label(str(user_data.get("total_stages_completed", 0)), 16, Color(1, 1, 1))
	var stages_container = _create_bordered_container(stages_label, Vector2(70, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(stages_container)
	
	# Level
	var level_label = _create_simple_label(str(user_data.get("level", 1)), 16, Color(1, 1, 1))
	var level_container = _create_bordered_container(level_label, Vector2(60, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(level_container)
	
	return entry

# Create entry for power scale rankings
func _create_power_entry(user_data: Dictionary, rank: int) -> Control:
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	entry.custom_minimum_size = Vector2(0, 50)
	
	# Rank number
	var rank_label = _create_simple_label(str(rank), 16, Color(1, 1, 1))
	var rank_container = _create_bordered_container(rank_label, Vector2(80, 45), Color(0.2, 0.2, 0.3, 0.6))
	entry.add_child(rank_container)
	
	# Profile picture
	var profile_rect = TextureRect.new()
	profile_rect.custom_minimum_size = Vector2(40, 40)
	profile_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var profile_id = user_data.get("profile_picture", "13")
	if profile_id == "default":
		profile_id = "13"
	var profile_texture = load("res://gui/ProfileScene/Profile/portrait" + profile_id + ".png")
	if profile_texture:
		profile_rect.texture = profile_texture
	
	var profile_center = Control.new()
	profile_center.custom_minimum_size = Vector2(60, 50)
	profile_center.add_child(profile_rect)
	profile_rect.position = Vector2(10, 5)
	var profile_container = _create_bordered_container(profile_center, Vector2(60, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(profile_container)
		# Player name
	var name_label = _create_simple_label(user_data.get("username", "Unknown"), 16, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT)
	var name_container = _create_bordered_container(name_label, Vector2(220, 45), Color(0.2, 0.2, 0.3, 0.6))  # was 200

	entry.add_child(name_container)
	
	# Level
	var level_label = _create_simple_label(str(user_data.get("level", 1)), 16, Color(1, 1, 1))
	var level_container = _create_bordered_container(level_label, Vector2(60, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(level_container)
	
	# Health (with color)
	var health_label = _create_simple_label(str(user_data.get("health", 100)), 16, Color(0.8, 1, 0.8))
	var health_container = _create_bordered_container(health_label, Vector2(90, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(health_container)
	
	# Attack/Damage (with color)
	var attack_label = _create_simple_label(str(user_data.get("damage", 10)), 16, Color(1, 0.8, 0.8))
	var attack_container = _create_bordered_container(attack_label, Vector2(90, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(attack_container)
	
	# Durability (with color)
	var durability_label = _create_simple_label(str(user_data.get("durability", 5)), 16, Color(0.8, 0.8, 1))
	var durability_container = _create_bordered_container(durability_label, Vector2(100, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(durability_container)
		# Power score (with color)
	var power_label = _create_simple_label(str(user_data.get("power_score", 115)), 16, Color(1, 1, 0.8))
	var power_container = _create_bordered_container(power_label, Vector2(100, 50), Color(0.05, 0.05, 0.05, 0.2))
	entry.add_child(power_container)
	
	return entry

# Back button handler
func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
