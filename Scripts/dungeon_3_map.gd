extends Node2D

# References to UI elements
var stage_buttons = []
var mob_buttons = []
var current_stage = 1
var max_stage = 5
var dungeon_num = 3

# Enemy types for this dungeon - simplified to match .tres structure  
var enemy_types = {
	"normal": {
		"resource_path": "res://Resources/Enemies/dungeon3_normal.tres"
	},
	"boss": {
		"resource_path": "res://Resources/Enemies/dungeon3_boss.tres"
	}
}

# Loaded enemy resources cache
var loaded_enemy_resources = {}

# Player progress tracking
var completed_stages = []
var current_selected_stage = 0
var current_selected_enemy_type = "stage_1"

# Constants for popup styling
const POPUP_BG_COLOR = Color(0.113725, 0.329412, 0.458824, 0.9)
const POPUP_BORDER_COLOR = Color(1, 1, 1, 1)
const POPUP_TEXT_COLOR = Color(1, 0.92549, 0.756863, 1)

# Replace StageLockPopup with notification popup
var notification_popup: CanvasLayer

func _ready():
	# Initialize Firebase if available
	_initialize_firebase()
	
	# Load enemy resources
	_load_enemy_resources()
	
	# Set up stage buttons
	_initialize_stage_buttons()
	
	# Initialize monster icon buttons
	_initialize_mob_buttons()
	
	# Add signal connections
	_connect_signals()
	
	# Hide stage details panel initially
	$StageDetails.visible = false
	
	# Create notification popup
	notification_popup = load("res://Scenes/NotificationPopUp.tscn").instantiate()
	add_child(notification_popup)
	notification_popup.closed.connect(_on_notification_closed)

# Add this new function to handle clicks outside StageDetails
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if $StageDetails.visible:
			# Check if the click is outside of StageDetails
			var click_pos = event.position
			var rect = $StageDetails.get_global_rect()
			
			if not rect.has_point(click_pos):
				$StageDetails.visible = false
				get_viewport().set_input_as_handled()

func _initialize_firebase():
	if Engine.has_singleton("Firebase"):
		print("Firebase initialized for Dungeon 3")
		# Load user progress data
		_load_player_progress()
	else:
		print("Firebase not available, using default progression")
		# Set default progression (only stage 1 is unlocked)
		completed_stages = []

func _load_player_progress():
	# Only proceed if authenticated
	if not Firebase.Auth.auth:
		print("User not authenticated, using default progression")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	print("Loading progression data for user: " + user_id)
	
	var document = await collection.get_doc(user_id)
	if document and !("error" in document.keys() and document.get_value("error")):
		# Extract progression data using new structure
		var dungeons = document.get_value("dungeons")
		if dungeons != null and typeof(dungeons) == TYPE_DICTIONARY:
			var completed = dungeons.get("completed", {})
			
			# Check if dungeon 2 is completed to unlock dungeon 3
			var dungeon2_completed = false
			if completed.has("2"):
				var dungeon2_data = completed["2"]
				if dungeon2_data.get("completed", false) or dungeon2_data.get("stages_completed", 0) >= 5:
					dungeon2_completed = true
			
			if not dungeon2_completed:
				print("Dungeon 2 not completed yet, returning to dungeon selection")
				await get_tree().create_timer(0.5).timeout
				get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")
				return
			
			# Load progression data for dungeon 3
			if completed.has(str(dungeon_num)):
				var dungeon_data = completed[str(dungeon_num)]
				var stages_completed_count = dungeon_data.get("stages_completed", 0)
				
				# Build completed_stages array from stages_completed count
				completed_stages = []
				for i in range(1, stages_completed_count + 1):
					completed_stages.append(i)
				
				print("Loaded completed stages for dungeon " + str(dungeon_num) + ": ", completed_stages)
	else:
		print("Failed to load user document or document error")
		
	# Update stage button visuals based on progression
	_update_stage_buttons()

func _initialize_stage_buttons():
	# Store references to all stage buttons
	stage_buttons = [
		$Stage1, $Stage2, $Stage3, $Stage4, $Stage5
	]
	
	# Initially, only stage 1 is unlocked
	_update_stage_buttons()

func _update_stage_buttons():
	for i in range(stage_buttons.size()):
		var stage_num = i + 1
		var button = stage_buttons[i]
		
		# Handle the different indicator node names for regular stages vs boss stage
		var indicator_node_name = "MobIndicator"
		if stage_num == max_stage: # Stage 5 is boss stage
			indicator_node_name = "BossIndicator"
		
		var indicator_node = button.get_node_or_null(indicator_node_name)
		if indicator_node == null:
			print("Warning: Could not find " + indicator_node_name + " for stage " + str(stage_num))
			continue
			
		# Stage 1 is always unlocked and available
		if stage_num == 1:
			button.texture_normal = load("res://gui/Update/icons/next level select.png")
			indicator_node.visible = true
		# Completed stages show as completed
		elif completed_stages.has(stage_num):
			button.texture_normal = load("res://gui/Update/icons/player completed level.png")
			indicator_node.visible = true
		# Next available stage (unlocked but not completed)
		elif completed_stages.has(stage_num - 1) or (stage_num == 2 and completed_stages.has(1)):
			button.texture_normal = load("res://gui/Update/icons/next level select.png")
			indicator_node.visible = true
		# Future stages that are locked
		else:
			button.texture_normal = load("res://gui/Update/icons/unlocked level.png")
			indicator_node.visible = false
			
	print("Updated stage buttons. Completed stages: ", completed_stages)

func _initialize_mob_buttons():
	# Get mob buttons from the stage details panel
	mob_buttons = [
		$StageDetails/MonsterIconButtonContainer/Mob1Button,
		$StageDetails/MonsterIconButtonContainer/Mob2Button,
		$StageDetails/MonsterIconButtonContainer/Mob3Button,
		$StageDetails/MonsterIconButtonContainer/Boss1Button
	]
	
	# Initial setup of animations
	var animated_sprite = $StageDetails/LeftContainer/AnimatedSprite2D
	animated_sprite.play("idle") # Default to boar animation for dungeon 3

func _connect_signals():
	# Connect stage button signals
	for i in range(stage_buttons.size()):
		stage_buttons[i].pressed.connect(_on_stage_button_pressed.bind(i + 1))
	
	# Connect mob button signals
	for i in range(mob_buttons.size()):
		if i < 3: # Regular mobs - pass stage info instead of "normal"
			mob_buttons[i].pressed.connect(_on_mob_button_pressed.bind("stage_" + str(i + 1), i))
		else: # Boss
			mob_buttons[i].pressed.connect(_on_mob_button_pressed.bind("boss", 0))
	
	# Connect back button
	$TextureRect/BackButton.pressed.connect(_on_back_button_pressed)
	
	# Connect fight button
	$StageDetails/FightButton.pressed.connect(_on_fight_button_pressed)

func _on_stage_button_pressed(stage_num):
	$SelectLevel.visible = false
	print("Stage " + str(stage_num) + " selected")
	
	# Check if stage is unlocked
	if stage_num > 1 and not (completed_stages.has(stage_num - 1) or completed_stages.has(stage_num)):
		# Stage is locked - show popup using new notification system
		notification_popup.show_notification("Stage Locked!", "Complete Stage " + str(stage_num - 1) + " first to unlock this stage.", "OK")
		return
		
	current_selected_stage = stage_num
	
	# Update stage details panel (this handles all the enemy data display)
	_update_stage_details(stage_num)
	
	# Show the stage details panel
	$StageDetails.visible = true
	
	# Set the appropriate enemy type for this stage
	if stage_num == max_stage:
		current_selected_enemy_type = "boss"
		# Show the boss indicator for stage 5
		if stage_num == 5:
			$Stage5/BossIndicator.visible = true
	else:
		current_selected_enemy_type = "stage_" + str(stage_num)

func _update_stage_details(stage_num):
	# Update stage number
	$StageDetails/Label2.text = str(stage_num)
	
	# Get scaled enemy data for this stage
	var enemy_data = _get_scaled_enemy_data(stage_num)
	if enemy_data.is_empty():
		print("Error: Could not get enemy data for stage ", stage_num)
		return
	
	# Update enemy information using scaled data
	$StageDetails/LeftContainer/MonsterName.text = enemy_data["name"].to_upper()
	$StageDetails/RightContainer/Info.text = enemy_data["description"]
	$StageDetails/RightContainer/Health.text = str(enemy_data["health"])
	$StageDetails/RightContainer/Attack.text = str(enemy_data["attack"])
	$StageDetails/RightContainer/Durability.text = str(enemy_data["durability"])
	$StageDetails/RightContainer/SkillName.text = enemy_data["skill"]
	
	# Update experience reward if ExpRewardValue node exists
	var exp_reward_node = $StageDetails.get_node_or_null("ExpRewardValue")
	if exp_reward_node:
		exp_reward_node.text = str(enemy_data["exp_reward"]) + " EXP"
	
	# Set level based on calculated level
	$StageDetails/LeftContainer/LVLabel2.text = str(enemy_data["level"])
	
	# Update mob button visibility - show only one button per stage
	for i in range(mob_buttons.size()):
		mob_buttons[i].visible = false  # Hide all buttons first
	
	if stage_num == 5:
		# Show only boss button for stage 5
		mob_buttons[3].visible = true  # Boss1Button (index 3)
	else:
		# Show only first mob button for stages 1-4
		mob_buttons[0].visible = true  # Mob1Button (index 0)

func _on_mob_button_pressed(type, index):
	print("Selected enemy type: " + type + " index: " + str(index))
	
	# Update enemy display based on selected type
	current_selected_enemy_type = type
	
	# Get scaled enemy data for the current stage
	var enemy_data = _get_scaled_enemy_data(current_selected_stage)
	
	if enemy_data.is_empty():
		print("Error: Could not load enemy data for stage ", current_selected_stage)
		return
	
	# Update animation and info with scaled data
	$StageDetails/LeftContainer/AnimatedSprite2D.play("idle")
	$StageDetails/LeftContainer/MonsterName.text = enemy_data["name"].to_upper()
	$StageDetails/RightContainer/Info.text = enemy_data["description"]
	$StageDetails/RightContainer/Health.text = str(enemy_data["health"])
	$StageDetails/RightContainer/Attack.text = str(enemy_data["attack"])
	$StageDetails/RightContainer/Durability.text = str(enemy_data["durability"])
	$StageDetails/RightContainer/SkillName.text = enemy_data["skill"]

func _on_back_button_pressed():
	if $StageDetails.visible:
		# If details panel is open, close it first
		$StageDetails.visible = false
	else:
		# Return to dungeon selection
		get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")

func _on_fight_button_pressed():
	print("Starting battle in Dungeon 3, Stage " + str(current_selected_stage))

	# Set battle progress in DungeonGlobals for immediate transfer to battle scene
	DungeonGlobals.set_battle_progress(dungeon_num, current_selected_stage)

	# Save current stage and dungeon directly to Firebase (for persistence)
	await _save_current_dungeon_stage()

	# Load the battle scene
	get_tree().change_scene_to_file("res://Scenes/BattleScene.tscn")

func _save_current_dungeon_stage():
	# Only proceed if authenticated
	if not Firebase.Auth.auth:
		print("User not authenticated, cannot save progress")
		return
		
	var user_id = Firebase.Auth.auth.localid
	var collection = Firebase.Firestore.collection("dyslexia_users")
	
	# Get current document first to preserve other fields
	var get_task = await collection.get_doc(user_id)
	if get_task:
		var document = await get_task
		if document and document.has_method("doc_fields"):
			var update_data = document.doc_fields
			
			# Update dungeons progress
			if not update_data.has("dungeons"):
				update_data["dungeons"] = {}
			if not update_data.dungeons.has("progress"):
				update_data.dungeons["progress"] = {}
			
			# Update current dungeon and stage
			update_data.dungeons.progress.current_dungeon = dungeon_num
			update_data.dungeons.progress.current_stage = current_selected_stage
			
			# Save back to Firestore
			collection.add(user_id, update_data)
			print("Saved current dungeon/stage to Firebase")

func _on_notification_closed():
	# Handle notification close if needed
	pass

# Load enemy resources from .tres files
func _load_enemy_resources():
	for enemy_type in enemy_types.keys():
		var resource_path = enemy_types[enemy_type]["resource_path"]
		var resource = load(resource_path)
		if resource:
			loaded_enemy_resources[enemy_type] = resource
			print("Loaded enemy resource: ", enemy_type, " from ", resource_path)
		else:
			print("Failed to load enemy resource: ", resource_path)

# Get stage-based multiplier for enemy stats
func _get_stage_multiplier(stage_num: int) -> float:
	# Base multiplier increases with stage progression
	var stage_multiplier = 1.0 + (stage_num - 1) * 0.25  # 1.0, 1.25, 1.5, 1.75, 2.0
	
	# Additional multiplier for higher dungeons
	var dungeon_multiplier = 1.0 + (dungeon_num - 1) * 0.5  # 1.0, 1.5, 2.0
	
	return stage_multiplier * dungeon_multiplier

# Get stage-specific enemy name variations for dungeon 3
func _get_stage_specific_name(base_name: String, stage_num: int) -> String:
	# Stage-specific prefixes for mountain/boar theme
	var stage_prefixes = ["Wild", "Mountain", "Tusked", "Alpha", "Boss"]
	var prefix = stage_prefixes[min(stage_num - 1, stage_prefixes.size() - 1)]
	
	# For boss stages, use specific boss names
	if stage_num == 5:
		return "Mountain Guardian"
	
	# For regular stages, add prefix
	return prefix + " " + base_name

# Get scaled enemy data for a specific stage
func _get_scaled_enemy_data(stage_num: int) -> Dictionary:
	var is_boss = (stage_num == 5)
	var enemy_type = "boss" if is_boss else "normal"
	
	if !loaded_enemy_resources.has(enemy_type):
		print("Error: Enemy resource not loaded for type: ", enemy_type)
		return {}
	
	var enemy_resource = loaded_enemy_resources[enemy_type]
	var multiplier = _get_stage_multiplier(stage_num)
	
	return {
		"name": _get_stage_specific_name(enemy_resource.get_enemy_name(), stage_num),
		"description": enemy_resource.description,
		"health": int(enemy_resource.get_health() * multiplier),
		"attack": int(enemy_resource.get_damage() * multiplier),
		"durability": int(enemy_resource.get_durability() * multiplier),
		"skill": enemy_resource.skill_name,
		"exp_reward": int(enemy_resource.get_exp_reward() * multiplier),
		"level": stage_num * 5
	}
