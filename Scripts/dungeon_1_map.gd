extends Node2D

# References to UI elements
var stage_buttons = []
var mob_buttons = []
var current_stage = 1
var max_stage = 5
var dungeon_num = 1

# Enemy types for this dungeon - now with stage-specific variations
var enemy_types = {
	"stage_1": {
		"name": "Young Slime",
		"description": "A small, bouncy slime that's new to combat.",
		"health": 70,
		"attack": 5,
		"durability": 5,
		"skill": "Tiny Splash",
		"animation": "idle"
	},
	"stage_2": {
		"name": "Slime",
		"description": "A gelatinous creature that bounces around.",
		"health": 80,
		"attack": 10,
		"durability": 10,
		"skill": "Acid Splash",
		"animation": "idle"
	},
	"stage_3": {
		"name": "Elder Slime",
		"description": "An experienced slime with stronger acidic properties.",
		"health": 90,
		"attack": 6,
		"durability": 6,
		"skill": "Corrosive Burst",
		"animation": "idle"
	},
	"stage_4": {
		"name": "Giant Slime",
		"description": "A massive slime that has absorbed many smaller ones.",
		"health": 100,
		"attack": 8,
		"durability": 7,
		"skill": "Overwhelming Splash",
		"animation": "idle"
	},
	"boss": {
		"name": "Plain Guardian",
		"description": "An ancient tree guardian with powerful nature magic.",
		"health": 300,
		"attack": 25,
		"durability": 35,
		"skill": "Root Entangle",
		"animation": "idle"
	}
}

# Player progress tracking
var completed_stages = []
var current_selected_stage = 0
var current_selected_enemy_type = "stage_1"

var notification_popup: CanvasLayer

func _ready():
	# Initialize Firebase if available
	_initialize_firebase()
	
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
		print("Firebase initialized for Dungeon 1")
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
		if stage_num == max_stage:  # Stage 5 is boss stage
			indicator_node_name = "BossIndicator"

		var indicator_node = button.get_node_or_null(indicator_node_name)
		if indicator_node == null:
			print("Warning: Could not find " + indicator_node_name + " for stage " + str(stage_num))
			continue
			
		# Stage 1 is always unlocked
		if stage_num == 1:
			button.texture_normal = load("res://gui/Update/icons/next level select.png")
			indicator_node.visible = true
		# Completed stages (stage_num is in completed_stages array)
		elif completed_stages.has(stage_num):
			button.texture_normal = load("res://gui/Update/icons/player completed level.png")
			indicator_node.visible = true
		# Next available stage (previous stage is completed or we're at stage 2 and stage 1 is completed)
		elif (stage_num > 1 and completed_stages.has(stage_num - 1)) or (stage_num == 2 and completed_stages.has(1)):
			button.texture_normal = load("res://gui/Update/icons/next level select.png")
			indicator_node.visible = true
		# Locked stages
		else:
			button.texture_normal = load("res://gui/Update/icons/unlocked level.png")
			indicator_node.visible = false

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
	animated_sprite.play("idle") # Default to slime animation

func _connect_signals():
	# Connect stage button signals
	for i in range(stage_buttons.size()):
		stage_buttons[i].pressed.connect(_on_stage_button_pressed.bind(i+1))
	
	# Connect mob button signals
	for i in range(mob_buttons.size()):
		if i < 3:  # Regular mobs - pass stage info instead of "normal"
			mob_buttons[i].pressed.connect(_on_mob_button_pressed.bind("stage_" + str(i + 1), i))
		else:  # Boss
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
		# Stage is locked - show popup
		notification_popup.show_notification("Stage Locked!", "Complete Stage " + str(stage_num - 1) + " first to unlock this stage.", "OK")
		return
		
	current_selected_stage = stage_num
	
	# Update stage details panel
	_update_stage_details(stage_num)
	
	# Show the stage details panel
	$StageDetails.visible = true
	
	# Set the appropriate enemy type for this stage
	if stage_num == max_stage:
		current_selected_enemy_type = "boss"
		# Show boss in the last stage
		$StageDetails/LeftContainer/AnimatedSprite2D.play("idle")
		$StageDetails/LeftContainer/MonsterName.text = enemy_types["boss"]["name"]
		
		# Show the boss indicator for stage 5
		if stage_num == 5:
			$Stage5/BossIndicator.visible = true
	else:
		current_selected_enemy_type = "stage_" + str(stage_num)
		# Show regular mob for stages 1-4 using stage-specific data
		$StageDetails/LeftContainer/AnimatedSprite2D.play("idle")
		$StageDetails/LeftContainer/MonsterName.text = enemy_types["stage_" + str(stage_num)]["name"]

func _update_stage_details(stage_num):
	# Update stage number
	$StageDetails/Label2.text = str(stage_num)
	
	# Set enemy info based on stage number
	var enemy_key = ""
	if stage_num == max_stage:
		enemy_key = "boss"
	else:
		enemy_key = "stage_" + str(stage_num)
	
	var enemy_data = enemy_types[enemy_key]
	
	# Update enemy information
	$StageDetails/LeftContainer/MonsterName.text = enemy_data["name"].to_upper()
	$StageDetails/RightContainer/Info.text = enemy_data["description"]
	$StageDetails/RightContainer/Health.text = str(enemy_data["health"])
	$StageDetails/RightContainer/Attack.text = str(enemy_data["attack"])
	$StageDetails/RightContainer/Durability.text = str(enemy_data["durability"])
	$StageDetails/RightContainer/SkillName.text = enemy_data["skill"]
	
	# Set level based on stage number
	$StageDetails/LeftContainer/LVLabel2.text = str(stage_num * 5)
	
	# Update mob button visibility - show only one button per stage
	for i in range(mob_buttons.size()):
		mob_buttons[i].visible = false  # Hide all buttons first
	
	if stage_num == 5:
		# Show only boss button for stage 5
		mob_buttons[3].visible = true  # Boss1Button (index 3)
	else:
		# Show only first mob button for stages 1-4 (since they all use the same enemy type)
		mob_buttons[0].visible = true  # Mob1Button (index 0)

func _on_mob_button_pressed(type, index):
	print("Selected enemy type: " + type + " index: " + str(index))
	
	# Update enemy display based on selected type
	current_selected_enemy_type = type
	
	# Update animation and info
	if type == "boss":
		$StageDetails/LeftContainer/AnimatedSprite2D.play("idle")
		$StageDetails/LeftContainer/MonsterName.text = enemy_types["boss"]["name"].to_upper()
		$StageDetails/RightContainer/Info.text = enemy_types["boss"]["description"]
		$StageDetails/RightContainer/Health.text = str(enemy_types["boss"]["health"])
		$StageDetails/RightContainer/Attack.text = str(enemy_types["boss"]["attack"])
		$StageDetails/RightContainer/Durability.text = str(enemy_types["boss"]["durability"])
		$StageDetails/RightContainer/SkillName.text = enemy_types["boss"]["skill"]
	else:
		# For stage-specific enemies, use the current selected stage
		var stage_key = "stage_" + str(current_selected_stage)
		$StageDetails/LeftContainer/AnimatedSprite2D.play("idle")
		$StageDetails/LeftContainer/MonsterName.text = enemy_types[stage_key]["name"].to_upper()
		$StageDetails/RightContainer/Info.text = enemy_types[stage_key]["description"]
		$StageDetails/RightContainer/Health.text = str(enemy_types[stage_key]["health"])
		$StageDetails/RightContainer/Attack.text = str(enemy_types[stage_key]["attack"])
		$StageDetails/RightContainer/Durability.text = str(enemy_types[stage_key]["durability"])
		$StageDetails/RightContainer/SkillName.text = enemy_types[stage_key]["skill"]

func _on_back_button_pressed():
	if $StageDetails.visible:
		# If details panel is open, close it first
		$StageDetails.visible = false
	else:
		# Return to dungeon selection
		get_tree().change_scene_to_file("res://Scenes/DungeonSelection.tscn")

func _on_fight_button_pressed():
	print("Starting battle in Dungeon 1, Stage " + str(current_selected_stage))
	
	# Save current stage and dungeon directly to Firebase
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
	# Handle popup close if needed
	pass